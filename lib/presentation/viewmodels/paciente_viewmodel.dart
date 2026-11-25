import 'dart:async';

import '../../data/fila_repository.dart';
import '../../domain/entities.dart';
import 'base_viewmodel.dart';
import 'session_viewmodel.dart';

class PacienteViewModel extends AreaViewModel {
  PacienteViewModel(super.repo, this.session) {
    // Só repassa à tela os eventos da senha deste paciente.
    _sub = repo.eventos.listen((e) {
      final s = repo.senhaPorId(e.senhaId);
      if (s != null && s.pacienteId == session.pacienteId) _eventos.add(e);
    });
  }

  final SessionViewModel session;
  late final StreamSubscription<FilaEvento> _sub;
  final _eventos = StreamController<FilaEvento>.broadcast();

  Stream<FilaEvento> get eventos => _eventos.stream;

  TipoAtendimento tipo = TipoAtendimento.urgencia;

  Paciente? get paciente => session.paciente;

  Unidade get unidade => repo.unidade(session.unidadeId);

  List<Unidade> get unidades => repo.unidades;

  int aguardandoNa(Unidade u) => repo.aguardando(u.id);

  Senha? get senhaAtiva => paciente == null ? null : repo.senhaAtiva(paciente!.id);

  Senha? get pendenteAvaliacao => paciente == null ? null : repo.pendenteDeAvaliacao(paciente!.id);

  PosicaoFila? get posicao => senhaAtiva == null ? null : repo.posicao(senhaAtiva!);

  List<Senha> get historico => paciente == null ? const [] : repo.historicoDoPaciente(paciente!.id);

  Unidade unidadeDe(Senha s) => repo.unidade(s.unidadeId);

  Senha? senha(String id) => repo.senhaPorId(id);

  void escolherTipo(TipoAtendimento t) {
    tipo = t;
    notifyListeners();
  }

  void escolherUnidade(Unidade u) => session.escolherUnidade(u.id);

  RetiradaResultado retirarSenha() => repo.retirarSenha(
        paciente: paciente!,
        unidade: unidade,
        tipo: tipo,
        origem: OrigemSenha.app,
      );

  void desistir() {
    final s = senhaAtiva;
    if (s != null) repo.desistir(s);
  }

  void avaliar(Senha s, int nota, String comentario) => repo.avaliar(s, nota, comentario);

  void atualizarPerfil({required String nome, required String telefone, required DateTime nascimento}) =>
      repo.atualizarPaciente(paciente!, nome: nome, telefone: telefone, nascimento: nascimento);

  void excluirConta() {
    final id = paciente!.id;
    session.sair();
    repo.excluirPaciente(id);
  }

  @override
  void dispose() {
    _sub.cancel();
    _eventos.close();
    super.dispose();
  }
}
