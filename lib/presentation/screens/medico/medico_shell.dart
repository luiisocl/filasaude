// Área do médico: chamar o próximo, rechamar/ausência (RN07) e encerrar.
import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/scope.dart';
import '../../../core/theme.dart';
import '../../../domain/entities.dart';
import '../../../domain/fila_rules.dart';
import '../../viewmodels/equipe_viewmodels.dart';
import '../../widgets/common.dart';
import '../../widgets/equipe_widgets.dart';

class MedicoShell extends StatelessWidget {
  const MedicoShell({super.key});

  @override
  Widget build(BuildContext context) => VmScope<MedicoViewModel>(
        create: (ctx) {
          final s = AppScope.of(ctx);
          return MedicoViewModel(s.repo, s.session);
        },
        child: const MinhaFilaScreen(),
      );
}

class MinhaFilaScreen extends StatelessWidget {
  const MinhaFilaScreen({super.key});

  void _chamar(BuildContext context) {
    final vm = VmScope.read<MedicoViewModel>(context);
    final s = vm.chamarProximo();
    if (s == null) {
      mostrarMensagem(context, 'Não há pacientes aguardando.');
      return;
    }
    VmScope.push<MedicoViewModel, void>(context, PacienteChamadoScreen(senhaId: s.id));
  }

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<MedicoViewModel>(context);
    final fila = vm.fila;
    final atual = vm.atual;
    final emerg = vm.emergencias;
    return Scaffold(
      appBar: EquipeAppBar(titulo: 'Minha fila', subtitulo: '${vm.unidade.nome} · ${vm.nomeProfissional}'),
      body: Column(
        children: [
          const BannerConexao(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      Row(
                        children: [
                          const Text('Consultório', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (var c = 1; c <= vm.unidade.consultorios; c++)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text('$c'),
                                        selected: vm.consultorio == c,
                                        onSelected: (_) => vm.escolherConsultorio(c),
                                        selectedColor: AppColors.primariaClara,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: Indicador(valor: '${fila.length}', rotulo: 'aguardando')),
                        const SizedBox(width: 10),
                        Expanded(child: Indicador(valor: '${vm.atendidosHoje}', rotulo: 'atendidos por mim hoje')),
                      ]),
                      const SizedBox(height: 14),
                      for (final e in emerg) ...[
                        AppCard(
                          cor: const Color(0xFFFBEBEA),
                          corBorda: AppColors.risco(CorRisco.vermelho),
                          larguraBorda: 2,
                          child: Row(
                            children: [
                              const Icon(Icons.emergency, color: Color(0xFFB42318)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('Emergência ${e.codigo} – ${e.triagem?.queixa ?? ''}',
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              TextButton(
                                onPressed: () {
                                  vm.assumirEmergencia(e);
                                  VmScope.push<MedicoViewModel, void>(context, PacienteChamadoScreen(senhaId: e.id));
                                },
                                child: const Text('Assumir'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (atual != null)
                        AppCard(
                          corBorda: AppColors.primaria,
                          larguraBorda: 2,
                          cor: AppColors.primariaClara,
                          onTap: () => VmScope.push<MedicoViewModel, void>(context, PacienteChamadoScreen(senhaId: atual.id)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${atual.etapa.label}: ${atual.codigo}',
                                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                    Text(vm.paciente(atual)?.nomeCurto ?? '', style: const TextStyle(color: AppColors.textoMedio)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        )
                      else
                        FilledButton.icon(
                          onPressed: fila.isEmpty ? null : () => _chamar(context),
                          icon: const Icon(Icons.campaign),
                          label: Text(fila.isEmpty ? 'Ninguém na fila' : 'Chamar próximo (${fila.first.codigo})'),
                        ),
                      const SizedBox(height: 18),
                      const SecaoTitulo('Próximos pacientes'),
                    ],
                  ),
                ),
                if (fila.isEmpty)
                  const SliverToBoxAdapter(child: EstadoVazio(icone: Icons.inbox_outlined, titulo: 'Fila vazia'))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    // Sliver com builder: itens montados só quando aparecem na tela.
                    sliver: SliverList.builder(
                      itemCount: fila.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: LinhaSenha(senha: fila[i], paciente: vm.paciente(fila[i]), destaque: i == 0),
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

// ---------------------------------------------------------------------------

class PacienteChamadoScreen extends StatelessWidget {
  const PacienteChamadoScreen({super.key, required this.senhaId});
  final String senhaId;

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<MedicoViewModel>(context);
    final s = vm.senha(senhaId);
    if (s == null || !(s.etapa == EtapaSenha.chamado || s.etapa == EtapaSenha.emAtendimento)) {
      return Scaffold(
        appBar: AppBar(),
        body: EstadoVazio(
          icone: Icons.info_outline,
          titulo: s == null ? 'Senha não encontrada' : 'Situação: ${s.etapa.label}',
          texto: s?.etapa == EtapaSenha.aguardandoMedico ? 'O paciente voltou para a fila.' : null,
        ),
      );
    }
    final p = vm.paciente(s);
    final t = s.triagem;
    final agora = DateTime.now();
    final chamado = s.etapa == EtapaSenha.chamado;
    return Scaffold(
      appBar: AppBar(title: Text('${s.codigo} · consultório ${s.consultorio ?? vm.consultorio}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p == null ? '' : '${p.nome}, ${p.idade(agora)} anos',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    if (s.cor != null) RiscoChip(s.cor!, compacto: true),
                  ],
                ),
                if (s.prioridade != PrioridadeLegal.nenhuma) ...[
                  const SizedBox(height: 8),
                  Etiqueta('Prioridade legal · ${s.prioridade.label}'),
                ],
                const Divider(height: 24),
                if (t != null) ...[
                  LinhaInfo('Queixa', t.queixa),
                  LinhaInfo('Pressão', t.sinais.pressao.isEmpty ? '—' : '${t.sinais.pressao} mmHg'),
                  LinhaInfo('Freq. cardíaca', t.sinais.frequenciaCardiaca.isEmpty ? '—' : '${t.sinais.frequenciaCardiaca} bpm'),
                  LinhaInfo('Temperatura', t.sinais.temperatura.isEmpty ? '—' : '${t.sinais.temperatura} °C'),
                  LinhaInfo('Saturação', t.sinais.saturacao.isEmpty ? '—' : '${t.sinais.saturacao}%'),
                  if (t.sinais.glicemia.isNotEmpty) LinhaInfo('Glicemia', '${t.sinais.glicemia} mg/dL'),
                  LinhaInfo('Dor', '${t.sinais.dor} de 10'),
                  LinhaInfo('Triagem', '${t.enfermeiro} às ${Fmt.hora(t.horario)}'),
                ],
                if (s.chegadaEm != null) LinhaInfo('Espera', Fmt.duracao(agora.difference(s.chegadaEm!))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (chamado) ...[
            AppCard(
              cor: AppColors.alertaFundo,
              corBorda: AppColors.alertaBorda,
              child: Row(
                children: [
                  Expanded(
                    child: Text('Chamada ${s.chamadas} de 3. Tempo para se apresentar:',
                        style: const TextStyle(color: AppColors.alertaTexto)),
                  ),
                  Contagem(
                    fim: s.ultimaChamadaEm!.add(FilaRules.prazoChamada),
                    estilo: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.alertaTexto),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => vm.iniciar(s),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Paciente chegou – iniciar atendimento'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: s.chamadas >= 3 ? null : () => vm.rechamar(s),
                    child: const Text('Rechamar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.perigo),
                    onPressed: () async {
                      final texto = s.chamadas >= 3
                          ? 'Foi a 3ª chamada: a senha será cancelada.'
                          : s.chamadas >= 2
                              ? 'Foram 2 chamadas: o paciente vai para o fim da fila da cor dele.'
                              : 'O paciente volta para a fila na mesma posição.';
                      final ok = await confirmar(context, titulo: 'Não compareceu?', texto: texto, acao: 'Confirmar');
                      if (!ok || !context.mounted) return;
                      vm.naoCompareceu(s);
                      Navigator.pop(context);
                    },
                    child: const Text('Não compareceu'),
                  ),
                ),
              ],
            ),
          ] else
            FilledButton.icon(
              onPressed: () => VmScope.push<MedicoViewModel, void>(context, EncerrarAtendimentoScreen(senhaId: s.id)),
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: const Text('Encerrar atendimento'),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class EncerrarAtendimentoScreen extends StatefulWidget {
  const EncerrarAtendimentoScreen({super.key, required this.senhaId});
  final String senhaId;

  @override
  State<EncerrarAtendimentoScreen> createState() => _EncerrarAtendimentoScreenState();
}

class _EncerrarAtendimentoScreenState extends State<EncerrarAtendimentoScreen> {
  Desfecho? _desfecho;
  final _obs = TextEditingController();

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.read<MedicoViewModel>(context);
    final s = vm.senha(widget.senhaId);
    return Scaffold(
      appBar: AppBar(title: Text('Encerrar · ${s?.codigo ?? ''}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SecaoTitulo('Desfecho'),
          for (final d in Desfecho.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                corBorda: _desfecho == d ? AppColors.primaria : null,
                larguraBorda: _desfecho == d ? 2 : 1,
                onTap: () => setState(() => _desfecho = d),
                child: Row(
                  children: [
                    Icon(
                      _desfecho == d ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: _desfecho == d ? AppColors.primaria : AppColors.bordaCampo,
                    ),
                    const SizedBox(width: 12),
                    Text(d.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Campo(
            rotulo: 'Orientação ao paciente (opcional)',
            child: TextField(controller: _obs, maxLines: 3, textCapitalization: TextCapitalization.sentences),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _desfecho == null || s == null
                ? null
                : () {
                    vm.encerrar(s, _desfecho!, _obs.text);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    mostrarMensagem(context, 'Atendimento de ${s.codigo} encerrado.');
                  },
            child: const Text('Encerrar atendimento'),
          ),
        ],
      ),
    );
  }
}
