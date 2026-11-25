// Envio das operações para o "servidor": monta o lote em JSON e comprime
// com GZIP antes de mandar pela rede (menos dados = envio mais rápido e
// mais barato no 3G/4G). Função top-level para poder rodar em Isolate.
import 'dart:convert';
import 'dart:io' show gzip;

class LoteCompactado {
  const LoteCompactado(this.bytesJson, this.bytesGzip, this.corpo);
  final int bytesJson;
  final int bytesGzip;

  /// Corpo comprimido que seria enviado na requisição HTTP.
  final List<int> corpo;
}

LoteCompactado compactarLote(List<String> operacoesJson) {
  final json = '[${operacoesJson.join(',')}]';
  final bruto = utf8.encode(json);
  final comprimido = gzip.encode(bruto);
  return LoteCompactado(bruto.length, comprimido.length, comprimido);
}
