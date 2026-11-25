import 'package:flutter/material.dart';

import '../../core/perf.dart';

/// Medidor de FPS por cima do app (ligado no Laboratório de performance).
/// Fica num RepaintBoundary próprio: atualizar os números não redesenha a tela.
class PerfOverlay extends StatelessWidget {
  const PerfOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          ValueListenableBuilder<bool>(
            valueListenable: PerfConfig.mostrarMonitor,
            builder: (context, mostrar, _) {
              if (!mostrar) return const SizedBox.shrink();
              return Positioned(
                right: 8,
                top: MediaQuery.paddingOf(context).top + 64,
                child: const IgnorePointer(child: RepaintBoundary(child: _Medidor())),
              );
            },
          ),
        ],
      );
}

class _Medidor extends StatelessWidget {
  const _Medidor();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: PerfMonitor.instance,
        builder: (context, _) {
          final m = PerfMonitor.instance;
          final ruim = m.jankRecente > 0;
          return Material(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace', height: 1.35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${m.fps} FPS', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('build ${m.mediaBuildMs.toStringAsFixed(1)} ms'),
                    Text('raster ${m.mediaRasterMs.toStringAsFixed(1)} ms'),
                    Text(
                      'jank ${m.jankRecente}',
                      style: TextStyle(color: ruim ? const Color(0xFFFF8A80) : const Color(0xFFA5D6A7)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
