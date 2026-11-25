// Laboratório de performance: liga/desliga as otimizações e mede, no próprio
// aparelho, o efeito de cada uma (parte 5 da apresentação: "antes x depois").
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/perf.dart';
import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../data/historico.dart';
import '../widgets/common.dart';

class Medicao {
  const Medicao(this.teste, this.otimizado, this.ms, this.jank, this.detalhe);
  final String teste;
  final bool otimizado;
  final int ms;
  final int jank;
  final String detalhe;
}

class PerfLabScreen extends StatefulWidget {
  const PerfLabScreen({super.key});

  /// Medições da sessão (ficam ao sair e voltar da tela).
  static final medicoes = <Medicao>[];

  @override
  State<PerfLabScreen> createState() => _PerfLabScreenState();
}

class _PerfLabScreenState extends State<PerfLabScreen> {
  bool _rodando = false;

  Future<void> _medir(String teste, Future<String> Function() acao) async {
    if (_rodando) return;
    setState(() => _rodando = true);
    // Espera um frame para o indicador começar a girar antes do teste.
    await WidgetsBinding.instance.endOfFrame;
    final jankAntes = PerfMonitor.instance.jankTotal;
    final cronometro = Stopwatch()..start();
    final detalhe = await acao();
    cronometro.stop();
    // Mais um frame para os tempos dos quadros chegarem ao monitor.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      PerfLabScreen.medicoes.insert(
        0,
        Medicao(teste, PerfConfig.otimizado.value, cronometro.elapsedMilliseconds,
            PerfMonitor.instance.jankTotal - jankAntes, detalhe),
      );
      _rodando = false;
    });
  }

  Future<void> _testeHistorico() => _medir('Gerar 200 mil registros', () async {
        final repo = AppScope.of(context).repo;
        repo.descartarHistorico();
        await repo.carregarHistorico();
        final h = repo.historico;
        return h != null
            ? 'arrays tipados: ${Fmt.bytes(h.bytes)} · Isolate'
            : 'List<Map>: ${Fmt.milhar(repo.historicoTamanho)} objetos · thread principal';
      });

  Future<void> _testeRelatorio() => _medir('Relatório de 12 meses', () async {
        final repo = AppScope.of(context).repo;
        await repo.carregarHistorico();
        final hoje = diaDe(DateTime.now());
        final h = repo.historico;
        if (h != null && PerfConfig.otimizado.value) {
          final r = await compute(calcularRelatorio, RelatorioParams(h, hoje - 365, hoje));
          return '${Fmt.milhar(r.total)} registros · Isolate';
        }
        final r = h != null
            ? calcularRelatorio(RelatorioParams(h, hoje - 365, hoje))
            : calcularRelatorioObjetos(repo.historicoObjetos!, hoje - 365, hoje);
        return '${Fmt.milhar(r.total)} registros · thread principal';
      });

  Future<void> _alternarModo(bool v) async {
    final scope = AppScope.of(context);
    PerfConfig.otimizado.value = v;
    await scope.cache.salvar(PerfConfig.chave, v.toString());
    scope.repo.descartarHistorico();
    if (!mounted) return;
    setState(() {});
    mostrarMensagem(context, 'Modo ${v ? 'otimizado' : 'NÃO otimizado'}. Feche e abra o app para medir o cold start neste modo.');
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repo;
    final otimizado = PerfConfig.otimizado.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Laboratório de performance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            cor: otimizado ? AppColors.primariaClara : const Color(0xFFFBEBEA),
            corBorda: otimizado ? AppColors.primaria : AppColors.perigo,
            larguraBorda: 2,
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(otimizado ? 'Otimizações LIGADAS (depois)' : 'Otimizações DESLIGADAS (antes)',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Isolates, arrays tipados, paginação, gravação com debounce, compressão em Isolate.'),
              value: otimizado,
              onChanged: _rodando ? null : _alternarModo,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: PerfConfig.mostrarMonitor,
            builder: (context, v, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar medidor de FPS nas telas'),
              value: v,
              onChanged: (n) => PerfConfig.mostrarMonitor.value = n,
            ),
          ),
          const SizedBox(height: 8),
          const SecaoTitulo('Abertura do app (cold start)'),
          AppCard(
            child: Column(
              children: [
                LinhaInfo('main() → 1º frame', PerfConfig.coldStartMs == null ? '—' : '${PerfConfig.coldStartMs} ms'),
                LinhaInfo('main() → dados prontos', PerfConfig.prontoMs == null ? '—' : '${PerfConfig.prontoMs} ms'),
                const SizedBox(height: 4),
                const Text(
                  'Medido a partir do código Dart. Para o tempo total (incluindo o motor do Flutter), use "flutter run --profile --trace-startup".',
                  style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SecaoTitulo('Frames agora (últimos 2 segundos)'),
          ListenableBuilder(
            listenable: PerfMonitor.instance,
            builder: (context, _) {
              final m = PerfMonitor.instance;
              return AppCard(
                child: Column(
                  children: [
                    LinhaInfo('FPS', '${m.fps}'),
                    LinhaInfo('Build médio', '${m.mediaBuildMs.toStringAsFixed(2)} ms'),
                    LinhaInfo('Raster médio', '${m.mediaRasterMs.toStringAsFixed(2)} ms'),
                    LinhaInfo('Pior frame', '${m.piorFrameMs.toStringAsFixed(1)} ms'),
                    LinhaInfo('Jank (sessão)', '${m.jankTotal} de ${m.framesTotal} frames'),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: m.zerar, child: const Text('Zerar contagem')),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          SecaoTitulo(
            'Testes',
            trailing: _rodando
                // Se a thread da UI travar, este indicador congela: dá para ver o jank.
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                : null,
          ),
          const Text(
            'Durante o teste, observe o indicador girando acima: na versão não otimizada ele congela.',
            style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _rodando ? null : _testeHistorico,
            icon: const Icon(Icons.dataset_outlined),
            label: Text('Gerar ${Fmt.milhar(PerfConfig.registrosHistorico)} registros'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _rodando ? null : _testeRelatorio,
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Calcular relatório de 12 meses'),
          ),
          const SizedBox(height: 14),
          if (PerfLabScreen.medicoes.isNotEmpty) ...[
            const SecaoTitulo('Resultados desta sessão'),
            for (final m in PerfLabScreen.medicoes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(m.teste, style: const TextStyle(fontWeight: FontWeight.w700))),
                          Etiqueta(
                            m.otimizado ? 'depois' : 'antes',
                            fundo: m.otimizado ? AppColors.primariaClara : const Color(0xFFFBEBEA),
                            corTexto: m.otimizado ? AppColors.primaria : AppColors.perigo,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${m.ms} ms · ${m.jank} frames com jank', style: const TextStyle(fontSize: 15)),
                      Text(m.detalhe, style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
          const SecaoTitulo('Rede e dados offline'),
          ListenableBuilder(
            listenable: repo,
            builder: (context, _) => AppCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Conectado à internet'),
                    subtitle: const Text('Desligue para simular queda de rede (EX13).'),
                    value: repo.online,
                    onChanged: repo.definirOnline,
                  ),
                  LinhaInfo('Na fila de envio', '${repo.operacoesPendentes} operação(ões)'),
                  LinhaInfo('Já enviadas', '${repo.envio.operacoes}'),
                  LinhaInfo('JSON', Fmt.bytes(repo.envio.bytesJson)),
                  LinhaInfo('Com GZIP', '${Fmt.bytes(repo.envio.bytesGzip)} (${repo.envio.economiaPct.toStringAsFixed(0)}% menor)'),
                  LinhaInfo('Último lote', repo.envio.ultimoLoteMs == null ? '—' : '${repo.envio.ultimoLoteMs} ms'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const SecaoTitulo('Demonstração'),
          StatefulBuilder(
            builder: (context, setLocal) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simular outros pacientes'),
              subtitle: const Text('Chegadas, triagens e atendimentos automáticos a cada 15 s.'),
              value: repo.simulacaoAtiva,
              onChanged: (v) => setLocal(() => repo.simulacaoAtiva = v),
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.perigo, minimumSize: const Size(0, 48)),
            onPressed: () async {
              final ok = await confirmar(
                context,
                titulo: 'Reiniciar dados?',
                texto: 'Apaga senhas, cadastros e o cache, e recria os dados de demonstração.',
                acao: 'Reiniciar',
                destrutivo: true,
              );
              if (!ok || !context.mounted) return;
              final s = AppScope.of(context);
              await s.repo.reiniciarDemonstracao();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
              s.session.sair();
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reiniciar dados de demonstração'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
