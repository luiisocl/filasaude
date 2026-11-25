// Telas do paciente ligadas à fila: escolher unidade, senha gerada,
// acompanhar fila (tela 2 do protótipo), "você foi chamado" e avaliação.
import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/scope.dart';
import '../../../core/theme.dart';
import '../../../domain/entities.dart';
import '../../../domain/fila_rules.dart';
import '../../viewmodels/paciente_viewmodel.dart';
import '../../widgets/common.dart';

class EscolherUnidadeScreen extends StatefulWidget {
  const EscolherUnidadeScreen({super.key});

  @override
  State<EscolherUnidadeScreen> createState() => _EscolherUnidadeScreenState();
}

class _EscolherUnidadeScreenState extends State<EscolherUnidadeScreen> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<PacienteViewModel>(context);
    final agora = DateTime.now();
    final lista = vm.unidades.where((u) => u.nome.toLowerCase().contains(_busca)).toList()
      ..sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
    return Scaffold(
      appBar: AppBar(title: const Text('Escolher unidade')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar unidade'),
              onChanged: (v) => setState(() => _busca = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: lista.isEmpty
                ? const EstadoVazio(icone: Icons.local_hospital_outlined, titulo: 'Nenhuma unidade encontrada')
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final u = lista[i];
                      final aberta = u.estaAberta(agora);
                      final selecionada = u.id == vm.unidade.id;
                      return AppCard(
                        corBorda: selecionada ? AppColors.primaria : null,
                        larguraBorda: selecionada ? 2 : 1,
                        onTap: () {
                          vm.escolherUnidade(u);
                          Navigator.pop(context);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(u.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                                Text('${u.distanciaKm.toStringAsFixed(1)} km', style: const TextStyle(color: AppColors.textoSecundario)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(u.endereco, style: const TextStyle(fontSize: 14, color: AppColors.textoSecundario)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 6, children: [
                              Etiqueta(u.ehUpa ? 'UPA' : 'UBS', fundo: const Color(0xFFEEF1F1), corTexto: AppColors.textoMedio),
                              aberta
                                  ? Etiqueta(u.horarioTexto)
                                  : Etiqueta('Fechada · ${u.horarioTexto}', fundo: const Color(0xFFFBEBEA), corTexto: AppColors.perigo),
                              Etiqueta('${vm.aguardandoNa(u)} aguardando', fundo: const Color(0xFFEEF1F1), corTexto: AppColors.textoMedio),
                            ]),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class SenhaGeradaScreen extends StatelessWidget {
  const SenhaGeradaScreen({super.key, required this.senhaId});
  final String senhaId;

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<PacienteViewModel>(context);
    final s = vm.senha(senhaId);
    if (s == null) return const Scaffold(body: EstadoVazio(icone: Icons.error_outline, titulo: 'Senha não encontrada'));
    final u = vm.unidadeDe(s);
    final p = vm.paciente;
    return Scaffold(
      appBar: AppBar(title: const Text('Senha retirada')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.check_circle, color: AppColors.sucesso, size: 56),
          const SizedBox(height: 8),
          const Text('Sua senha foi gerada', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text(u.nome, style: const TextStyle(color: AppColors.textoSecundario)),
                Text(s.codigo, style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w800, letterSpacing: 3, color: AppColors.primaria)),
                Text(s.tipo.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                const Divider(height: 28),
                if (p != null) LinhaInfo('Paciente', p.nome),
                if (p != null) LinhaInfo('Documento', Fmt.documento(p.documento)),
                LinhaInfo('Retirada', Fmt.hora(s.retiradaEm)),
                LinhaInfo('Endereço', u.endereco),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (s.etapa == EtapaSenha.aguardandoChegada)
            AppCard(
              cor: AppColors.alertaFundo,
              corBorda: AppColors.alertaBorda,
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppColors.alertaTexto),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Confirme sua chegada na recepção. A senha expira em:',
                        style: TextStyle(color: AppColors.alertaTexto, fontSize: 14)),
                  ),
                  Contagem(
                    fim: s.retiradaEm.add(FilaRules.prazoChegada),
                    estilo: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.alertaTexto),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              VmScope.push<PacienteViewModel, void>(context, const AcompanharFilaScreen());
            },
            child: const Text('Acompanhar minha fila'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tela 2 do protótipo: Acompanhar fila

class AcompanharFilaScreen extends StatelessWidget {
  const AcompanharFilaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<PacienteViewModel>(context);
    final s = vm.senhaAtiva;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Minha senha')),
        body: EstadoVazio(
          icone: Icons.task_alt,
          titulo: 'Você não tem senha ativa',
          texto: vm.pendenteAvaliacao != null ? 'Seu atendimento foi encerrado. Avalie na tela inicial.' : null,
        ),
      );
    }
    final u = vm.unidadeDe(s);
    final pos = vm.posicao!;
    final emAtendimento = s.etapa == EtapaSenha.chamado || s.etapa == EtapaSenha.emAtendimento || s.etapa == EtapaSenha.emergencia;
    return Scaffold(
      appBar: AppBar(title: Text('Minha senha · ${u.nome}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            cor: AppColors.primaria,
            corBorda: AppColors.primaria,
            padding: const EdgeInsets.all(22),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Column(
                children: [
                  const Text('Sua senha', style: TextStyle(fontSize: 14)),
                  Text(s.codigo, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  const Divider(color: Colors.white38, height: 26),
                  if (emAtendimento)
                    Text(
                      s.etapa == EtapaSenha.emergencia
                          ? 'Você está sendo atendido na sala de emergência.'
                          : 'Dirija-se ao consultório ${s.consultorio ?? ''}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    )
                  else
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: _Numero(
                              valor: '${pos.pessoasAFrente + 1}º',
                              rotulo: s.etapa == EtapaSenha.aguardandoTriagem
                                  ? 'na triagem'
                                  : s.etapa == EtapaSenha.aguardandoChegada
                                      ? 'pessoas na unidade'
                                      : 'na fila',
                            ),
                          ),
                          const VerticalDivider(color: Colors.white38, width: 1),
                          Expanded(
                            child: _Numero(
                              valor: pos.tempoEstimado == null ? '—' : '~${Fmt.duracao(pos.tempoEstimado!)}',
                              rotulo: pos.tempoEstimado == null ? 'sem médico disponível' : 'tempo estimado',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (s.etapa == EtapaSenha.aguardandoChegada) ...[
            AppCard(
              cor: AppColors.alertaFundo,
              corBorda: AppColors.alertaBorda,
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Confirme a chegada na recepção ou no totem. Tempo restante:',
                        style: TextStyle(color: AppColors.alertaTexto)),
                  ),
                  Contagem(
                    fim: s.retiradaEm.add(FilaRules.prazoChegada),
                    estilo: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.alertaTexto),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (s.triagem != null) ...[
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(color: AppColors.risco(s.cor!), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Classificação: ${s.cor!.label} – ${s.cor!.descricao.toLowerCase()}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text('Definida pela enfermagem às ${Fmt.hora(s.triagem!.horario)}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          AppCard(child: _Etapas(senha: s)),
          const SizedBox(height: 14),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_active_outlined, color: AppColors.primaria, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Avisaremos quando faltarem 3 pessoas e quando você for chamado. Se sentir piora, procure a recepção.',
                  style: TextStyle(fontSize: 14, color: AppColors.textoMedio, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (!emAtendimento)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.perigo,
                side: const BorderSide(color: Color(0xFFE0B4AF)),
              ),
              onPressed: () async {
                final ok = await confirmar(
                  context,
                  titulo: 'Desistir da senha?',
                  texto: 'Você sairá da fila e, se voltar, precisará retirar outra senha.',
                  acao: 'Desistir',
                  destrutivo: true,
                );
                if (!ok || !context.mounted) return;
                vm.desistir();
                Navigator.pop(context);
                mostrarMensagem(context, 'Senha cancelada. Melhoras!');
              },
              child: const Text('Desistir da senha'),
            ),
        ],
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.valor, required this.rotulo});
  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(valor, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(rotulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.white)),
        ],
      );
}

class _Etapas extends StatelessWidget {
  const _Etapas({required this.senha});
  final Senha senha;

  @override
  Widget build(BuildContext context) {
    final s = senha;
    final passos = <(String, DateTime?)>[
      ('Senha retirada', s.retiradaEm),
      ('Chegada confirmada', s.chegadaEm),
      ('Triagem realizada', s.triagem?.horario),
      ('Chamado para o consultório', s.ultimaChamadaEm),
      ('Em atendimento', s.atendimentoInicio),
    ];
    final atual = passos.indexWhere((p) => p.$2 == null);
    return Column(
      children: [
        for (var i = 0; i < passos.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: passos[i].$2 != null ? AppColors.primaria : (i == atual ? AppColors.primariaClara : Colors.white),
                    shape: BoxShape.circle,
                    border: Border.all(color: passos[i].$2 != null || i == atual ? AppColors.primaria : AppColors.borda, width: 2),
                  ),
                  child: passos[i].$2 != null ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    i == atual ? _textoAtual(s) : passos[i].$1,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: i == atual ? FontWeight.w700 : FontWeight.w400,
                      color: passos[i].$2 == null && i != atual ? AppColors.textoSecundario : AppColors.texto,
                    ),
                  ),
                ),
                if (passos[i].$2 != null)
                  Text(Fmt.hora(passos[i].$2!), style: const TextStyle(color: AppColors.textoSecundario)),
              ],
            ),
          ),
      ],
    );
  }

  String _textoAtual(Senha s) => switch (s.etapa) {
        EtapaSenha.aguardandoChegada => 'Aguardando confirmação de chegada',
        EtapaSenha.aguardandoTriagem => 'Aguardando triagem',
        EtapaSenha.aguardandoMedico => 'Aguardando atendimento médico',
        EtapaSenha.chamado => 'Chamado – vá ao consultório ${s.consultorio}',
        EtapaSenha.emergencia => 'Atendimento de emergência',
        _ => s.etapa.label,
      };
}

// ---------------------------------------------------------------------------

class ChamadoScreen extends StatelessWidget {
  const ChamadoScreen({super.key, required this.senhaId});
  final String senhaId;

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.watch<PacienteViewModel>(context);
    final s = vm.senha(senhaId);
    return Scaffold(
      backgroundColor: AppColors.primaria,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.campaign_rounded, color: Colors.white, size: 72),
              const SizedBox(height: 12),
              const Text('É a sua vez!', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              Text(s?.codigo ?? '', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w800, letterSpacing: 3)),
              const SizedBox(height: 8),
              Text(
                'Consultório ${s?.consultorio ?? ''}',
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
              ),
              if (s?.medico != null && s!.medico!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(s.medico!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              ],
              if (s != null && s.chamadas > 1) ...[
                const SizedBox(height: 16),
                Text('Chamada ${s.chamadas} de 3', style: const TextStyle(color: Colors.white, fontSize: 15)),
              ],
              const Spacer(),
              const Text(
                'Você tem 5 minutos para se apresentar.',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaria),
                onPressed: () => Navigator.pop(context),
                child: const Text('Estou indo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class AvaliarScreen extends StatefulWidget {
  const AvaliarScreen({super.key, required this.senhaId});
  final String senhaId;

  @override
  State<AvaliarScreen> createState() => _AvaliarScreenState();
}

class _AvaliarScreenState extends State<AvaliarScreen> {
  int _nota = 0;
  final _comentario = TextEditingController();

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  static const _rotulos = ['', 'Muito ruim', 'Ruim', 'Regular', 'Bom', 'Excelente'];

  @override
  Widget build(BuildContext context) {
    final vm = VmScope.read<PacienteViewModel>(context);
    final s = vm.senha(widget.senhaId);
    return Scaffold(
      appBar: AppBar(title: const Text('Avaliar atendimento')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (s != null) Text('${vm.unidadeDe(s).nome} · ${Fmt.dataHora(s.finalizadoEm ?? s.retiradaEm)}',
              style: const TextStyle(color: AppColors.textoSecundario)),
          const SizedBox(height: 10),
          Text('Como foi seu atendimento?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 44,
                  tooltip: '$i estrela${i > 1 ? 's' : ''}',
                  onPressed: () => setState(() => _nota = i),
                  icon: Icon(
                    i <= _nota ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i <= _nota ? const Color(0xFFE8B100) : AppColors.bordaCampo,
                  ),
                ),
            ],
          ),
          Text(_rotulos[_nota], textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Campo(
            rotulo: 'Comentário (opcional)',
            child: TextField(controller: _comentario, maxLines: 4, maxLength: 300),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _nota == 0 || s == null
                ? null
                : () {
                    vm.avaliar(s, _nota, _comentario.text);
                    Navigator.pop(context);
                    mostrarMensagem(context, 'Obrigado pela avaliação!');
                  },
            child: const Text('Enviar avaliação'),
          ),
        ],
      ),
    );
  }
}
