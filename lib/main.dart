import 'package:flutter/material.dart';

import 'app.dart';
import 'core/perf.dart';

/// Cronômetro do cold start: começa aqui e para no primeiro frame.
final cronometroInicio = Stopwatch();

void main() {
  cronometroInicio.start();
  WidgetsFlutterBinding.ensureInitialized();
  PerfMonitor.instance.iniciar();
  // Otimização de cold start: o primeiro frame (splash) é desenhado já,
  // antes de abrir o banco local e carregar os dados. Nada pesado roda
  // antes do runApp.
  runApp(const FilaSaudeApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PerfConfig.coldStartMs ??= cronometroInicio.elapsedMilliseconds;
  });
}
