// Injeção de dependências sem pacotes externos.
//
// AppScope: entrega o repositório, a sessão e o cache para toda a árvore.
// VmScope:  cria um ViewModel quando a área abre e chama dispose() quando ela
//           fecha (evita vazamento de memória). As telas leem o ViewModel com
//           VmScope.read (não reconstrói) ou VmScope.watch (reconstrói só
//           quem depende dele quando ele avisa uma mudança).
import 'package:flutter/widgets.dart';

import '../data/fila_repository.dart';
import '../data/local_cache.dart';
import '../presentation/viewmodels/session_viewmodel.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repo,
    required this.session,
    required this.cache,
    required super.child,
  });

  final FilaRepository repo;
  final SessionViewModel session;
  final LocalCache cache;

  static AppScope of(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repo != oldWidget.repo || session != oldWidget.session || cache != oldWidget.cache;
}

class VmScope<T extends ChangeNotifier> extends StatefulWidget {
  const VmScope({super.key, required this.create, required this.child});

  final T Function(BuildContext context) create;
  final Widget child;

  /// Lê sem se inscrever (para chamar ações em callbacks).
  static T read<T extends ChangeNotifier>(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_VmInherited<T>>()!.notifier!;

  /// Lê e reconstrói quando o ViewModel notificar.
  static T watch<T extends ChangeNotifier>(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_VmInherited<T>>()!.notifier!;

  /// Abre uma nova tela levando o mesmo ViewModel (rotas novas não ficam
  /// abaixo do VmScope na árvore, então o ViewModel é repassado).
  static Future<R?> push<T extends ChangeNotifier, R>(BuildContext context, Widget page, {bool fullscreen = false}) {
    final vm = read<T>(context);
    return Navigator.of(context).push<R>(
      PageRouteBuilder<R>(
        opaque: true,
        fullscreenDialog: fullscreen,
        pageBuilder: (_, __, ___) => _VmInherited<T>(notifier: vm, child: page),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(anim),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  @override
  State<VmScope<T>> createState() => _VmScopeState<T>();
}

class _VmScopeState<T extends ChangeNotifier> extends State<VmScope<T>> {
  late final T _vm = widget.create(context);

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _VmInherited<T>(notifier: _vm, child: widget.child);
}

class _VmInherited<T extends ChangeNotifier> extends InheritedNotifier<T> {
  const _VmInherited({required super.notifier, required super.child});
}
