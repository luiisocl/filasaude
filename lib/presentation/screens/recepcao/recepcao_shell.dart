// Área da recepção: confirmar chegada de quem retirou senha pelo app e
// gerar senha presencial para quem chega sem celular.
import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/scope.dart';
import '../../../core/theme.dart';
import '../../../data/fila_repository.dart';
import '../../../domain/entities.dart';
import '../../../domain/fila_rules.dart';
import '../../viewmodels/equipe_viewmodels.dart';
import '../../widgets/common.dart';
import '../../widgets/equipe_widgets.dart';

class RecepcaoShell extends StatefulWidget {
  const RecepcaoShell({super.key});

  @override
  State<RecepcaoShell> createState() => _RecepcaoShellState();
}

class _RecepcaoShellState extends State<RecepcaoShell> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) => VmScope<RecepcaoViewModel>(
        create: (ctx) {
          final s = AppScope.of(ctx);
          return RecepcaoViewModel(s.repo, s.session);
        },
        child: Scaffold(
          body: IndexedStack(index: _aba, children: const [_ChegadasTab(), NovaSenhaPresencialTab()]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _aba,
            onDestinationSelected: (i) => setState(() => _aba = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.how_to_reg_outlined), selectedIcon: Icon(Icons.how_to_reg), label: 'Chegadas'),
              NavigationDestination(icon: Icon(Icons.add_card_outlined), selectedIcon: Icon(Icons.add_card), label: 'Nova senha'),
            ],
          ),
        ),
      );
}

class _ChegadasTab extends StatelessWidget {
  const _ChegadasTab();

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<RecepcaoViewModel>(context);
    final lista = vm.chegadas;
    return Scaffold(
      appBar: EquipeAppBar(titulo: 'Recepção', subtitulo: '${vm.unidade.nome} · ${vm.nomeProfissional}'),
      body: Column(
        children: [
          const BannerConexao(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Senha, nome ou CPF'),
              onChanged: vm.buscar,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SecaoTitulo(
              'Retiraram senha pelo app (${lista.length})',
              trailing: Text('${vm.naTriagem} na triagem', style: const TextStyle(color: AppColors.textoSecundario, fontSize: 13)),
            ),
          ),
          Expanded(
            child: lista.isEmpty
                ? const EstadoVazio(
                    icone: Icons.inbox_outlined,
                    titulo: 'Ninguém aguardando confirmação',
                    texto: 'Quando um paciente retirar senha pelo app, ele aparece aqui.',
                  )
                : Tique(
                    intervalo: const Duration(seconds: 30),
                    builder: (context, agora) => ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final s = lista[i];
                        final restante = s.retiradaEm.add(FilaRules.prazoChegada).difference(agora);
                        return LinhaSenha(
                          senha: s,
                          paciente: vm.paciente(s),
                          onTap: () => VmScope.push<RecepcaoViewModel, void>(context, ConfirmarChegadaScreen(senhaId: s.id)),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('expira em', style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                              Text(Fmt.duracao(restante), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class ConfirmarChegadaScreen extends StatefulWidget {
  const ConfirmarChegadaScreen({super.key, required this.senhaId});
  final String senhaId;

  @override
  State<ConfirmarChegadaScreen> createState() => _ConfirmarChegadaScreenState();
}

class _ConfirmarChegadaScreenState extends State<ConfirmarChegadaScreen> {
  PrioridadeLegal? _prioridade;
  late final TextEditingController _nome;
  late final TextEditingController _tel;
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    final vm = VmScope.read<RecepcaoViewModel>(context);
    final s = vm.senha(widget.senhaId);
    final p = s == null ? null : vm.paciente(s);
    _nome = TextEditingController(text: p?.nome ?? '');
    _tel = TextEditingController(text: p?.telefone ?? '');
    _prioridade = s?.prioridade;
  }

  @override
  void dispose() {
    _nome.dispose();
    _tel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<RecepcaoViewModel>(context);
    final s = vm.senha(widget.senhaId);
    if (s == null || s.etapa != EtapaSenha.aguardandoChegada) {
      return Scaffold(
        appBar: AppBar(),
        body: const EstadoVazio(icone: Icons.info_outline, titulo: 'Esta senha não aguarda mais confirmação'),
      );
    }
    final p = vm.paciente(s);
    final agora = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text('Confirmar chegada · ${s.codigo}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.codigo, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.primaria)),
                const SizedBox(height: 6),
                LinhaInfo('Tipo', s.tipo.label),
                LinhaInfo('Retirada', '${Fmt.hora(s.retiradaEm)} (${Fmt.haQuanto(s.retiradaEm, agora)})'),
                if (p != null) LinhaInfo('Documento', Fmt.documento(p.documento)),
                if (p != null) LinhaInfo('Idade', '${p.idade(agora)} anos'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SecaoTitulo('Conferir cadastro'),
          Campo(rotulo: 'Nome', child: TextField(controller: _nome, textCapitalization: TextCapitalization.words)),
          const SizedBox(height: 12),
          Campo(
            rotulo: 'Celular',
            child: TextField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              inputFormatters: [MascaraFormatter('(##) #####-####')],
            ),
          ),
          const SizedBox(height: 18),
          const SecaoTitulo('Prioridade legal'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pr in PrioridadeLegal.values)
                ChoiceChip(
                  label: Text(pr.label),
                  selected: _prioridade == pr,
                  onSelected: (_) => setState(() => _prioridade = pr),
                  selectedColor: AppColors.primariaClara,
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              vm.confirmarChegada(s, _prioridade ?? PrioridadeLegal.nenhuma, nome: _nome.text, telefone: _tel.text);
              Navigator.pop(context);
              mostrarMensagem(context, 'Chegada de ${s.codigo} confirmada. Paciente enviado para a triagem.');
            },
            icon: const Icon(Icons.check),
            label: const Text('Confirmar chegada'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class NovaSenhaPresencialTab extends StatefulWidget {
  const NovaSenhaPresencialTab({super.key});

  @override
  State<NovaSenhaPresencialTab> createState() => _NovaSenhaPresencialTabState();
}

class _NovaSenhaPresencialTabState extends State<NovaSenhaPresencialTab> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _nasc = TextEditingController();
  final _doc = TextEditingController();
  TipoAtendimento _tipo = TipoAtendimento.urgencia;
  PrioridadeLegal _prioridade = PrioridadeLegal.nenhuma;

  @override
  void dispose() {
    _nome.dispose();
    _nasc.dispose();
    _doc.dispose();
    super.dispose();
  }

  DateTime? _data(String t) {
    final p = t.split('/');
    if (p.length != 3 || p[2].length != 4) return null;
    return DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}');
  }

  void _gerar() {
    if (!_form.currentState!.validate()) return;
    final vm = VmScope.read<RecepcaoViewModel>(context);
    final r = vm.novaSenhaPresencial(
      nome: _nome.text,
      nascimento: _data(_nasc.text)!,
      documento: _doc.text.replaceAll(RegExp(r'\D'), ''),
      tipo: _tipo,
      prioridade: _prioridade,
    );
    switch (r.resultado) {
      case ResultadoRetirada.ok:
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Senha gerada'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.senha!.codigo, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: AppColors.primaria)),
                const Text('O paciente já está na fila da triagem.'),
              ],
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
        _form.currentState!.reset();
        _nome.clear();
        _nasc.clear();
        _doc.clear();
        setState(() => _prioridade = PrioridadeLegal.nenhuma);
      case ResultadoRetirada.jaPossui:
        mostrarMensagem(context, 'Este paciente já tem a senha ${r.senha!.codigo} ativa.', erro: true);
      case ResultadoRetirada.unidadeFechada:
        mostrarMensagem(context, 'A unidade está fora do horário de funcionamento.', erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.read<RecepcaoViewModel>(context);
    return Scaffold(
      appBar: EquipeAppBar(titulo: 'Nova senha presencial', subtitulo: vm.unidade.nome),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Aviso.info(texto: 'Para quem chega sem celular. A senha entra direto na fila da triagem.'),
            const SizedBox(height: 18),
            Campo(
              rotulo: 'Nome completo',
              child: TextFormField(
                controller: _nome,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
              ),
            ),
            const SizedBox(height: 14),
            Campo(
              rotulo: 'Data de nascimento',
              child: TextFormField(
                controller: _nasc,
                keyboardType: TextInputType.number,
                inputFormatters: [MascaraFormatter('##/##/####')],
                decoration: const InputDecoration(hintText: 'dd/mm/aaaa'),
                validator: (v) => _data(v ?? '') == null ? 'Data inválida' : null,
              ),
            ),
            const SizedBox(height: 14),
            Campo(
              rotulo: 'CPF ou Cartão SUS (opcional)',
              child: TextFormField(
                controller: _doc,
                keyboardType: TextInputType.number,
                inputFormatters: [DocumentoFormatter()],
                validator: (v) => (v ?? '').isEmpty || FilaRules.documentoValido(v!) ? null : 'Documento inválido',
              ),
            ),
            const SizedBox(height: 18),
            const SecaoTitulo('Tipo de atendimento'),
            SegmentedButton<TipoAtendimento>(
              segments: [for (final t in TipoAtendimento.values) ButtonSegment(value: t, label: Text(t.label))],
              selected: {_tipo},
              onSelectionChanged: (v) => setState(() => _tipo = v.first),
            ),
            const SizedBox(height: 18),
            const SecaoTitulo('Prioridade legal'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in PrioridadeLegal.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: _prioridade == p,
                    onSelected: (_) => setState(() => _prioridade = p),
                    selectedColor: AppColors.primariaClara,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _gerar, child: const Text('Gerar senha')),
          ],
        ),
      ),
    );
  }
}
