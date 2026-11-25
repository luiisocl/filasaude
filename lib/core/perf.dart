// Configuração e medição de performance.
//
// - PerfConfig.otimizado liga/desliga as otimizações, para a comparação
//   "antes x depois" pedida na apresentação (parte 5). O valor fica salvo
//   no cache e vale a partir da próxima abertura do app.
// - PerfMonitor lê os tempos reais de cada frame desenhado pelo Flutter
//   (SchedulerBinding.addTimingsCallback) e calcula FPS e quadros com
//   engasgo (jank). Os números são medidos no aparelho, não estimados.
import 'dart:collection';
import 'dart:ui' show FrameTiming, FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class PerfConfig {
  PerfConfig._();

  static const chave = 'perf_otimizado';

  /// Otimizações ligadas (padrão).
  static final otimizado = ValueNotifier<bool>(true);

  /// Mostrar o medidor de FPS por cima das telas.
  static final mostrarMonitor = ValueNotifier<bool>(false);

  /// Tempo do início do main() até o primeiro frame (cold start, parte Dart).
  static int? coldStartMs;

  /// Tempo até a tela inicial com dados (splash concluído).
  static int? prontoMs;

  /// Quantidade de registros do histórico usado nos relatórios.
  static const registrosHistorico = 200000;

  /// Na versão não otimizada a lista de atendimentos monta todos os itens
  /// de uma vez; limitamos para não travar o aparelho de vez.
  static const limiteListaNaoOtimizada = 3000;
}

class FrameAmostra {
  const FrameAmostra(this.inicioUs, this.buildUs, this.rasterUs, this.totalUs);
  final int inicioUs;
  final int buildUs;
  final int rasterUs;
  final int totalUs;
}

class PerfMonitor extends ChangeNotifier {
  PerfMonitor._();
  static final instance = PerfMonitor._();

  /// Orçamento de um frame a 60 Hz.
  static const orcamentoUs = 16667;

  final _amostras = ListQueue<FrameAmostra>();
  bool _ativo = false;
  int jankTotal = 0;
  int framesTotal = 0;

  void iniciar() {
    if (_ativo) return;
    _ativo = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void zerar() {
    _amostras.clear();
    jankTotal = 0;
    framesTotal = 0;
    notifyListeners();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final a = FrameAmostra(
        t.timestampInMicroseconds(FramePhase.vsyncStart),
        t.buildDuration.inMicroseconds,
        t.rasterDuration.inMicroseconds,
        t.totalSpan.inMicroseconds,
      );
      _amostras.addLast(a);
      framesTotal++;
      if (a.buildUs > orcamentoUs || a.rasterUs > orcamentoUs) jankTotal++;
    }
    // Janela móvel dos últimos ~2 segundos.
    while (_amostras.length > 240) {
      _amostras.removeFirst();
    }
    notifyListeners();
  }

  /// FPS = frames desenhados no último segundo. Com a tela parada o Flutter
  /// não desenha nada (isso é bom: economiza bateria), então o valor cai.
  int get fps {
    if (_amostras.isEmpty) return 0;
    final fim = _amostras.last.inicioUs;
    return _amostras.where((a) => fim - a.inicioUs <= 1000000).length;
  }

  double get mediaBuildMs => _media((a) => a.buildUs);
  double get mediaRasterMs => _media((a) => a.rasterUs);

  double get piorFrameMs => _amostras.isEmpty
      ? 0
      : _amostras.map((a) => a.buildUs > a.rasterUs ? a.buildUs : a.rasterUs).reduce((a, b) => a > b ? a : b) /
          1000;

  int get jankRecente => _amostras.where((a) => a.buildUs > orcamentoUs || a.rasterUs > orcamentoUs).length;

  double _media(int Function(FrameAmostra) f) {
    if (_amostras.isEmpty) return 0;
    var soma = 0;
    for (final a in _amostras) {
      soma += f(a);
    }
    return soma / _amostras.length / 1000;
  }
}
