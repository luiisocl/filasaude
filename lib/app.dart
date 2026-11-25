import 'dart:async';

import 'package:flutter/material.dart';

import 'core/perf.dart';
import 'core/scope.dart';
import 'core/theme.dart';
import 'data/fila_repository.dart';
import 'data/local_cache.dart';
import 'domain/entities.dart';
import 'main.dart' show cronometroInicio;
import 'presentation/screens/auth_screens.dart';
import 'presentation/screens/coordenador/coordenador_shell.dart';
import 'presentation/screens/enfermeiro/enfermeiro_shell.dart';
import 'presentation/screens/medico/medico_shell.dart';
import 'presentation/screens/paciente/paciente_shell.dart';
import 'presentation/screens/recepcao/recepcao_shell.dart';
import 'presentation/viewmodels/session_viewmodel.dart';
import 'presentation/widgets/perf_overlay.dart';

class FilaSaudeApp extends StatefulWidget {
  const FilaSaudeApp({super.key});

  @override
  State<FilaSaudeApp> createState() => _FilaSaudeAppState();
}

class _FilaSaudeAppState extends State<FilaSaudeApp> {
  final _cache = LocalCache();
  FilaRepository? _repo;
  SessionViewModel? _session;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    unawaited(_iniciar());
  }

  Future<void> _iniciar() async {
    try {
      await _cache.init();
      PerfConfig.otimizado.value = _cache.ler(PerfConfig.chave) != 'false';
      final repo = FilaRepository(_cache);
      if (!PerfConfig.otimizado.value) {
        // "Antes": gera o histórico pesado durante a abertura, na thread da
        // interface. A splash congela e o cold start fica bem mais longo.
        await repo.carregarHistorico();
      }
      await repo.carregar();
      final session = SessionViewModel(repo, _cache)..restaurar();
      if (!mounted) return;
      setState(() {
        _repo = repo;
        _session = session;
      });
      PerfConfig.prontoMs = cronometroInicio.elapsedMilliseconds;
    } catch (e) {
      setState(() => _erro = e);
    }
  }

  @override
  void dispose() {
    _repo?.dispose();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    final session = _session;
    final Widget home;
    if (_erro != null) {
      home = Scaffold(body: Center(child: Text('Erro ao iniciar: $_erro')));
    } else if (repo == null || session == null) {
      home = const SplashScreen();
    } else {
      home = _Raiz(session: session);
    }
    final app = MaterialApp(
      title: 'FilaSaúde',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      home: home,
      builder: (context, child) => PerfOverlay(child: child ?? const SizedBox()),
    );
    if (repo == null || session == null) return app;
    return AppScope(repo: repo, session: session, cache: _cache, child: app);
  }
}

/// Escolhe a área de acordo com o perfil logado.
class _Raiz extends StatelessWidget {
  const _Raiz({required this.session});
  final SessionViewModel session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) => switch (session.perfil) {
          null => const BoasVindasScreen(),
          Perfil.paciente => PacienteShell(key: ValueKey(session.pacienteId)),
          Perfil.recepcao => const RecepcaoShell(),
          Perfil.enfermeiro => const EnfermeiroShell(),
          Perfil.medico => MedicoShell(key: ValueKey(session.funcionarioId)),
          Perfil.coordenador => const CoordenadorShell(),
        },
      );
}

/// Sair: volta para a primeira rota e limpa a sessão.
void sair(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  AppScope.of(context).session.sair();
}
