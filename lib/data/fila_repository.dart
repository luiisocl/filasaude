// Repositório central (camada de dados). Guarda o estado da fila em memória,
// persiste no cache local e simula o tempo real de uma unidade de saúde.
//
// As telas não falam com ele diretamente: cada área usa um ViewModel
// (padrão MVVM), que lê daqui e expõe só o que a tela precisa.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/perf.dart';
import '../domain/entities.dart';
import '../domain/fila_rules.dart';
import 'historico.dart';
import 'local_cache.dart';
import 'seed.dart';
import 'sync.dart';

// ---- eventos enviados às telas -------------------------------------------

sealed class FilaEvento {
  const FilaEvento(this.senhaId);
  final String senhaId;
}

class FaltamTres extends FilaEvento {
  const FaltamTres(super.senhaId);
}

class VoceFoiChamado extends FilaEvento {
  const VoceFoiChamado(super.senhaId);
}

class SenhaEncerrada extends FilaEvento {
  const SenhaEncerrada(super.senhaId, this.motivo);
  final String motivo;
}

class AlertaVermelho extends FilaEvento {
  const AlertaVermelho(super.senhaId);
}

// ---- tipos auxiliares -----------------------------------------------------

class PosicaoFila {
  const PosicaoFila(this.pessoasAFrente, this.tempoEstimado);
  final int pessoasAFrente;

  /// null = nenhum médico disponível (EX12).
  final Duration? tempoEstimado;
}

enum ResultadoRetirada { ok, jaPossui, unidadeFechada }

class RetiradaResultado {
  const RetiradaResultado(this.resultado, this.senha);
  final ResultadoRetirada resultado;
  final Senha? senha;
}

class ChamadaPainel {
  const ChamadaPainel(this.codigo, this.consultorio, this.hora);
  final String codigo;
  final int consultorio;
  final DateTime hora;
}

class EnvioStats {
  int operacoes = 0;
  int bytesJson = 0;
  int bytesGzip = 0;
  int? ultimoLoteMs;

  double get economiaPct => bytesJson == 0 ? 0 : (1 - bytesGzip / bytesJson) * 100;
}

// ---------------------------------------------------------------------------

class FilaRepository extends ChangeNotifier {
  FilaRepository(this._cache);

  static const _chaveEstado = 'estado_v1';

  final LocalCache _cache;
  final _rand = Random();

  final List<Unidade> unidades = [];
  final Map<String, Paciente> pacientes = {};
  final List<Senha> senhas = [];
  final List<Funcionario> funcionarios = [];
  final Map<String, int> medicosAtivos = {};
  final List<ChamadaPainel> ultimasChamadas = [];
  final Map<String, int> _contadores = {};
  final Set<String> _avisadosTres = {};

  final _eventos = StreamController<FilaEvento>.broadcast();
  Stream<FilaEvento> get eventos => _eventos.stream;

  Timer? _relogio;
  Timer? _simulador;
  Timer? _salvarDebounce;
  int _seqSim = 0;
  bool _descartado = false;

  /// Simulação de outros pacientes chegando e sendo atendidos.
  bool simulacaoAtiva = true;

  // ---- rede / sincronização ----
  bool _online = true;
  bool _enviando = false;
  final envio = EnvioStats();

  bool get online => _online;
  int get operacoesPendentes => _cache.pendentes;

  // ---- histórico (relatórios) ----
  HistoricoCompacto? historico;
  List<Map<String, Object>>? historicoObjetos;
  bool carregandoHistorico = false;
  int? historicoMs;

  bool get historicoPronto => historico != null || historicoObjetos != null;
  int get historicoTamanho => historico?.length ?? historicoObjetos?.length ?? 0;

  // =========================================================================
  // Inicialização e persistência

  Future<void> carregar() async {
    final bruto = _cache.ler(_chaveEstado);
    var restaurado = false;
    if (bruto != null) {
      try {
        _aplicarSnapshot(jsonDecode(bruto) as Map<String, dynamic>);
        restaurado = true;
      } catch (e) {
        debugPrint('Cache inválido, recriando dados: $e');
      }
    }
    if (!restaurado) _semear();
    _verificarPrazos();
    _relogio = Timer.periodic(const Duration(seconds: 20), (_) => _verificarPrazos());
    _simulador = Timer.periodic(const Duration(seconds: 15), (_) => _simular());
    unawaited(_enviarPendentes());
  }

  @override
  void dispose() {
    _descartado = true;
    // Evita vazamento de memória: timers e streams vivos seguram o objeto.
    _relogio?.cancel();
    _simulador?.cancel();
    _salvarDebounce?.cancel();
    _eventos.close();
    super.dispose();
  }

  void _mudou() {
    if (_descartado) return;
    _verificarEventos();
    notifyListeners();
    if (PerfConfig.otimizado.value) {
      // Otimizado: junta várias mudanças seguidas numa única gravação.
      _salvarDebounce?.cancel();
      _salvarDebounce = Timer(const Duration(milliseconds: 800), _salvar);
    } else {
      // Antes: serializa e grava o estado inteiro a cada mudança.
      _salvar();
    }
  }

  void _salvar() {
    final mapa = {
      'unidades': unidades.map((u) => u.toJson()).toList(),
      'pacientes': pacientes.values.map((p) => p.toJson()).toList(),
      'senhas': senhas.map((s) => s.toJson()).toList(),
      'funcionarios': funcionarios.map((f) => f.toJson()).toList(),
      'medicos': medicosAtivos,
      'contadores': _contadores,
      'seqSim': _seqSim,
    };
    unawaited(_cache.salvar(_chaveEstado, jsonEncode(mapa)));
  }

  void _aplicarSnapshot(Map<String, dynamic> j) {
    List<Map<String, dynamic>> lista(String k) =>
        (j[k] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    unidades
      ..clear()
      ..addAll(lista('unidades').map(Unidade.fromJson));
    pacientes
      ..clear()
      ..addEntries(lista('pacientes').map(Paciente.fromJson).map((p) => MapEntry(p.id, p)));
    senhas
      ..clear()
      ..addAll(lista('senhas').map(Senha.fromJson));
    funcionarios
      ..clear()
      ..addAll(lista('funcionarios').map(Funcionario.fromJson));
    medicosAtivos
      ..clear()
      ..addAll(Map<String, int>.from(j['medicos'] as Map));
    _contadores
      ..clear()
      ..addAll(Map<String, int>.from(j['contadores'] as Map));
    _seqSim = j['seqSim'] as int? ?? 0;
    // Senhas de dias anteriores que ficaram abertas são encerradas.
    final hoje = DateTime.now();
    for (final s in senhas) {
      if (s.etapa.ativa && !_mesmoDia(s.retiradaEm, hoje)) s.etapa = EtapaSenha.expirada;
    }
  }

  static bool _mesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Apaga tudo e recria os dados de demonstração.
  Future<void> reiniciarDemonstracao() async {
    await _cache.limparTudo();
    unidades.clear();
    pacientes.clear();
    senhas.clear();
    funcionarios.clear();
    medicosAtivos.clear();
    ultimasChamadas.clear();
    _contadores.clear();
    _avisadosTres.clear();
    _semear();
    _mudou();
  }

  void _semear() {
    unidades.addAll(Seed.unidades());
    funcionarios.addAll(Seed.funcionarios());
    for (final u in unidades) {
      medicosAtivos[u.id] = u.ehUpa ? 2 : 1;
    }
    final demo = Seed.pacienteDemo();
    pacientes[demo.id] = demo;

    // Atendimentos anteriores da paciente de demonstração (tela Histórico).
    final agora = DateTime.now();
    final antigas = [
      (agora.subtract(const Duration(days: 41)), CorRisco.amarelo, Desfecho.alta, 5),
      (agora.subtract(const Duration(days: 120)), CorRisco.verde, Desfecho.retorno, 4),
    ];
    for (final (data, cor, desf, nota) in antigas) {
      final s = Senha(
        id: 'hist-${data.millisecondsSinceEpoch}',
        codigo: 'U-0${10 + _rand.nextInt(80)}',
        pacienteId: demo.id,
        unidadeId: Seed.unidadePrincipal,
        tipo: TipoAtendimento.urgencia,
        origem: OrigemSenha.app,
        retiradaEm: data,
        etapa: EtapaSenha.finalizado,
      )
        ..chegadaEm = data.add(const Duration(minutes: 20))
        ..triagem = Triagem(
          cor: cor,
          queixa: Seed.queixas[_rand.nextInt(Seed.queixas.length)],
          sinais: Seed.sinaisSimulados(_rand),
          enfermeiro: 'Enf. Rafael Sousa',
          horario: data.add(const Duration(minutes: 30)),
        )
        ..medico = 'Dra. Helena Rocha'
        ..consultorio = 2
        ..finalizadoEm = data.add(const Duration(hours: 1, minutes: 25))
        ..desfecho = desf
        ..avaliacao = nota;
      senhas.add(s);
    }

    // Fila já em andamento na UPA Centro e em outras unidades.
    for (var i = 0; i < 9; i++) {
      _criarSimulada(Seed.unidadePrincipal, triar: i < 6, minutosAtras: 70 - i * 7);
    }
    for (var i = 0; i < 4; i++) {
      _criarSimulada('upa-norte', triar: i < 3, minutosAtras: 40 - i * 8);
    }
    for (var i = 0; i < 2; i++) {
      _criarSimulada('ubs-satelite', triar: true, minutosAtras: 30 - i * 10);
    }
  }

  Senha _criarSimulada(String unidadeId, {required bool triar, int minutosAtras = 0}) {
    final p = Seed.pacienteSimulado(_rand, ++_seqSim);
    pacientes[p.id] = p;
    final chegada = DateTime.now().subtract(Duration(minutes: minutosAtras));
    final s = Senha(
      id: 's-${p.id}',
      codigo: _proximoCodigo(unidadeId, TipoAtendimento.urgencia),
      pacienteId: p.id,
      unidadeId: unidadeId,
      tipo: TipoAtendimento.urgencia,
      origem: OrigemSenha.presencial,
      retiradaEm: chegada,
      etapa: EtapaSenha.aguardandoTriagem,
      prioridade: p.idade(DateTime.now()) >= 60 ? PrioridadeLegal.idoso : PrioridadeLegal.nenhuma,
      simulada: true,
    )
      ..chegadaEm = chegada
      ..ordemFila = chegada;
    if (triar) {
      s
        ..etapa = EtapaSenha.aguardandoMedico
        ..triagem = Triagem(
          cor: Seed.corSimulada(_rand),
          queixa: Seed.queixas[_rand.nextInt(Seed.queixas.length)],
          sinais: Seed.sinaisSimulados(_rand),
          enfermeiro: 'Enf. plantonista',
          horario: chegada.add(const Duration(minutes: 4)),
        );
    }
    senhas.add(s);
    return s;
  }

  String _proximoCodigo(String unidadeId, TipoAtendimento tipo) {
    final chave = '$unidadeId-${tipo.prefixo}';
    final n = (_contadores[chave] ?? 40) + 1;
    _contadores[chave] = n;
    return '${tipo.prefixo}-${n.toString().padLeft(3, '0')}';
  }

  // =========================================================================
  // Consultas

  Unidade unidade(String id) => unidades.firstWhere((u) => u.id == id, orElse: () => unidades.first);

  Paciente? paciente(String id) => pacientes[id];

  Senha? senhaPorId(String id) {
    for (final s in senhas) {
      if (s.id == id) return s;
    }
    return null;
  }

  Paciente? pacientePorDocumento(String doc) {
    final d = doc.replaceAll(RegExp(r'\D'), '');
    for (final p in pacientes.values) {
      if (p.documento == d) return p;
    }
    return null;
  }

  /// RN06: só uma senha ativa por paciente.
  Senha? senhaAtiva(String pacienteId) {
    for (final s in senhas) {
      if (s.pacienteId == pacienteId && s.etapa.ativa) return s;
    }
    return null;
  }

  /// Atendimento encerrado ainda sem avaliação (RF18).
  Senha? pendenteDeAvaliacao(String pacienteId) {
    for (final s in senhas.reversed) {
      if (s.pacienteId == pacienteId &&
          s.etapa == EtapaSenha.finalizado &&
          s.avaliacao == null &&
          DateTime.now().difference(s.finalizadoEm ?? s.retiradaEm).inHours < 24) {
        return s;
      }
    }
    return null;
  }

  List<Senha> historicoDoPaciente(String pacienteId) =>
      senhas.where((s) => s.pacienteId == pacienteId && !s.etapa.ativa).toList()
        ..sort((a, b) => b.retiradaEm.compareTo(a.retiradaEm));

  List<Senha> filaChegada(String unidadeId) => senhas
      .where((s) => s.unidadeId == unidadeId && s.etapa == EtapaSenha.aguardandoChegada)
      .toList()
    ..sort((a, b) => a.retiradaEm.compareTo(b.retiradaEm));

  List<Senha> filaTriagem(String unidadeId) => senhas
      .where((s) => s.unidadeId == unidadeId && s.etapa == EtapaSenha.aguardandoTriagem)
      .toList()
    ..sort(FilaRules.compararTriagem);

  List<Senha> filaMedico(String unidadeId) => senhas
      .where((s) => s.unidadeId == unidadeId && s.etapa == EtapaSenha.aguardandoMedico)
      .toList()
    ..sort(FilaRules.comparar);

  List<Senha> chamadosOuEmAtendimento(String unidadeId) => senhas
      .where((s) =>
          s.unidadeId == unidadeId && (s.etapa == EtapaSenha.chamado || s.etapa == EtapaSenha.emAtendimento))
      .toList();

  List<Senha> emergencias(String unidadeId) =>
      senhas.where((s) => s.unidadeId == unidadeId && s.etapa == EtapaSenha.emergencia).toList();

  List<Senha> atendidasHoje(String unidadeId) {
    final hoje = DateTime.now();
    return senhas
        .where((s) =>
            s.unidadeId == unidadeId &&
            (s.etapa == EtapaSenha.finalizado || s.etapa == EtapaSenha.desistiu) &&
            _mesmoDia(s.finalizadoEm ?? s.retiradaEm, hoje))
        .toList();
  }

  int aguardando(String unidadeId) => senhas
      .where((s) =>
          s.unidadeId == unidadeId &&
          (s.etapa == EtapaSenha.aguardandoTriagem || s.etapa == EtapaSenha.aguardandoMedico))
      .length;

  PosicaoFila posicao(Senha s) {
    final medicos = medicosAtivos[s.unidadeId] ?? 0;
    switch (s.etapa) {
      case EtapaSenha.aguardandoChegada:
        final n = aguardando(s.unidadeId);
        return PosicaoFila(n, FilaRules.tempoEstimado(pessoasAFrente: n, medicosAtivos: medicos));
      case EtapaSenha.aguardandoTriagem:
        final i = filaTriagem(s.unidadeId).indexWhere((x) => x.id == s.id);
        return PosicaoFila(
          i,
          Duration(minutes: (i + 1) * FilaRules.mediaTriagemMin) +
              (FilaRules.tempoEstimado(
                    pessoasAFrente: filaMedico(s.unidadeId).length,
                    medicosAtivos: medicos,
                  ) ??
                  Duration.zero),
        );
      case EtapaSenha.aguardandoMedico:
        final i = filaMedico(s.unidadeId).indexWhere((x) => x.id == s.id);
        return PosicaoFila(i, FilaRules.tempoEstimado(pessoasAFrente: i, medicosAtivos: medicos));
      default:
        return const PosicaoFila(0, Duration.zero);
    }
  }

  Funcionario? autenticar(String email, String senha) {
    for (final f in funcionarios) {
      if (f.ativo && f.email.toLowerCase() == email.trim().toLowerCase() && f.senha == senha) return f;
    }
    return null;
  }

  // =========================================================================
  // Ações do paciente

  Paciente cadastrarPaciente({
    required String nome,
    required DateTime nascimento,
    required String telefone,
    required String documento,
  }) {
    final p = Paciente(
      id: 'p-${DateTime.now().microsecondsSinceEpoch}',
      nome: nome.trim(),
      nascimento: nascimento,
      telefone: telefone,
      documento: documento.replaceAll(RegExp(r'\D'), ''),
    );
    pacientes[p.id] = p;
    _registrar('paciente.cadastro', {'id': p.id});
    _mudou();
    return p;
  }

  void atualizarPaciente(Paciente p, {String? nome, String? telefone, DateTime? nascimento}) {
    if (nome != null) p.nome = nome.trim();
    if (telefone != null) p.telefone = telefone;
    if (nascimento != null) p.nascimento = nascimento;
    _registrar('paciente.atualizar', {'id': p.id});
    _mudou();
  }

  /// LGPD: exclui o paciente e os atendimentos dele.
  void excluirPaciente(String id) {
    pacientes.remove(id);
    senhas.removeWhere((s) => s.pacienteId == id);
    _registrar('paciente.excluir', {'id': id});
    _mudou();
  }

  RetiradaResultado retirarSenha({
    required Paciente paciente,
    required Unidade unidade,
    required TipoAtendimento tipo,
    required OrigemSenha origem,
  }) {
    final ativa = senhaAtiva(paciente.id);
    if (ativa != null) return RetiradaResultado(ResultadoRetirada.jaPossui, ativa);
    final agora = DateTime.now();
    if (!unidade.estaAberta(agora)) return const RetiradaResultado(ResultadoRetirada.unidadeFechada, null);
    final s = Senha(
      id: 'sen-${agora.microsecondsSinceEpoch}',
      codigo: _proximoCodigo(unidade.id, tipo),
      pacienteId: paciente.id,
      unidadeId: unidade.id,
      tipo: tipo,
      origem: origem,
      retiradaEm: agora,
      prioridade: paciente.idade(agora) >= 60 ? PrioridadeLegal.idoso : PrioridadeLegal.nenhuma,
    );
    if (origem == OrigemSenha.presencial) {
      s
        ..etapa = EtapaSenha.aguardandoTriagem
        ..chegadaEm = agora
        ..ordemFila = agora;
    }
    senhas.add(s);
    _registrar('senha.retirar', {'id': s.id, 'codigo': s.codigo, 'unidade': unidade.id});
    _mudou();
    return RetiradaResultado(ResultadoRetirada.ok, s);
  }

  void desistir(Senha s) {
    s
      ..etapa = EtapaSenha.desistiu
      ..finalizadoEm = DateTime.now();
    _registrar('senha.desistir', {'id': s.id});
    _mudou();
  }

  void avaliar(Senha s, int nota, String comentario) {
    s
      ..avaliacao = nota
      ..comentarioAvaliacao = comentario.trim().isEmpty ? null : comentario.trim();
    _registrar('senha.avaliar', {'id': s.id, 'nota': nota});
    _mudou();
  }

  // =========================================================================
  // Recepção

  void confirmarChegada(Senha s, PrioridadeLegal prioridade) {
    final agora = DateTime.now();
    s
      ..etapa = EtapaSenha.aguardandoTriagem
      ..prioridade = prioridade
      ..chegadaEm = agora
      ..ordemFila = agora;
    _registrar('senha.chegada', {'id': s.id, 'prioridade': prioridade.index});
    _mudou();
  }

  // =========================================================================
  // Enfermagem

  void classificar(Senha s, {required CorRisco cor, required String queixa, required SinaisVitais sinais, required String enfermeiro}) {
    final agora = DateTime.now();
    s.triagem = Triagem(
      cor: cor,
      queixa: queixa,
      sinais: sinais,
      enfermeiro: enfermeiro,
      horario: agora,
      historico: [
        Reclassificacao(de: null, para: cor, motivo: 'Classificação inicial', responsavel: enfermeiro, horario: agora),
      ],
    );
    s.ordemFila ??= s.chegadaEm ?? agora;
    _aplicarCor(s, cor);
    _registrar('triagem.classificar', {'id': s.id, 'cor': cor.index, 'sinais': sinais.toJson()});
    _mudou();
  }

  void reclassificar(Senha s, {required CorRisco cor, required String motivo, required String enfermeiro}) {
    final t = s.triagem;
    if (t == null) return;
    final agora = DateTime.now();
    t.historico.add(Reclassificacao(de: t.cor, para: cor, motivo: motivo, responsavel: enfermeiro, horario: agora));
    t
      ..cor = cor
      ..horario = agora;
    _aplicarCor(s, cor);
    _registrar('triagem.reclassificar', {'id': s.id, 'cor': cor.index, 'motivo': motivo});
    _mudou();
  }

  /// RN02: vermelho não entra na fila e gera alerta imediato.
  void _aplicarCor(Senha s, CorRisco cor) {
    if (cor == CorRisco.vermelho) {
      s.etapa = EtapaSenha.emergencia;
      _eventos.add(AlertaVermelho(s.id));
    } else {
      s.etapa = EtapaSenha.aguardandoMedico;
    }
  }

  // =========================================================================
  // Médico

  Senha? chamarProximo(String unidadeId, {required String medico, required int consultorio}) {
    final fila = filaMedico(unidadeId);
    if (fila.isEmpty) return null;
    final s = fila.first;
    _chamar(s, medico: medico, consultorio: consultorio);
    return s;
  }

  void _chamar(Senha s, {required String medico, required int consultorio}) {
    final agora = DateTime.now();
    s
      ..etapa = EtapaSenha.chamado
      ..chamadas += 1
      ..ultimaChamadaEm = agora
      ..medico = medico
      ..consultorio = consultorio;
    ultimasChamadas.insert(0, ChamadaPainel(s.codigo, consultorio, agora));
    if (ultimasChamadas.length > 6) ultimasChamadas.removeLast();
    if (!s.simulada) _eventos.add(VoceFoiChamado(s.id));
    _registrar('medico.chamar', {'id': s.id, 'consultorio': consultorio, 'chamada': s.chamadas});
    _mudou();
  }

  void rechamar(Senha s) => _chamar(s, medico: s.medico ?? '', consultorio: s.consultorio ?? 1);

  /// RN07: 2 chamadas sem resposta → fim da fila da cor; na 3ª → cancelada.
  void naoCompareceu(Senha s) {
    if (s.chamadas >= 3) {
      s
        ..etapa = EtapaSenha.cancelada
        ..finalizadoEm = DateTime.now();
      _eventos.add(SenhaEncerrada(s.id, 'Senha cancelada após 3 chamadas sem resposta.'));
    } else {
      s.etapa = EtapaSenha.aguardandoMedico;
      if (s.chamadas >= 2) s.ordemFila = DateTime.now();
    }
    _registrar('medico.ausente', {'id': s.id, 'chamadas': s.chamadas});
    _mudou();
  }

  void iniciarAtendimento(Senha s, {String? medico, int? consultorio}) {
    s
      ..etapa = EtapaSenha.emAtendimento
      ..atendimentoInicio = DateTime.now();
    if (medico != null) s.medico = medico;
    if (consultorio != null) s.consultorio = consultorio;
    _registrar('medico.iniciar', {'id': s.id});
    _mudou();
  }

  void encerrar(Senha s, Desfecho desfecho, String observacao) {
    s
      ..etapa = EtapaSenha.finalizado
      ..finalizadoEm = DateTime.now()
      ..desfecho = desfecho
      ..observacao = observacao.trim().isEmpty ? null : observacao.trim();
    _registrar('medico.encerrar', {'id': s.id, 'desfecho': desfecho.index});
    _mudou();
  }

  // =========================================================================
  // Coordenação

  void salvarFuncionario(Funcionario f) {
    final i = funcionarios.indexWhere((x) => x.id == f.id);
    if (i >= 0) {
      funcionarios[i] = f;
    } else {
      funcionarios.add(f);
    }
    _registrar('equipe.salvar', {'id': f.id});
    _mudou();
  }

  bool emailEmUso(String email, {String? exceto}) =>
      funcionarios.any((f) => f.id != exceto && f.email.toLowerCase() == email.trim().toLowerCase());

  void alternarAtivo(Funcionario f) {
    f.ativo = !f.ativo;
    _registrar('equipe.ativo', {'id': f.id, 'ativo': f.ativo});
    _mudou();
  }

  void atualizarUnidade(Unidade u, {required String nome, required int abre, required int fecha, required int consultorios, required int medicos}) {
    u
      ..nome = nome
      ..abre = abre
      ..fecha = fecha
      ..consultorios = consultorios;
    medicosAtivos[u.id] = medicos;
    _registrar('unidade.atualizar', {'id': u.id});
    _mudou();
  }

  // =========================================================================
  // Relógio: prazos (RN05, RN07) e avisos ao paciente

  void _verificarPrazos() {
    final agora = DateTime.now();
    var mudou = false;
    for (final s in senhas) {
      if (FilaRules.expirou(s, agora)) {
        s.etapa = EtapaSenha.expirada;
        _eventos.add(SenhaEncerrada(s.id, 'Sua senha expirou: a chegada não foi confirmada em 1 hora.'));
        mudou = true;
      } else if (s.etapa == EtapaSenha.chamado &&
          s.ultimaChamadaEm != null &&
          agora.difference(s.ultimaChamadaEm!) > FilaRules.prazoChamada) {
        naoCompareceu(s);
        return;
      }
    }
    if (mudou) _mudou();
  }

  void _verificarEventos() {
    for (final u in unidades) {
      final fila = filaMedico(u.id);
      for (var i = 0; i < fila.length && i <= 3; i++) {
        final s = fila[i];
        if (!s.simulada && i <= 3 && _avisadosTres.add(s.id)) {
          _eventos.add(FaltamTres(s.id));
        }
      }
    }
  }

  // =========================================================================
  // Simulação de uma unidade em funcionamento (outros pacientes)

  void _simular() {
    if (!simulacaoAtiva || _descartado) return;
    final agora = DateTime.now();
    for (final u in unidades) {
      // Médico plantonista atende o 1º da fila, se for um paciente simulado.
      final fila = filaMedico(u.id);
      if (fila.isNotEmpty && fila.first.simulada && _rand.nextInt(100) < 70) {
        fila.first
          ..etapa = EtapaSenha.finalizado
          ..medico = 'Médico plantonista'
          ..consultorio = 1 + _rand.nextInt(u.consultorios)
          ..atendimentoInicio = agora
          ..finalizadoEm = agora
          ..desfecho = Desfecho.alta;
      }
      // Enfermagem de plantão classifica um paciente simulado.
      final triagem = filaTriagem(u.id).where((s) => s.simulada).toList();
      if (triagem.isNotEmpty && _rand.nextInt(100) < 45) {
        final s = triagem.first;
        s.triagem = Triagem(
          cor: Seed.corSimulada(_rand),
          queixa: Seed.queixas[_rand.nextInt(Seed.queixas.length)],
          sinais: Seed.sinaisSimulados(_rand),
          enfermeiro: 'Enf. plantonista',
          horario: agora,
        );
        s.etapa = EtapaSenha.aguardandoMedico;
      }
      // Chegam novos pacientes para manter a fila viva.
      final limite = u.id == Seed.unidadePrincipal ? 10 : 5;
      if (aguardando(u.id) < limite && u.estaAberta(agora) && _rand.nextInt(100) < 55) {
        _criarSimulada(u.id, triar: false);
      }
    }
    // Remove simulados antigos para a lista não crescer sem limite (memória).
    senhas.removeWhere((s) =>
        s.simulada && !s.etapa.ativa && agora.difference(s.finalizadoEm ?? s.retiradaEm).inHours >= 6);
    pacientes.removeWhere((id, p) => p.simulado && !senhas.any((s) => s.pacienteId == id));
    _mudou();
  }

  // =========================================================================
  // Rede: outbox + envio comprimido

  void definirOnline(bool valor) {
    _online = valor;
    notifyListeners();
    if (valor) unawaited(_enviarPendentes());
  }

  void _registrar(String tipo, Map<String, dynamic> dados) {
    final op = jsonEncode({'tipo': tipo, 'dados': dados, 'em': DateTime.now().toIso8601String()});
    unawaited(_cache.enfileirar(op).then((_) => _enviarPendentes()));
  }

  Future<void> _enviarPendentes() async {
    if (!_online || _enviando || _descartado) return;
    _enviando = true;
    try {
      while (_online && _cache.pendentes > 0 && !_descartado) {
        final lote = _cache.lote(50);
        final cronometro = Stopwatch()..start();
        final operacoes = [for (final e in lote) e.value];
        final compactado = PerfConfig.otimizado.value
            ? await compute(compactarLote, operacoes)
            : compactarLote(operacoes);
        // Latência simulada do servidor.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        cronometro.stop();
        await _cache.confirmarEnvio(lote.map((e) => e.key));
        envio
          ..operacoes += lote.length
          ..bytesJson += compactado.bytesJson
          ..bytesGzip += compactado.bytesGzip
          ..ultimoLoteMs = cronometro.elapsedMilliseconds;
        if (!_descartado) notifyListeners();
      }
    } finally {
      _enviando = false;
    }
  }

  // =========================================================================
  // Histórico para relatórios

  /// Usado ao trocar o modo otimizado/não otimizado: o histórico é gerado
  /// de novo no formato correspondente.
  void descartarHistorico() {
    historico = null;
    historicoObjetos = null;
    historicoMs = null;
    notifyListeners();
  }

  Future<void> carregarHistorico() async {
    if (historicoPronto || carregandoHistorico) return;
    carregandoHistorico = true;
    notifyListeners();
    final cronometro = Stopwatch()..start();
    final params = GeracaoParams(PerfConfig.registrosHistorico, diaDe(DateTime.now()));
    if (PerfConfig.otimizado.value) {
      // Depois: gera os dados em outro Isolate, em arrays tipados.
      historico = await compute(gerarHistoricoCompacto, params);
    } else {
      // Antes: gera 200 mil mapas na thread da interface.
      historicoObjetos = gerarHistoricoObjetos(params);
    }
    historicoMs = cronometro.elapsedMilliseconds;
    carregandoHistorico = false;
    if (!_descartado) notifyListeners();
  }
}
