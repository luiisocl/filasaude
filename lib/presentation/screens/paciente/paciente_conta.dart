import 'package:flutter/material.dart';

import '../../../app.dart' show sair;
import '../../../core/formatters.dart';
import '../../../core/scope.dart';
import '../../../core/theme.dart';
import '../../../domain/entities.dart';
import '../../viewmodels/paciente_viewmodel.dart';
import '../../widgets/common.dart';

class HistoricoPacienteTab extends StatelessWidget {
  const HistoricoPacienteTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<PacienteViewModel>(context);
    final lista = vm.historico;
    return Scaffold(
      appBar: AppBar(title: const Text('Meus atendimentos'), automaticallyImplyLeading: false),
      body: lista.isEmpty
          ? const EstadoVazio(icone: Icons.history, titulo: 'Nenhum atendimento ainda', texto: 'Seus atendimentos encerrados aparecem aqui.')
          // ListView.builder: só os itens visíveis são construídos.
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final s = lista[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => _detalhes(context, vm, s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(Fmt.data(s.retiradaEm), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            ),
                            if (s.cor != null) RiscoChip(s.cor!, compacto: true),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${vm.unidadeDe(s).nome} · senha ${s.codigo}', style: const TextStyle(color: AppColors.textoSecundario)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.desfecho?.label ?? s.etapa.label,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (s.avaliacao != null)
                              for (var e = 0; e < s.avaliacao!; e++)
                                const Icon(Icons.star_rounded, size: 18, color: Color(0xFFE8B100)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _detalhes(BuildContext context, PacienteViewModel vm, Senha s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Atendimento de ${Fmt.data(s.retiradaEm)}', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              LinhaInfo('Unidade', vm.unidadeDe(s).nome),
              LinhaInfo('Senha', s.codigo),
              if (s.triagem != null) ...[
                LinhaInfo('Classificação', '${s.cor!.label} – ${s.cor!.descricao}'),
                LinhaInfo('Queixa', s.triagem!.queixa),
                LinhaInfo('Pressão', s.triagem!.sinais.pressao.isEmpty ? '—' : '${s.triagem!.sinais.pressao} mmHg'),
              ],
              if (s.medico != null) LinhaInfo('Médico(a)', s.medico!),
              LinhaInfo('Situação', s.desfecho?.label ?? s.etapa.label),
              if (s.observacao != null) LinhaInfo('Orientação', s.observacao!),
              if (s.chegadaEm != null && s.atendimentoInicio != null)
                LinhaInfo('Espera', Fmt.duracao(s.atendimentoInicio!.difference(s.chegadaEm!))),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class PerfilPacienteTab extends StatelessWidget {
  const PerfilPacienteTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<PacienteViewModel>(context);
    final p = vm.paciente;
    if (p == null) return const SizedBox.shrink();
    final agora = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primariaClara,
                      child: Text(p.nome[0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primaria)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          Text('${p.idade(agora)} anos', style: const TextStyle(color: AppColors.textoSecundario)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                LinhaInfo('Documento', Fmt.documento(p.documento)),
                LinhaInfo('Nascimento', Fmt.data(p.nascimento)),
                LinhaInfo('Celular', p.telefone.isEmpty ? '—' : p.telefone),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _editar(context, vm, p),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar dados'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => sair(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
          const SizedBox(height: 28),
          const SecaoTitulo('Privacidade (LGPD)'),
          const Text(
            'Seus dados de saúde são tratados como sensíveis e usados só para organizar o atendimento.',
            style: TextStyle(color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.perigo, minimumSize: const Size(0, 48)),
            onPressed: () async {
              final ok = await confirmar(
                context,
                titulo: 'Excluir conta?',
                texto: 'Seu cadastro e o histórico de atendimentos serão apagados. Essa ação não pode ser desfeita.',
                acao: 'Excluir',
                destrutivo: true,
              );
              if (ok && context.mounted) vm.excluirConta();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir minha conta e meus dados'),
          ),
        ],
      ),
    );
  }

  void _editar(BuildContext context, PacienteViewModel vm, Paciente p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditarPerfilSheet(vm: vm, paciente: p),
    );
  }
}

/// Folha de edição com estado próprio: os controllers são liberados no
/// dispose, depois que a animação de fechamento termina.
class _EditarPerfilSheet extends StatefulWidget {
  const _EditarPerfilSheet({required this.vm, required this.paciente});
  final PacienteViewModel vm;
  final Paciente paciente;

  @override
  State<_EditarPerfilSheet> createState() => _EditarPerfilSheetState();
}

class _EditarPerfilSheetState extends State<_EditarPerfilSheet> {
  late final _nome = TextEditingController(text: widget.paciente.nome);
  late final _tel = TextEditingController(text: widget.paciente.telefone);
  late final _nasc = TextEditingController(text: Fmt.data(widget.paciente.nascimento));

  @override
  void dispose() {
    _nome.dispose();
    _tel.dispose();
    _nasc.dispose();
    super.dispose();
  }

  void _salvar() {
    final partes = _nasc.text.split('/');
    final data = partes.length == 3 ? DateTime.tryParse('${partes[2]}-${partes[1]}-${partes[0]}') : null;
    if (_nome.text.trim().isEmpty || data == null) {
      mostrarMensagem(context, 'Confira o nome e a data de nascimento.', erro: true);
      return;
    }
    widget.vm.atualizarPerfil(nome: _nome.text, telefone: _tel.text, nascimento: data);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Campo(rotulo: 'Nome completo', child: TextField(controller: _nome, textCapitalization: TextCapitalization.words)),
            const SizedBox(height: 14),
            Campo(
              rotulo: 'Data de nascimento',
              child: TextField(
                controller: _nasc,
                keyboardType: TextInputType.number,
                inputFormatters: [MascaraFormatter('##/##/####')],
              ),
            ),
            const SizedBox(height: 14),
            Campo(
              rotulo: 'Celular',
              child: TextField(
                controller: _tel,
                keyboardType: TextInputType.phone,
                inputFormatters: [MascaraFormatter('(##) #####-####')],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _salvar, child: const Text('Salvar')),
          ],
        ),
      );
}
