// ViewModels das áreas da equipe: recepção, enfermagem e médico.
import 'dart:async';

import '../../data/fila_repository.dart';
import '../../domain/entities.dart';
import '../../domain/fila_rules.dart';
import 'base_viewmodel.dart';
import 'session_viewmodel.dart';

abstract class EquipeViewModel extends AreaViewModel {
  EquipeViewModel(super.repo, this.session);

  final SessionViewModel session;

  String get unidadeId => session.unidadeId;
  Unidade get unidade => repo.unidade(unidadeId);
  String get nomeProfissional => session.funcionario?.nome ?? '';

  Paciente? paciente(Senha s) => repo.paciente(s.pacienteId);
  Senha? senha(String id) => repo.senhaPorId(id);
}

// ---------------------------------------------------------------------------

class RecepcaoViewModel extends EquipeViewModel {
  RecepcaoViewModel(super.repo, super.session);

  String busca = '';

  void buscar(String texto) {
    busca = texto.trim().toLowerCase();
    notifyListeners();
  }

  List<Senha> get chegadas {
    final lista = repo.filaChegada(unidadeId);
    if (busca.isEmpty) return lista;
    final digitos = busca.replaceAll(RegExp(r'\D'), '');
    return lista.where((s) {
      final p = paciente(s);
      return s.codigo.toLowerCase().contains(busca) ||
          (p != null && p.nome.toLowerCase().contains(busca)) ||
          (digitos.isNotEmpty && p != null && p.documento.contains(digitos));
    }).toList();
  }

  int get naTriagem => repo.filaTriagem(unidadeId).length;

  void confirmarChegada(Senha s, PrioridadeLegal prioridade, {String? nome, String? telefone}) {
    final p = paciente(s);
    if (p != null && (nome != null || telefone != null)) {
      repo.atualizarPaciente(p, nome: nome, telefone: telefone);
    }
    repo.confirmarChegada(s, prioridade);
  }

  /// EX02: CPF ou cartão já cadastrado → reaproveita o cadastro.
  RetiradaResultado novaSenhaPresencial({
    required String nome,
    required DateTime nascimento,
    required String documento,
    required TipoAtendimento tipo,
    required PrioridadeLegal prioridade,
  }) {
    final existente = documento.isEmpty ? null : repo.pacientePorDocumento(documento);
    final p = existente ??
        repo.cadastrarPaciente(
          nome: nome,
          nascimento: nascimento,
          telefone: '',
          documento: documento.isEmpty ? 'sem-doc-${DateTime.now().millisecondsSinceEpoch}' : documento,
        );
    final r = repo.retirarSenha(paciente: p, unidade: unidade, tipo: tipo, origem: OrigemSenha.presencial);
    if (r.senha != null && r.resultado == ResultadoRetirada.ok && prioridade != PrioridadeLegal.nenhuma) {
      r.senha!.prioridade = prioridade;
    }
    return r;
  }
}

// ---------------------------------------------------------------------------

class EnfermeiroViewModel extends EquipeViewModel {
  EnfermeiroViewModel(super.repo, super.session) {
    _sub = repo.eventos.listen((e) {
      if (e is AlertaVermelho) {
        final s = repo.senhaPorId(e.senhaId);
        if (s != null && s.unidadeId == unidadeId) _alertas.add(s);
      }
    });
  }

  late final StreamSubscription<FilaEvento> _sub;
  final _alertas = StreamController<Senha>.broadcast();

  /// RN02: avisa a tela quando alguém é classificado como vermelho.
  Stream<Senha> get alertasVermelhos => _alertas.stream;

  List<Senha> get filaTriagem => repo.filaTriagem(unidadeId);

  List<Senha> get filaMedico => repo.filaMedico(unidadeId);

  List<Senha> get emergencias => repo.emergencias(unidadeId);

  /// RN08: quem passou do tempo máximo da cor.
  List<Senha> get atrasados {
    final agora = DateTime.now();
    return filaMedico.where((s) => FilaRules.excedeuTempo(s, agora)).toList();
  }

  void classificar(Senha s, CorRisco cor, String queixa, SinaisVitais sinais) =>
      repo.classificar(s, cor: cor, queixa: queixa, sinais: sinais, enfermeiro: nomeProfissional);

  void reclassificar(Senha s, CorRisco cor, String motivo) =>
      repo.reclassificar(s, cor: cor, motivo: motivo, enfermeiro: nomeProfissional);

  @override
  void dispose() {
    _sub.cancel();
    _alertas.close();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------

class MedicoViewModel extends EquipeViewModel {
  MedicoViewModel(super.repo, super.session);

  int consultorio = 1;

  void escolherConsultorio(int c) {
    consultorio = c;
    notifyListeners();
  }

  List<Senha> get fila => repo.filaMedico(unidadeId);

  List<Senha> get emergencias => repo.emergencias(unidadeId);

  /// Paciente chamado ou em atendimento por este médico.
  Senha? get atual {
    for (final s in repo.chamadosOuEmAtendimento(unidadeId)) {
      if (s.medico == nomeProfissional) return s;
    }
    return null;
  }

  int get atendidosHoje =>
      repo.atendidasHoje(unidadeId).where((s) => s.medico == nomeProfissional).length;

  int get medicosAtivos => repo.medicosAtivos[unidadeId] ?? 0;

  Senha? chamarProximo() => repo.chamarProximo(unidadeId, medico: nomeProfissional, consultorio: consultorio);

  void rechamar(Senha s) => repo.rechamar(s);

  void naoCompareceu(Senha s) => repo.naoCompareceu(s);

  void iniciar(Senha s) => repo.iniciarAtendimento(s);

  void assumirEmergencia(Senha s) =>
      repo.iniciarAtendimento(s, medico: nomeProfissional, consultorio: consultorio);

  void encerrar(Senha s, Desfecho d, String obs) => repo.encerrar(s, d, obs);
}
