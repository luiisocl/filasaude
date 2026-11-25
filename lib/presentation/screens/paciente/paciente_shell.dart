import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/scope.dart';
import '../../../core/theme.dart';
import '../../../data/fila_repository.dart';
import '../../../domain/entities.dart';
import '../../viewmodels/paciente_viewmodel.dart';
import '../../widgets/common.dart';
import 'paciente_conta.dart';
import 'paciente_fila.dart';

class PacienteShell extends StatelessWidget {
  const PacienteShell({super.key});

  @override
  Widget build(BuildContext context) => VmScope<PacienteViewModel>(
        create: (ctx) {
          final s = AppScope.of(ctx);
          return PacienteViewModel(s.repo, s.session);
        },
        child: const _PacienteHome(),
      );
}

class _PacienteHome extends StatefulWidget {
  const _PacienteHome();

  @override
  State<_PacienteHome> createState() => _PacienteHomeState();
}

class _PacienteHomeState extends State<_PacienteHome> {
  int _aba = 0;
  StreamSubscription<FilaEvento>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= VmScope.read<PacienteViewModel>(context).eventos.listen(_aoEvento);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _aoEvento(FilaEvento e) {
    if (!mounted) return;
    switch (e) {
      case FaltamTres():
        mostrarMensagem(context, 'Faltam 3 pessoas ou menos antes de você. Fique perto do consultório.');
      case VoceFoiChamado():
        VmScope.push<PacienteViewModel, void>(context, ChamadoScreen(senhaId: e.senhaId), fullscreen: true);
      case SenhaEncerrada(:final motivo):
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Senha encerrada'),
            content: Text(motivo),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendi'))],
          ),
        );
      case AlertaVermelho():
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          // IndexedStack mantém o estado (e a rolagem) de cada aba.
          index: _aba,
          children: const [InicioPacienteTab(), HistoricoPacienteTab(), PerfilPacienteTab()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _aba,
          onDestinationSelected: (i) => setState(() => _aba = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number), label: 'Senha'),
            NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Tela 1 do protótipo: Retirar senha

class InicioPacienteTab extends StatelessWidget {
  const InicioPacienteTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<PacienteViewModel>(context);
    final p = vm.paciente;
    final ativa = vm.senhaAtiva;
    final avaliar = vm.pendenteAvaliacao;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.primaria,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Logo(),
                const SizedBox(height: 18),
                Text('Olá, ${p?.primeiroNome ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  ativa == null ? 'Retirar senha' : 'Minha senha',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList.list(
            children: [
              if (avaliar != null) ...[
                AppCard(
                  corBorda: AppColors.primaria,
                  onTap: () => VmScope.push<PacienteViewModel, void>(context, AvaliarScreen(senhaId: avaliar.id)),
                  child: const Row(
                    children: [
                      Icon(Icons.star_rate_rounded, color: Color(0xFFE8B100), size: 30),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Como foi seu atendimento? Toque para avaliar.',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (ativa != null) _SenhaAtivaCard(senha: ativa) else const _FormRetirada(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SenhaAtivaCard extends StatelessWidget {
  const _SenhaAtivaCard({required this.senha});
  final Senha senha;

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<PacienteViewModel>(context);
    final pos = vm.posicao;
    final u = vm.unidadeDe(senha);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          cor: AppColors.primaria,
          corBorda: AppColors.primaria,
          onTap: () => VmScope.push<PacienteViewModel, void>(context, const AcompanharFilaScreen()),
          padding: const EdgeInsets.all(20),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Column(
              children: [
                Text(u.nome, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text(senha.codigo, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: 2)),
                Text(senha.etapa.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (pos != null && senha.etapa != EtapaSenha.chamado && senha.etapa != EtapaSenha.emAtendimento) ...[
                  const SizedBox(height: 10),
                  Text(
                    pos.tempoEstimado == null
                        ? 'Tempo estimado indisponível'
                        : 'Tempo estimado: ~${Fmt.duracao(pos.tempoEstimado!)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => VmScope.push<PacienteViewModel, void>(context, const AcompanharFilaScreen()),
          icon: const Icon(Icons.timelapse),
          label: const Text('Acompanhar fila'),
        ),
        const SizedBox(height: 16),
        const AvisoSamu(),
      ],
    );
  }
}

class _FormRetirada extends StatelessWidget {
  const _FormRetirada();

  Future<void> _retirar(BuildContext context) async {
    final vm = VmScope.read<PacienteViewModel>(context);
    final r = vm.retirarSenha();
    switch (r.resultado) {
      case ResultadoRetirada.ok:
        await VmScope.push<PacienteViewModel, void>(context, SenhaGeradaScreen(senhaId: r.senha!.id));
      case ResultadoRetirada.jaPossui:
        // RN06 / EX01
        mostrarMensagem(context, 'Você já tem a senha ${r.senha!.codigo} ativa.');
      case ResultadoRetirada.unidadeFechada:
        // EX03: indica uma unidade aberta.
        final agora = DateTime.now();
        final abertas = vm.unidades.where((u) => u.estaAberta(agora)).toList()
          ..sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('${vm.unidade.nome} está fechada'),
            content: Text(
              'Horário de funcionamento: ${vm.unidade.horarioTexto}.'
              '${abertas.isEmpty ? '' : '\n\nA unidade aberta mais próxima é ${abertas.first.nome} (${abertas.first.distanciaKm} km).'}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
              if (abertas.isNotEmpty)
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () {
                    vm.escolherUnidade(abertas.first);
                    Navigator.pop(ctx);
                  },
                  child: Text('Usar ${abertas.first.nome}'),
                ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<PacienteViewModel>(context);
    final u = vm.unidade;
    final aberta = u.estaAberta(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SecaoTitulo('Unidade'),
        AppCard(
          onTap: () => VmScope.push<PacienteViewModel, void>(context, const EscolherUnidadeScreen()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(u.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  const Text('Trocar', style: TextStyle(color: AppColors.primaria, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Text(u.endereco, style: const TextStyle(color: AppColors.textoSecundario)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  aberta
                      ? Etiqueta(u.horarioTexto)
                      : const Etiqueta('Fechada agora', fundo: Color(0xFFFBEBEA), corTexto: AppColors.perigo),
                  Etiqueta('${vm.aguardandoNa(u)} aguardando', fundo: const Color(0xFFEEF1F1), corTexto: AppColors.textoMedio),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SecaoTitulo('Tipo de atendimento'),
        for (final t in TipoAtendimento.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              corBorda: vm.tipo == t ? AppColors.primaria : null,
              larguraBorda: vm.tipo == t ? 2 : 1,
              onTap: () => vm.escolherTipo(t),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    vm.tipo == t ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: vm.tipo == t ? AppColors.primaria : AppColors.bordaCampo,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(t.descricao, style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        if (vm.tipo == TipoAtendimento.urgencia) ...[const AvisoSamu(), const SizedBox(height: 18)],
        FilledButton(onPressed: () => _retirar(context), child: const Text('Retirar senha')),
        const SizedBox(height: 8),
        const Text(
          'Confirme sua chegada na recepção em até 1 hora.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
        ),
      ],
    );
  }
}
