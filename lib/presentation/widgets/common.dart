// Componentes reutilizáveis. Quase todos são const e sem estado: o Flutter
// consegue reaproveitá-los entre frames sem reconstruir.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../domain/entities.dart';
import '../../domain/fila_rules.dart';

class Logo extends StatelessWidget {
  const Logo({super.key, this.cor = Colors.white, this.tamanho = 20});
  final Color cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_box_rounded, color: cor, size: tamanho + 6),
          const SizedBox(width: 6),
          Text('FilaSaúde', style: TextStyle(color: cor, fontSize: tamanho, fontWeight: FontWeight.w800)),
        ],
      );
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.cor, this.corBorda, this.larguraBorda = 1});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? cor;
  final Color? corBorda;
  final double larguraBorda;

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: corBorda ?? AppColors.borda, width: larguraBorda),
    );
    return Material(
      color: cor ?? Colors.white,
      shape: forma,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class SecaoTitulo extends StatelessWidget {
  const SecaoTitulo(this.texto, {super.key, this.trailing});
  final String texto;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(texto, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textoMedio)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// Cor de risco sempre com o nome escrito (não depende só da cor).
class RiscoChip extends StatelessWidget {
  const RiscoChip(this.cor, {super.key, this.compacto = false});
  final CorRisco cor;
  final bool compacto;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: compacto ? 8 : 10, vertical: compacto ? 3 : 5),
        decoration: BoxDecoration(color: AppColors.risco(cor), borderRadius: BorderRadius.circular(999)),
        child: Text(
          compacto ? cor.label : '${cor.label} · ${cor.descricao}',
          style: TextStyle(color: AppColors.sobreRisco(cor), fontSize: compacto ? 12 : 13, fontWeight: FontWeight.w700),
        ),
      );
}

class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, this.fundo = AppColors.primariaClara, this.corTexto = AppColors.primaria});
  final String texto;
  final Color fundo;
  final Color corTexto;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(999)),
        child: Text(texto, style: TextStyle(color: corTexto, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class Aviso extends StatelessWidget {
  const Aviso({
    super.key,
    required this.texto,
    this.titulo,
    this.icone = Icons.warning_amber_rounded,
    this.fundo = AppColors.alertaFundo,
    this.borda = AppColors.alertaBorda,
    this.corTexto = AppColors.alertaTexto,
  });

  final String? titulo;
  final String texto;
  final IconData icone;
  final Color fundo;
  final Color borda;
  final Color corTexto;

  const Aviso.info({super.key, required this.texto, this.titulo, this.icone = Icons.info_outline})
      : fundo = AppColors.primariaClara,
        borda = const Color(0xFFB7D9D5),
        corTexto = AppColors.primariaEscura;

  const Aviso.perigo({super.key, required this.texto, this.titulo, this.icone = Icons.error_outline})
      : fundo = const Color(0xFFFBEBEA),
        borda = const Color(0xFFE6B3AE),
        corTexto = const Color(0xFF7A1F16);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: fundo, border: Border.all(color: borda), borderRadius: BorderRadius.circular(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: corTexto, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  if (titulo != null) TextSpan(text: '$titulo ', style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: texto),
                ]),
                style: TextStyle(color: corTexto, fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

/// RN10
class AvisoSamu extends StatelessWidget {
  const AvisoSamu({super.key});

  @override
  Widget build(BuildContext context) => const Aviso(
        titulo: 'Dor no peito, falta de ar ou desmaio?',
        texto: 'Não espere na fila: ligue 192 (SAMU) ou vá direto à recepção.',
      );
}

class EstadoVazio extends StatelessWidget {
  const EstadoVazio({super.key, required this.icone, required this.titulo, this.texto});
  final IconData icone;
  final String titulo;
  final String? texto;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 56, color: AppColors.bordaCampo),
              const SizedBox(height: 12),
              Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              if (texto != null) ...[
                const SizedBox(height: 6),
                Text(texto!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      );
}

class Campo extends StatelessWidget {
  const Campo({super.key, required this.rotulo, required this.child});
  final String rotulo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textoMedio)),
          const SizedBox(height: 6),
          child,
        ],
      );
}

/// Linha "rótulo: valor" usada em resumos.
class LinhaInfo extends StatelessWidget {
  const LinhaInfo(this.rotulo, this.valor, {super.key});
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 130, child: Text(rotulo, style: Theme.of(context).textTheme.bodySmall)),
            Expanded(child: Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String acao,
  bool destrutivo = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: destrutivo ? AppColors.perigo : AppColors.primaria,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(acao),
        ),
      ],
    ),
  );
  return r ?? false;
}

void mostrarMensagem(BuildContext context, String texto, {bool erro = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: erro ? AppColors.perigo : AppColors.texto,
    ));
}

/// Reconstrói só o próprio pedaço da tela a cada [intervalo].
/// Isolado num RepaintBoundary: o relógio não força o resto da tela
/// a ser redesenhado (otimização de UI).
class Tique extends StatefulWidget {
  const Tique({super.key, required this.builder, this.intervalo = const Duration(seconds: 1)});
  final Widget Function(BuildContext context, DateTime agora) builder;
  final Duration intervalo;

  @override
  State<Tique> createState() => _TiqueState();
}

class _TiqueState extends State<Tique> {
  late final Timer _timer;
  DateTime _agora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.intervalo, (_) => setState(() => _agora = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel(); // sem isso o timer segue vivo depois que a tela fecha
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: widget.builder(context, _agora));
}

/// Contagem regressiva até [fim].
class Contagem extends StatelessWidget {
  const Contagem({super.key, required this.fim, this.estilo});
  final DateTime fim;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) => Tique(
        builder: (_, agora) => Text(Fmt.contagem(fim.difference(agora)), style: estilo),
      );
}

/// Seleção de cor de risco (Manchester).
class SeletorRisco extends StatelessWidget {
  const SeletorRisco({super.key, required this.valor, required this.aoEscolher});
  final CorRisco? valor;
  final ValueChanged<CorRisco> aoEscolher;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final c in CorRisco.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                cor: valor == c ? AppColors.risco(c).withValues(alpha: 0.10) : Colors.white,
                corBorda: valor == c ? AppColors.risco(c) : AppColors.borda,
                larguraBorda: valor == c ? 2 : 1,
                onTap: () => aoEscolher(c),
                child: Row(
                  children: [
                    Icon(
                      valor == c ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: valor == c ? AppColors.risco(c) : AppColors.bordaCampo,
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(color: AppColors.risco(c), borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 82, child: Text(c.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                    Expanded(
                      child: Text('${c.descricao} · ${c.prazoTexto}', style: const TextStyle(fontSize: 13, color: AppColors.textoMedio)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
}

/// Cabeçalho de paciente em listas da equipe.
class LinhaSenha extends StatelessWidget {
  const LinhaSenha({
    super.key,
    required this.senha,
    required this.paciente,
    this.onTap,
    this.trailing,
    this.destaque = false,
    this.mostrarCor = true,
  });

  final Senha senha;
  final Paciente? paciente;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destaque;
  final bool mostrarCor;

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final atraso = FilaRules.excedeuTempo(senha, agora);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      corBorda: atraso ? AppColors.perigo : (destaque ? AppColors.primaria : null),
      larguraBorda: atraso || destaque ? 2 : 1,
      cor: destaque ? AppColors.primariaClara : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(senha.codigo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    if (mostrarCor && senha.cor != null) RiscoChip(senha.cor!, compacto: true),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  paciente == null ? 'Paciente' : '${paciente!.nomeCurto}, ${paciente!.idade(agora)} anos',
                  style: const TextStyle(fontSize: 15),
                ),
                if (senha.prioridade != PrioridadeLegal.nenhuma) ...[
                  const SizedBox(height: 6),
                  Etiqueta('Prioridade legal · ${senha.prioridade.label}'),
                ],
                if (atraso) ...[
                  const SizedBox(height: 6),
                  const Etiqueta('Passou do tempo máximo – reavaliar', fundo: Color(0xFFFBEBEA), corTexto: AppColors.perigo),
                ],
              ],
            ),
          ),
          trailing ??
              Text(
                Fmt.haQuanto(senha.chegadaEm ?? senha.retiradaEm, agora),
                style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario),
              ),
        ],
      ),
    );
  }
}
