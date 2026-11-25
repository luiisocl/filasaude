import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/fila_repository.dart';
import '../../data/local_cache.dart';
import '../../data/seed.dart';
import '../../domain/entities.dart';

/// Quem está logado. A sessão fica no cache: ao reabrir o app, a pessoa
/// cai direto na sua área (cold start mais curto, sem novo login).
class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._repo, this._cache);

  static const _chave = 'sessao';

  final FilaRepository _repo;
  final LocalCache _cache;

  Perfil? perfil;
  String? pacienteId;
  String? funcionarioId;

  /// Unidade escolhida pelo paciente / unidade de trabalho do profissional.
  String unidadeId = Seed.unidadePrincipal;

  Paciente? get paciente => pacienteId == null ? null : _repo.paciente(pacienteId!);

  Funcionario? get funcionario {
    for (final f in _repo.funcionarios) {
      if (f.id == funcionarioId) return f;
    }
    return null;
  }

  void restaurar() {
    final bruto = _cache.ler(_chave);
    if (bruto == null) return;
    try {
      final j = jsonDecode(bruto) as Map<String, dynamic>;
      perfil = j['perfil'] == null ? null : Perfil.values[j['perfil'] as int];
      pacienteId = j['paciente'] as String?;
      funcionarioId = j['funcionario'] as String?;
      unidadeId = j['unidade'] as String? ?? Seed.unidadePrincipal;
      // Conta apagada ou dados reiniciados: volta para o login.
      if ((perfil == Perfil.paciente && paciente == null) ||
          (perfil != null && perfil != Perfil.paciente && funcionario == null)) {
        perfil = null;
      }
    } catch (_) {
      perfil = null;
    }
  }

  void entrarPaciente(Paciente p) {
    perfil = Perfil.paciente;
    pacienteId = p.id;
    funcionarioId = null;
    _salvarENotificar();
  }

  void entrarFuncionario(Funcionario f) {
    perfil = f.perfil;
    funcionarioId = f.id;
    pacienteId = null;
    unidadeId = Seed.unidadePrincipal;
    _salvarENotificar();
  }

  void escolherUnidade(String id) {
    unidadeId = id;
    _salvarENotificar();
  }

  void sair() {
    perfil = null;
    pacienteId = null;
    funcionarioId = null;
    _salvarENotificar();
  }

  void _salvarENotificar() {
    unawaited(_cache.salvar(
      _chave,
      jsonEncode({
        'perfil': perfil?.index,
        'paciente': pacienteId,
        'funcionario': funcionarioId,
        'unidade': unidadeId,
      }),
    ));
    notifyListeners();
  }
}
