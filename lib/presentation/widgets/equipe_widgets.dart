import 'package:flutter/material.dart';

import '../../app.dart' show sair;
import '../../core/scope.dart';
import '../../core/theme.dart';
import '../screens/perf_lab_screen.dart';

/// Barra superior das áreas da equipe: título, unidade e menu (sair,
/// laboratório de performance).
class EquipeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EquipeAppBar({super.key, required this.titulo, this.subtitulo, this.acoes = const []});

  final String titulo;
  final String? subtitulo;
  final List<Widget> acoes;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo),
            if (subtitulo != null)
              Text(subtitulo!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white)),
          ],
        ),
        actions: [
          ...acoes,
          PopupMenuButton<String>(
            tooltip: 'Menu',
            iconColor: Colors.white,
            onSelected: (v) {
              if (v == 'sair') sair(context);
              if (v == 'perf') {
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PerfLabScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'perf', child: Text('Laboratório de performance')),
              PopupMenuItem(value: 'sair', child: Text('Sair')),
            ],
          ),
        ],
      );
}

/// Faixa de "sem conexão" (EX13): o app continua funcionando no modo local e
/// guarda as operações para enviar quando a internet voltar.
class BannerConexao extends StatelessWidget {
  const BannerConexao({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repo;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (repo.online) return const SizedBox.shrink();
        return Material(
          color: const Color(0xFF3B4C49),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sem conexão – modo local. ${repo.operacoesPendentes} registro(s) aguardando envio.',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Contador grande usado nos painéis.
class Indicador extends StatelessWidget {
  const Indicador({super.key, required this.valor, required this.rotulo, this.cor = AppColors.primaria});
  final String valor;
  final String rotulo;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.borda),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: cor)),
            const SizedBox(height: 2),
            Text(rotulo, style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
          ],
        ),
      );
}
