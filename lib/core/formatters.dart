import 'package:flutter/services.dart';

/// Formatação simples em pt-BR, sem pacotes externos.
class Fmt {
  Fmt._();

  static String dois(int n) => n.toString().padLeft(2, '0');

  static String hora(DateTime d) => '${dois(d.hour)}:${dois(d.minute)}';

  static String data(DateTime d) => '${dois(d.day)}/${dois(d.month)}/${d.year}';

  static String dataHora(DateTime d) => '${data(d)} às ${hora(d)}';

  static const _meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

  static String dataCurta(DateTime d) => '${dois(d.day)} ${_meses[d.month - 1]}';

  static String duracao(Duration d) {
    final m = d.inMinutes;
    if (m < 1) return 'menos de 1 min';
    if (m < 60) return '$m min';
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? '${h}h' : '${h}h${dois(r)}';
  }

  static String haQuanto(DateTime d, DateTime agora) {
    final m = agora.difference(d).inMinutes;
    if (m < 1) return 'agora';
    if (m < 60) return 'há $m min';
    return 'há ${duracao(agora.difference(d))}';
  }

  static String contagem(Duration d) {
    if (d.isNegative) return '00:00';
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return h > 0 ? '$h:${dois(m)}:${dois(s)}' : '${dois(m)}:${dois(s)}';
  }

  static String milhar(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String bytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static String documento(String digitos) {
    if (digitos.length == 11) {
      return '${digitos.substring(0, 3)}.${digitos.substring(3, 6)}.${digitos.substring(6, 9)}-${digitos.substring(9)}';
    }
    if (digitos.length == 15) {
      return '${digitos.substring(0, 3)} ${digitos.substring(3, 7)} ${digitos.substring(7, 11)} ${digitos.substring(11)}';
    }
    return digitos;
  }
}

/// Máscara por padrão: "#" = dígito. Ex.: "###.###.###-##".
class MascaraFormatter extends TextInputFormatter {
  MascaraFormatter(this.padrao);
  final String padrao;

  int get maxDigitos => '#'.allMatches(padrao).length;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    final b = StringBuffer();
    var i = 0;
    for (final ch in padrao.split('')) {
      if (i >= digitos.length) break;
      if (ch == '#') {
        b.write(digitos[i++]);
      } else {
        b.write(ch);
      }
    }
    final texto = b.toString();
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}

/// CPF (11 dígitos) ou Cartão SUS (15 dígitos), escolhendo a máscara pelo tamanho.
class DocumentoFormatter extends TextInputFormatter {
  final _cpf = MascaraFormatter('###.###.###-##');
  final _sus = MascaraFormatter('### #### #### ####');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final n = newValue.text.replaceAll(RegExp(r'\D'), '').length;
    return (n <= 11 ? _cpf : _sus).formatEditUpdate(oldValue, newValue);
  }
}
