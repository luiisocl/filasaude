import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/perf.dart';
import '../../data/historico.dart';
import '../../domain/entities.dart';
import 'equipe_viewmodels.dart';

enum Periodo {
  semana('7 dias', 7),
  mes('30 dias', 30),
  trimestre('90 dias', 90),
  ano('12 meses', 365);

  const Periodo(this.label, this.dias);
  final String label;
  final int dias;
}

class PainelHoje {
  const PainelHoje({
    required this.aguardandoPorCor,
    required this.esperaMediaPorCor,
    required this.aguardandoTriagem,
    required this.aguardandoChegada,
    required this.atendidos,
    required this.desistencias,
    required this.emAtendimento,
  });

  final List<int> aguardandoPorCor;
  final List<int?> esperaMediaPorCor;
  final int aguardandoTriagem;
  final int aguardandoChegada;
  final int atendidos;
  final int desistencias;
  final int emAtendimento;

  int get totalAguardando => aguardandoPorCor.fold(0, (a, b) => a + b) + aguardandoTriagem;
  double get taxaDesistencia => atendidos + desistencias == 0 ? 0 : desistencias / (atendidos + desistencias);
}

class CoordenadorViewModel extends EquipeViewModel {
  CoordenadorViewModel(super.repo, super.session);

  // ---- painel em tempo real ----

  PainelHoje get painel {
    final agora = DateTime.now();
    final porCor = List.filled(5, 0);
    final somaEspera = List.filled(5, 0);
    final qtdEspera = List.filled(5, 0);
    for (final s in repo.filaMedico(unidadeId)) {
      porCor[s.cor!.index]++;
    }
    for (final s in repo.senhas) {
      if (s.unidadeId != unidadeId || s.triagem == null || s.chegadaEm == null) continue;
      if (agora.difference(s.chegadaEm!).inHours > 24) continue;
      final fim = s.atendimentoInicio ?? (s.etapa == EtapaSenha.aguardandoMedico ? agora : null);
      if (fim == null) continue;
      somaEspera[s.cor!.index] += fim.difference(s.chegadaEm!).inMinutes;
      qtdEspera[s.cor!.index]++;
    }
    final hoje = repo.atendidasHoje(unidadeId);
    return PainelHoje(
      aguardandoPorCor: porCor,
      esperaMediaPorCor: [for (var i = 0; i < 5; i++) qtdEspera[i] == 0 ? null : somaEspera[i] ~/ qtdEspera[i]],
      aguardandoTriagem: repo.filaTriagem(unidadeId).length,
      aguardandoChegada: repo.filaChegada(unidadeId).length,
      atendidos: hoje.where((s) => s.etapa == EtapaSenha.finalizado).length,
      desistencias: hoje.where((s) => s.etapa == EtapaSenha.desistiu).length,
      emAtendimento: repo.chamadosOuEmAtendimento(unidadeId).length,
    );
  }

  int get medicosAtivos => repo.medicosAtivos[unidadeId] ?? 0;

  // ---- relatório (Isolate) ----

  Periodo periodo = Periodo.mes;
  Relatorio? relatorio;
  bool calculando = false;
  int? calculoMs;
  bool calculadoEmIsolate = false;

  void escolherPeriodo(Periodo p) {
    periodo = p;
    unawaited(gerarRelatorio());
  }

  Future<void> gerarRelatorio() async {
    if (calculando) return;
    calculando = true;
    notifyListeners();
    await repo.carregarHistorico();
    final cronometro = Stopwatch()..start();
    final hoje = diaDe(DateTime.now());
    final inicio = hoje - periodo.dias;
    final h = repo.historico;
    if (h != null && PerfConfig.otimizado.value) {
      // Depois: cálculo e ordenação de até 200 mil registros fora da UI.
      relatorio = await compute(calcularRelatorio, RelatorioParams(h, inicio, hoje));
      calculadoEmIsolate = true;
    } else if (h != null) {
      relatorio = calcularRelatorio(RelatorioParams(h, inicio, hoje));
      calculadoEmIsolate = false;
    } else {
      // Antes: tudo na thread principal, sobre a lista de mapas.
      relatorio = calcularRelatorioObjetos(repo.historicoObjetos!, inicio, hoje);
      calculadoEmIsolate = false;
    }
    calculoMs = cronometro.elapsedMilliseconds;
    calculando = false;
    notifyListeners();
  }

  // ---- lista de atendimentos com paginação (lazy loading) ----

  static const tamanhoPagina = 50;
  int itensCarregados = 0;
  bool carregandoPagina = false;

  int get totalHistorico => repo.historicoTamanho;
  bool get temMais => itensCarregados < totalHistorico;

  Future<void> abrirLista() async {
    await repo.carregarHistorico();
    if (itensCarregados == 0) await carregarMais();
  }

  Future<void> carregarMais() async {
    if (carregandoPagina || !temMais) return;
    carregandoPagina = true;
    notifyListeners();
    // Simula a busca da próxima página no servidor.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    itensCarregados = (itensCarregados + tamanhoPagina).clamp(0, totalHistorico);
    carregandoPagina = false;
    notifyListeners();
  }

  /// Registro i do histórico, nos dois formatos.
  ({int dia, int cor, int espera, int duracao, bool desistiu, int desfecho}) item(int i) {
    final h = repo.historico;
    if (h != null) {
      return (
        dia: h.dias[i],
        cor: h.cores[i],
        espera: h.esperas[i],
        duracao: h.duracoes[i],
        desistiu: h.flags[i] & 1 == 1,
        desfecho: h.flags[i] >> 1,
      );
    }
    final m = repo.historicoObjetos![i];
    return (
      dia: m['dia']! as int,
      cor: m['cor']! as int,
      espera: m['espera']! as int,
      duracao: m['duracao']! as int,
      desistiu: m['desistiu']! as bool,
      desfecho: m['desfecho']! as int,
    );
  }

  // ---- equipe e unidade ----

  List<Funcionario> get funcionarios => repo.funcionarios;

  bool emailEmUso(String email, {String? exceto}) => repo.emailEmUso(email, exceto: exceto);

  void salvarFuncionario(Funcionario f) => repo.salvarFuncionario(f);

  void alternarAtivo(Funcionario f) => repo.alternarAtivo(f);

  void salvarUnidade({required String nome, required int abre, required int fecha, required int consultorios, required int medicos}) =>
      repo.atualizarUnidade(unidade, nome: nome, abre: abre, fecha: fecha, consultorios: consultorios, medicos: medicos);
}
