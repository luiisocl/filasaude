import 'package:flutter/foundation.dart';

import '../../data/fila_repository.dart';

/// Base dos ViewModels de cada área: escuta o repositório enquanto a área
/// está aberta e para de escutar no dispose (sem isso o repositório
/// continuaria segurando o ViewModel na memória: memory leak).
abstract class AreaViewModel extends ChangeNotifier {
  AreaViewModel(this.repo) {
    repo.addListener(_repoMudou);
  }

  final FilaRepository repo;
  bool _descartado = false;

  void _repoMudou() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    repo.removeListener(_repoMudou);
    super.dispose();
  }
}
