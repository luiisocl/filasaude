// Área do coordenador: painel em tempo real, relatórios (Isolate), lista de
// atendimentos com paginação, equipe, configuração da unidade e painel de TV.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/perf.dart';
import '../../../core/scope.dart';
import '../../../core/theme.dart';
import '../../../data/historico.dart';
import '../../../domain/entities.dart';
import '../../viewmodels/coordenador_viewmodel.dart';
import '../../widgets/common.dart';
import '../../widgets/equipe_widgets.dart';

class CoordenadorShell extends StatefulWidget {
  const CoordenadorShell({super.key});

  @override
  State<CoordenadorShell> createState() => _CoordenadorShellState();
}

class _CoordenadorShellState extends State<CoordenadorShell> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) => VmScope<CoordenadorViewModel>(
        create: (ctx) {
          final s = AppScope.of(ctx);
          return CoordenadorViewModel(s.repo, s.session);
        },
        child: Scaffold(
          body: IndexedStack(
            index: _aba,
            children: const [_PainelTab(), _RelatoriosTab(), _EquipeTab(), _UnidadeTab()],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _aba,
            onDestinationSelected: (i) => setState(() => _aba = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Painel'),
              NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Relatórios'),
              NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Equipe'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Unidade'),
            ],
          ),
        ),
      );
}

/// Barras horizontais simples (sem biblioteca de gráficos).
class Barras extends StatelessWidget {
  const Barras({super.key, required this.itens, this.maximo});
  final List<({String rotulo, double valor, String texto, Color cor})> itens;
  final double? maximo;

  @override
  Widget build(BuildContext context) {
    final max = maximo ?? itens.fold<double>(1, (m, e) => e.valor > m ? e.valor : m);
    return Column(
      children: [
        for (final e in itens)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(width: 74, child: Text(e.rotulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 18,
                        width: (c.maxWidth * (max == 0 ? 0 : e.valor / max)).clamp(2, c.maxWidth),
                        decoration: BoxDecoration(color: e.cor, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 76,
                  child: Text(e.texto, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _PainelTab extends StatelessWidget {
  const _PainelTab();

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<CoordenadorViewModel>(context);
    final p = vm.painel;
    return Scaffold(
      appBar: EquipeAppBar(
        titulo: 'Painel da unidade',
        subtitulo: vm.unidade.nome,
        acoes: [
          IconButton(
            tooltip: 'Painel de chamada (TV)',
            icon: const Icon(Icons.tv),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PainelTvScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          const BannerConexao(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.9,
                  children: [
                    Indicador(valor: '${p.totalAguardando}', rotulo: 'aguardando agora'),
                    Indicador(valor: '${p.emAtendimento}', rotulo: 'chamados / em atendimento'),
                    Indicador(valor: '${p.atendidos}', rotulo: 'atendidos hoje', cor: AppColors.sucesso),
                    Indicador(
                      valor: '${(p.taxaDesistencia * 100).toStringAsFixed(0)}%',
                      rotulo: 'desistência hoje',
                      cor: AppColors.perigo,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (vm.medicosAtivos == 0)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Aviso.perigo(texto: 'Nenhum médico ativo: os pacientes veem "tempo estimado indisponível" (EX12).'),
                  ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SecaoTitulo('Aguardando médico por cor'),
                      Barras(itens: [
                        for (final c in CorRisco.values.skip(1))
                          (
                            rotulo: c.label,
                            valor: p.aguardandoPorCor[c.index].toDouble(),
                            texto: '${p.aguardandoPorCor[c.index]}',
                            cor: AppColors.risco(c),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      Text('Na triagem: ${p.aguardandoTriagem} · aguardando chegada (app): ${p.aguardandoChegada}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SecaoTitulo('Espera média hoje (chegada → médico)'),
                      Barras(
                        itens: [
                          for (final c in CorRisco.values.skip(1))
                            (
                              rotulo: c.label,
                              valor: (p.esperaMediaPorCor[c.index] ?? 0).toDouble(),
                              texto: p.esperaMediaPorCor[c.index] == null ? '—' : '${p.esperaMediaPorCor[c.index]} min',
                              cor: AppColors.risco(c),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Limites: laranja 10 min · amarelo 60 · verde 120 · azul 240.',
                          style: TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
                    ],
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

// ---------------------------------------------------------------------------

class _RelatoriosTab extends StatelessWidget {
  const _RelatoriosTab();

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<CoordenadorViewModel>(context);
    final r = vm.relatorio;
    return Scaffold(
      appBar: EquipeAppBar(titulo: 'Relatórios', subtitulo: vm.unidade.nome),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<Periodo>(
            showSelectedIcon: false,
            segments: [for (final p in Periodo.values) ButtonSegment(value: p, label: Text(p.label))],
            selected: {vm.periodo},
            onSelectionChanged: (s) => vm.escolherPeriodo(s.first),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: vm.calculando ? null : () => unawaited(vm.gerarRelatorio()),
            icon: vm.calculando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.analytics_outlined),
            label: Text(vm.calculando ? 'Calculando…' : 'Gerar relatório'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => VmScope.push<CoordenadorViewModel, void>(context, const AtendimentosListScreen()),
            icon: const Icon(Icons.list_alt),
            label: const Text('Ver todos os atendimentos'),
          ),
          const SizedBox(height: 16),
          if (r == null)
            Text(
              'Base: ${Fmt.milhar(PerfConfig.registrosHistorico)} atendimentos dos últimos 12 meses.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textoSecundario),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Etiqueta('Calculado em ${vm.calculoMs} ms'),
                Etiqueta(vm.calculadoEmIsolate ? 'Isolate (fora da UI)' : 'Thread principal',
                    fundo: vm.calculadoEmIsolate ? AppColors.primariaClara : const Color(0xFFFBEBEA),
                    corTexto: vm.calculadoEmIsolate ? AppColors.primaria : AppColors.perigo),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                Indicador(valor: Fmt.milhar(r.total), rotulo: 'atendimentos'),
                Indicador(valor: '${r.dentroDoPrazoPct.toStringAsFixed(1)}%', rotulo: 'dentro do prazo da cor', cor: AppColors.sucesso),
                Indicador(valor: '${(r.taxaDesistencia * 100).toStringAsFixed(1)}%', rotulo: 'desistência', cor: AppColors.perigo),
                Indicador(valor: '${r.mediaDuracao.toStringAsFixed(0)} min', rotulo: 'duração média da consulta'),
              ],
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SecaoTitulo('Espera média por cor'),
                  Barras(itens: [
                    for (final c in CorRisco.values)
                      (
                        rotulo: c.label,
                        valor: r.mediaEsperaPorCor[c.index],
                        texto: '${r.mediaEsperaPorCor[c.index].toStringAsFixed(0)} min',
                        cor: AppColors.risco(c),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  const SecaoTitulo('90% esperaram até'),
                  Barras(itens: [
                    for (final c in CorRisco.values)
                      (
                        rotulo: c.label,
                        valor: r.p90EsperaPorCor[c.index].toDouble(),
                        texto: '${r.p90EsperaPorCor[c.index]} min',
                        cor: AppColors.risco(c),
                      ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SecaoTitulo('Atendimentos por dia da semana'),
                  Barras(itens: [
                    for (final (i, d) in const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'].indexed)
                      (rotulo: d, valor: r.porDiaSemana[i].toDouble(), texto: Fmt.milhar(r.porDiaSemana[i]), cor: AppColors.primaria),
                  ]),
                  const SizedBox(height: 12),
                  const SecaoTitulo('Desfechos'),
                  Barras(itens: [
                    for (final d in Desfecho.values)
                      (
                        rotulo: d.label.split(' ').first,
                        valor: r.desfechos[d.index].toDouble(),
                        texto: Fmt.milhar(r.desfechos[d.index]),
                        cor: AppColors.primariaEscura,
                      ),
                  ]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Lista de até 200 mil atendimentos.
/// Otimizado: ListView.builder + itemExtent fixo + paginação (lazy loading):
///   só os itens visíveis existem na memória e são carregados 50 por vez.
/// Não otimizado: Column dentro de SingleChildScrollView montando todos os
///   itens de uma vez (limitado a 3.000 para não travar de vez).
class AtendimentosListScreen extends StatefulWidget {
  const AtendimentosListScreen({super.key});

  @override
  State<AtendimentosListScreen> createState() => _AtendimentosListScreenState();
}

class _AtendimentosListScreenState extends State<AtendimentosListScreen> {
  final _scroll = ScrollController();
  final _otimizado = PerfConfig.otimizado.value;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_aoRolar);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(VmScope.read<CoordenadorViewModel>(context).abrirLista());
    });
  }

  void _aoRolar() {
    // Carrega a próxima página antes de chegar ao fim (rolagem contínua).
    if (_scroll.position.extentAfter < 600) {
      unawaited(VmScope.read<CoordenadorViewModel>(context).carregarMais());
    }
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_aoRolar)
      ..dispose();
    super.dispose();
  }

  static const _alturaItem = 72.0;

  Widget _item(CoordenadorViewModel vm, int i) {
    final r = vm.item(i);
    final cor = CorRisco.values[r.cor];
    return SizedBox(
      height: _alturaItem,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(width: 6, height: 44, decoration: BoxDecoration(color: AppColors.risco(cor), borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${i + 1} · ${Fmt.data(dataDoDia(r.dia))}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${cor.label} · espera ${r.espera} min · ${r.desistiu ? 'desistiu' : '${Desfecho.values[r.desfecho].label}, ${r.duracao} min'}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<CoordenadorViewModel>(context);
    final Widget corpo;
    if (!vm.repo.historicoPronto) {
      corpo = const Center(child: CircularProgressIndicator());
    } else if (_otimizado) {
      final n = vm.itensCarregados;
      corpo = ListView.builder(
        controller: _scroll,
        itemExtent: _alturaItem, // altura fixa: o Flutter não precisa medir cada item
        itemCount: n + (vm.temMais ? 1 : 0),
        itemBuilder: (context, i) => i == n
            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
            : _item(vm, i),
      );
    } else {
      final n = vm.totalHistorico < PerfConfig.limiteListaNaoOtimizada ? vm.totalHistorico : PerfConfig.limiteListaNaoOtimizada;
      corpo = SingleChildScrollView(
        child: Column(children: [for (var i = 0; i < n; i++) _item(vm, i)]),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Atendimentos (${Fmt.milhar(vm.totalHistorico)})'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _otimizado
                  ? 'Paginação: ${Fmt.milhar(vm.itensCarregados)} carregados · ListView.builder'
                  : 'Não otimizado: ${Fmt.milhar(PerfConfig.limiteListaNaoOtimizada)} itens montados de uma vez',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ),
      body: corpo,
    );
  }
}

// ---------------------------------------------------------------------------

class _EquipeTab extends StatelessWidget {
  const _EquipeTab();

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<CoordenadorViewModel>(context);
    final lista = vm.funcionarios;
    return Scaffold(
      appBar: EquipeAppBar(titulo: 'Equipe', subtitulo: vm.unidade.nome),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaria,
        foregroundColor: Colors.white,
        onPressed: () => VmScope.push<CoordenadorViewModel, void>(context, const FuncionarioFormScreen()),
        icon: const Icon(Icons.person_add),
        label: const Text('Adicionar'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: lista.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final f = lista[i];
          return AppCard(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            onTap: () => VmScope.push<CoordenadorViewModel, void>(context, FuncionarioFormScreen(funcionario: f)),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: f.ativo ? AppColors.primariaClara : const Color(0xFFEEF1F1),
                  child: Text(f.nome.replaceAll('Dra. ', '').replaceAll('Dr. ', '').replaceAll('Enf. ', '')[0],
                      style: const TextStyle(color: AppColors.primaria, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.nome, style: TextStyle(fontWeight: FontWeight.w700, color: f.ativo ? AppColors.texto : AppColors.textoSecundario)),
                      Text('${f.perfil.label} · ${f.email}', style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
                    ],
                  ),
                ),
                Switch(
                  value: f.ativo,
                  onChanged: f.id == vm.session.funcionarioId ? null : (_) => vm.alternarAtivo(f),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FuncionarioFormScreen extends StatefulWidget {
  const FuncionarioFormScreen({super.key, this.funcionario});
  final Funcionario? funcionario;

  @override
  State<FuncionarioFormScreen> createState() => _FuncionarioFormScreenState();
}

class _FuncionarioFormScreenState extends State<FuncionarioFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.funcionario?.nome ?? '');
  late final _email = TextEditingController(text: widget.funcionario?.email ?? '');
  late Perfil _perfil = widget.funcionario?.perfil ?? Perfil.enfermeiro;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!_form.currentState!.validate()) return;
    final vm = VmScope.read<CoordenadorViewModel>(context);
    final f = widget.funcionario;
    vm.salvarFuncionario(Funcionario(
      id: f?.id ?? 'f-${DateTime.now().millisecondsSinceEpoch}',
      nome: _nome.text.trim(),
      email: _email.text.trim().toLowerCase(),
      perfil: _perfil,
      senha: f?.senha ?? '123456',
      ativo: f?.ativo ?? true,
    ));
    Navigator.pop(context);
    mostrarMensagem(context, f == null ? 'Funcionário adicionado (senha inicial 123456).' : 'Dados atualizados.');
  }

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.read<CoordenadorViewModel>(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.funcionario == null ? 'Novo funcionário' : 'Editar funcionário')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Campo(
              rotulo: 'Nome',
              child: TextFormField(
                controller: _nome,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
              ),
            ),
            const SizedBox(height: 14),
            Campo(
              rotulo: 'E-mail',
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final e = (v ?? '').trim();
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return 'E-mail inválido';
                  if (vm.emailEmUso(e, exceto: widget.funcionario?.id)) return 'E-mail já cadastrado';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 18),
            const SecaoTitulo('Perfil de acesso'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in Perfil.values.skip(1))
                  ChoiceChip(
                    label: Text(p.label),
                    selected: _perfil == p,
                    onSelected: (_) => setState(() => _perfil = p),
                    selectedColor: AppColors.primariaClara,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _salvar, child: const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _UnidadeTab extends StatefulWidget {
  const _UnidadeTab();

  @override
  State<_UnidadeTab> createState() => _UnidadeTabState();
}

class _UnidadeTabState extends State<_UnidadeTab> {
  TextEditingController? _nome;
  late bool _h24;
  late int _abre, _fecha, _consultorios, _medicos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nome != null) return;
    final vm = VmScope.read<CoordenadorViewModel>(context);
    final u = vm.unidade;
    _nome = TextEditingController(text: u.nome);
    _h24 = u.aberta24h;
    _abre = u.aberta24h ? 7 : u.abre;
    _fecha = u.aberta24h ? 19 : u.fecha;
    _consultorios = u.consultorios;
    _medicos = vm.medicosAtivos;
  }

  @override
  void dispose() {
    _nome?.dispose();
    super.dispose();
  }

  Widget _contador(String rotulo, int valor, int min, int max, ValueChanged<int> aoMudar) => Row(
        children: [
          Expanded(child: Text(rotulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          IconButton.outlined(
            tooltip: 'Diminuir',
            onPressed: valor > min ? () => setState(() => aoMudar(valor - 1)) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(width: 44, child: Text('$valor', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          IconButton.outlined(
            tooltip: 'Aumentar',
            onPressed: valor < max ? () => setState(() => aoMudar(valor + 1)) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.read<CoordenadorViewModel>(context);
    return Scaffold(
      appBar: EquipeAppBar(titulo: 'Configurações da unidade', subtitulo: vm.unidade.nome),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Campo(rotulo: 'Nome da unidade', child: TextField(controller: _nome)),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aberta 24 horas'),
            value: _h24,
            onChanged: (v) => setState(() => _h24 = v),
          ),
          if (!_h24) ...[
            _contador('Abre às (h)', _abre, 0, 23, (v) => _abre = v),
            const SizedBox(height: 8),
            _contador('Fecha às (h)', _fecha, 1, 24, (v) => _fecha = v),
          ],
          const Divider(height: 28),
          _contador('Consultórios', _consultorios, 1, 12, (v) => _consultorios = v),
          const SizedBox(height: 8),
          _contador('Médicos ativos', _medicos, 0, 12, (v) => _medicos = v),
          const SizedBox(height: 6),
          const Text('Usado no cálculo do tempo estimado (RN09). Com 0, o app mostra "tempo indisponível".',
              style: TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
          const Divider(height: 28),
          const SecaoTitulo('Tempo máximo por cor (Protocolo de Manchester)'),
          for (final c in CorRisco.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [RiscoChip(c, compacto: true), const SizedBox(width: 10), Text(c.prazoTexto)]),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (!_h24 && _abre >= _fecha) {
                mostrarMensagem(context, 'O horário de abertura precisa ser antes do fechamento.', erro: true);
                return;
              }
              vm.salvarUnidade(
                nome: _nome!.text.trim().isEmpty ? vm.unidade.nome : _nome!.text.trim(),
                abre: _h24 ? 0 : _abre,
                fecha: _h24 ? 24 : _fecha,
                consultorios: _consultorios,
                medicos: _medicos,
              );
              mostrarMensagem(context, 'Configurações salvas.');
            },
            child: const Text('Salvar configurações'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Painel de chamada para a TV da recepção (RN12: só senha e consultório).
class PainelTvScreen extends StatelessWidget {
  const PainelTvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repo;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1F1D),
      appBar: AppBar(backgroundColor: const Color(0xFF0B1F1D), title: const Text('Painel de chamada')),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final ch = repo.ultimasChamadas;
          if (ch.isEmpty) {
            return const Center(
              child: Text('Aguardando chamadas…', style: TextStyle(color: Colors.white70, fontSize: 22)),
            );
          }
          final atual = ch.first;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: AppColors.primaria, borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    children: [
                      const Text('SENHA', style: TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 3)),
                      Text(atual.codigo, style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.w900)),
                      Text('Consultório ${atual.consultorio}',
                          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Últimas chamadas', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                for (final c in ch.skip(1))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(c.codigo, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))),
                        Text('Consultório ${c.consultorio}', style: const TextStyle(color: Colors.white, fontSize: 20)),
                        const SizedBox(width: 14),
                        Text(Fmt.hora(c.hora), style: const TextStyle(color: Colors.white54, fontSize: 16)),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
