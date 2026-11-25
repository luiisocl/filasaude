// Área da enfermagem: fila da triagem, classificação de risco (tela 3 do
// protótipo), reclassificação e alertas.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/scope.dart';
import '../../../core/theme.dart';
import '../../../domain/entities.dart';
import '../../../domain/fila_rules.dart';
import '../../viewmodels/equipe_viewmodels.dart';
import '../../widgets/common.dart';
import '../../widgets/equipe_widgets.dart';

class EnfermeiroShell extends StatelessWidget {
  const EnfermeiroShell({super.key});

  @override
  Widget build(BuildContext context) => VmScope<EnfermeiroViewModel>(
        create: (ctx) {
          final s = AppScope.of(ctx);
          return EnfermeiroViewModel(s.repo, s.session);
        },
        child: const _EnfermeiroHome(),
      );
}

class _EnfermeiroHome extends StatefulWidget {
  const _EnfermeiroHome();

  @override
  State<_EnfermeiroHome> createState() => _EnfermeiroHomeState();
}

class _EnfermeiroHomeState extends State<_EnfermeiroHome> {
  int _aba = 0;
  StreamSubscription<Senha>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= VmScope.read<EnfermeiroViewModel>(context).alertasVermelhos.listen(_alertaVermelho);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// RN02 / EX08
  void _alertaVermelho(Senha s) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFBEBEA),
        icon: const Icon(Icons.emergency, color: Color(0xFFB42318), size: 48),
        title: Text('Emergência – ${s.codigo}'),
        content: const Text(
          'Paciente classificado como VERMELHO. Ele não entra na fila: a equipe médica e a sala de emergência foram alertadas.',
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ciente'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _aba, children: const [_TriagemTab(), _FilaMedicaTab()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _aba,
          onDestinationSelected: (i) => setState(() => _aba = i),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart), label: 'Triagem'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: VmScope.watch<EnfermeiroViewModel>(context).atrasados.isNotEmpty,
                child: const Icon(Icons.format_list_numbered),
              ),
              label: 'Na fila',
            ),
          ],
        ),
      );
}

class _TriagemTab extends StatelessWidget {
  const _TriagemTab();

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<EnfermeiroViewModel>(context);
    final fila = vm.filaTriagem;
    final emerg = vm.emergencias;
    return Scaffold(
      appBar: EquipeAppBar(titulo: 'Triagem', subtitulo: '${vm.unidade.nome} · ${vm.nomeProfissional}'),
      body: Column(
        children: [
          const BannerConexao(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (emerg.isNotEmpty) ...[
                  Aviso.perigo(
                    titulo: 'Emergência:',
                    texto: '${emerg.map((e) => e.codigo).join(', ')} na sala vermelha.',
                    icone: Icons.emergency,
                  ),
                  const SizedBox(height: 14),
                ],
                SecaoTitulo('Aguardando triagem (${fila.length})'),
                if (fila.isEmpty)
                  const EstadoVazio(icone: Icons.check_circle_outline, titulo: 'Ninguém aguardando triagem')
                else
                  for (var i = 0; i < fila.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LinhaSenha(
                        senha: fila[i],
                        paciente: vm.paciente(fila[i]),
                        destaque: i == 0,
                        onTap: () => VmScope.push<EnfermeiroViewModel, void>(
                          context,
                          ClassificacaoScreen(senhaId: fila[i].id),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaMedicaTab extends StatelessWidget {
  const _FilaMedicaTab();

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<EnfermeiroViewModel>(context);
    final fila = vm.filaMedico;
    final atrasados = vm.atrasados.length;
    return Scaffold(
      appBar: EquipeAppBar(titulo: 'Fila do atendimento médico', subtitulo: vm.unidade.nome),
      body: fila.isEmpty
          ? const EstadoVazio(icone: Icons.inbox_outlined, titulo: 'Fila vazia')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: fila.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: atrasados == 0
                        ? const Aviso.info(texto: 'Todos dentro do tempo máximo da sua cor. Toque em um paciente para reclassificar.')
                        : Aviso.perigo(
                            texto: '$atrasados paciente(s) passaram do tempo máximo da cor. Reavalie (RN08).',
                          ),
                  );
                }
                final s = fila[i - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LinhaSenha(
                    senha: s,
                    paciente: vm.paciente(s),
                    onTap: () => _reclassificar(context, vm, s),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${i}º', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(_prazo(s), style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _prazo(Senha s) {
    final m = FilaRules.minutosParaPrazo(s, DateTime.now());
    return m >= 0 ? 'prazo: $m min' : 'atraso: ${-m} min';
  }

  void _reclassificar(BuildContext context, EnfermeiroViewModel vm, Senha s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReclassificarSheet(vm: vm, senha: s),
    );
  }
}

/// EX09: paciente piorou → nova cor, com motivo obrigatório (RNF10).
class _ReclassificarSheet extends StatefulWidget {
  const _ReclassificarSheet({required this.vm, required this.senha});
  final EnfermeiroViewModel vm;
  final Senha senha;

  @override
  State<_ReclassificarSheet> createState() => _ReclassificarSheetState();
}

class _ReclassificarSheetState extends State<_ReclassificarSheet> {
  late CorRisco _cor = widget.senha.cor!;
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.senha;
    final hist = s.triagem!.historico;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reclassificar ${s.codigo}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Queixa: ${s.triagem!.queixa}', style: const TextStyle(color: AppColors.textoSecundario)),
            const SizedBox(height: 14),
            SeletorRisco(valor: _cor, aoEscolher: (c) => setState(() => _cor = c)),
            const SizedBox(height: 6),
            Campo(
              rotulo: 'Motivo (obrigatório)',
              child: TextField(controller: _motivo, maxLines: 2, onChanged: (_) => setState(() {})),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _motivo.text.trim().isEmpty || _cor == s.cor
                  ? null
                  : () {
                      widget.vm.reclassificar(s, _cor, _motivo.text.trim());
                      Navigator.pop(context);
                      mostrarMensagem(context, '${s.codigo} reclassificado para ${_cor.label}. A fila foi reordenada.');
                    },
              child: const Text('Salvar nova classificação'),
            ),
            const SizedBox(height: 18),
            const SecaoTitulo('Histórico de classificação'),
            for (final r in hist.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${Fmt.hora(r.horario)} · ${r.de == null ? '' : '${r.de!.label} → '}${r.para.label} · ${r.responsavel} · ${r.motivo}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textoMedio),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tela 3 do protótipo: Classificação de risco

class ClassificacaoScreen extends StatefulWidget {
  const ClassificacaoScreen({super.key, required this.senhaId});
  final String senhaId;

  @override
  State<ClassificacaoScreen> createState() => _ClassificacaoScreenState();
}

class _ClassificacaoScreenState extends State<ClassificacaoScreen> {
  final _queixa = TextEditingController();
  final _pressao = TextEditingController();
  final _fc = TextEditingController();
  final _temp = TextEditingController();
  final _sat = TextEditingController();
  final _gli = TextEditingController();
  double _dor = 0;
  CorRisco? _cor;

  @override
  void dispose() {
    for (final c in [_queixa, _pressao, _fc, _temp, _sat, _gli]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar(EnfermeiroViewModel vm, Senha s) async {
    if (_queixa.text.trim().isEmpty || _cor == null) {
      mostrarMensagem(context, 'Preencha a queixa principal e escolha a cor de risco.', erro: true);
      return;
    }
    if (_cor == CorRisco.vermelho) {
      final ok = await confirmar(
        context,
        titulo: 'Confirmar VERMELHO?',
        texto: 'O paciente será levado à sala de emergência e não entrará na fila.',
        acao: 'Confirmar emergência',
        destrutivo: true,
      );
      if (!ok || !mounted) return;
    }
    vm.classificar(
      s,
      _cor!,
      _queixa.text.trim(),
      SinaisVitais(
        pressao: _pressao.text,
        frequenciaCardiaca: _fc.text,
        temperatura: _temp.text,
        saturacao: _sat.text,
        glicemia: _gli.text,
        dor: _dor.round(),
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
    if (_cor != CorRisco.vermelho) mostrarMensagem(context, '${s.codigo} classificado como ${_cor!.label} e enviado para a fila.');
  }

  Widget _vital(String rotulo, TextEditingController c, {String? dica}) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo, style: const TextStyle(fontSize: 12, color: AppColors.textoMedio)),
            const SizedBox(height: 4),
            TextField(
              controller: c,
              keyboardType: TextInputType.text,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: dica,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<EnfermeiroViewModel>(context);
    final s = vm.senha(widget.senhaId);
    if (s == null || s.etapa != EtapaSenha.aguardandoTriagem) {
      return Scaffold(appBar: AppBar(), body: const EstadoVazio(icone: Icons.info_outline, titulo: 'Paciente já classificado'));
    }
    final p = vm.paciente(s);
    final agora = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.codigo} · ${p?.nomeCurto ?? ''}, ${p?.idade(agora) ?? ''} anos'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              if (s.prioridade != PrioridadeLegal.nenhuma)
                Etiqueta('Prioridade legal · ${s.prioridade.label}', fundo: Colors.white),
              Text('chegou ${Fmt.haQuanto(s.chegadaEm ?? s.retiradaEm, agora)}',
                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w400)),
            ]),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Campo(
            rotulo: 'Queixa principal',
            child: TextField(controller: _queixa, maxLines: 2, textCapitalization: TextCapitalization.sentences),
          ),
          const SizedBox(height: 16),
          const SecaoTitulo('Sinais vitais'),
          Row(children: [
            _vital('Pressão', _pressao, dica: '120/80'),
            const SizedBox(width: 8),
            _vital('Freq. card.', _fc, dica: 'bpm'),
            const SizedBox(width: 8),
            _vital('Temp. (°C)', _temp, dica: '36,5'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _vital('Sat. O₂ (%)', _sat, dica: '98'),
            const SizedBox(width: 8),
            _vital('Glicemia', _gli, dica: 'mg/dL'),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ]),
          const SizedBox(height: 12),
          Text('Dor: ${_dor.round()} de 10', style: const TextStyle(fontSize: 13, color: AppColors.textoMedio)),
          Slider(
            value: _dor,
            max: 10,
            divisions: 10,
            label: _dor.round().toString(),
            onChanged: (v) => setState(() => _dor = v),
          ),
          const SizedBox(height: 8),
          const SecaoTitulo('Classificação de risco (Manchester)'),
          SeletorRisco(valor: _cor, aoEscolher: (c) => setState(() => _cor = c)),
          const SizedBox(height: 6),
          const Text(
            'Registro salvo com data, hora e responsável.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: () => _salvar(vm, s), child: const Text('Salvar e enviar para a fila')),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
