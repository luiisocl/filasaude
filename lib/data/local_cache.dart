// Cache local com Hive (banco chave-valor em Dart puro, muito rápido para
// abrir no cold start). Guarda:
// - o estado da unidade (senhas, pacientes, equipe), para o app abrir já com
//   os dados da última sessão, mesmo sem internet (RNF04);
// - a sessão logada;
// - a "caixa de saída" (outbox): operações feitas offline que ainda não
//   foram enviadas ao servidor.
import 'package:hive_flutter/hive_flutter.dart';

class LocalCache {
  static const _boxEstado = 'estado';
  static const _boxOutbox = 'outbox';

  late Box<String> _estado;
  late Box<String> _outbox;

  Future<void> init() async {
    await Hive.initFlutter('filasaude');
    _estado = await Hive.openBox<String>(_boxEstado);
    _outbox = await Hive.openBox<String>(_boxOutbox);
  }

  String? ler(String chave) => _estado.get(chave);

  Future<void> salvar(String chave, String valor) => _estado.put(chave, valor);

  Future<void> remover(String chave) => _estado.delete(chave);

  // ---- outbox -------------------------------------------------------------

  Future<void> enfileirar(String operacaoJson) => _outbox.add(operacaoJson);

  int get pendentes => _outbox.length;

  /// Retorna até [max] operações pendentes, com as chaves para removê-las depois.
  List<MapEntry<dynamic, String>> lote(int max) =>
      _outbox.keys.take(max).map((k) => MapEntry<dynamic, String>(k, _outbox.get(k)!)).toList();

  Future<void> confirmarEnvio(Iterable<dynamic> chaves) => _outbox.deleteAll(chaves);

  Future<void> limparTudo() async {
    await _estado.clear();
    await _outbox.clear();
  }
}
