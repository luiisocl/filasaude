// Regras de negócio do DRS, como funções puras (fáceis de testar e
// independentes da interface).
import 'entities.dart';

class FilaRules {
  FilaRules._();

  /// RN05: senha do app expira se a chegada não for confirmada em 1 hora.
  static const prazoChegada = Duration(hours: 1);

  /// RN07: tempo para se apresentar após a chamada.
  static const prazoChamada = Duration(minutes: 5);

  /// RN09: duração média de um atendimento médico e de uma triagem.
  static const mediaAtendimentoMin = 12;
  static const mediaTriagemMin = 5;

  /// RN03: cor de risco primeiro; na mesma cor, prioridade legal;
  /// depois a ordem de chegada.
  static int comparar(Senha a, Senha b) {
    final cor = (a.cor?.index ?? 99).compareTo(b.cor?.index ?? 99);
    if (cor != 0) return cor;
    final pa = a.prioridade == PrioridadeLegal.nenhuma ? 1 : 0;
    final pb = b.prioridade == PrioridadeLegal.nenhuma ? 1 : 0;
    if (pa != pb) return pa.compareTo(pb);
    final oa = a.ordemFila ?? a.chegadaEm ?? a.retiradaEm;
    final ob = b.ordemFila ?? b.chegadaEm ?? b.retiradaEm;
    return oa.compareTo(ob);
  }

  /// Fila de triagem: prioridade legal primeiro, depois a ordem de chegada.
  static int compararTriagem(Senha a, Senha b) {
    final pa = a.prioridade == PrioridadeLegal.nenhuma ? 1 : 0;
    final pb = b.prioridade == PrioridadeLegal.nenhuma ? 1 : 0;
    if (pa != pb) return pa.compareTo(pb);
    return (a.chegadaEm ?? a.retiradaEm).compareTo(b.chegadaEm ?? b.retiradaEm);
  }

  /// RN09: tempo estimado = pessoas à frente × média ÷ médicos ativos.
  /// Retorna null quando não há médico disponível (EX12).
  static Duration? tempoEstimado({
    required int pessoasAFrente,
    required int medicosAtivos,
    int mediaMin = mediaAtendimentoMin,
  }) {
    if (medicosAtivos <= 0) return null;
    final minutos = ((pessoasAFrente + 1) * mediaMin / medicosAtivos).ceil();
    return Duration(minutes: minutos);
  }

  /// RN08: passou do tempo máximo da cor?
  static bool excedeuTempo(Senha s, DateTime agora) {
    final t = s.triagem;
    if (t == null || s.etapa != EtapaSenha.aguardandoMedico) return false;
    if (t.cor == CorRisco.vermelho) return false;
    return agora.difference(t.horario).inMinutes > t.cor.tempoMaxMin;
  }

  /// Minutos que faltam para o prazo da cor (negativo = atrasado).
  static int minutosParaPrazo(Senha s, DateTime agora) {
    final t = s.triagem;
    if (t == null) return 0;
    return t.cor.tempoMaxMin - agora.difference(t.horario).inMinutes;
  }

  /// RN05
  static bool expirou(Senha s, DateTime agora) =>
      s.etapa == EtapaSenha.aguardandoChegada &&
      s.origem == OrigemSenha.app &&
      agora.difference(s.retiradaEm) > prazoChegada;

  /// Validação de CPF (dígitos verificadores).
  static bool cpfValido(String valor) {
    final d = valor.replaceAll(RegExp(r'\D'), '');
    if (d.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
    int dv(int len) {
      var soma = 0;
      for (var i = 0; i < len; i++) {
        soma += int.parse(d[i]) * (len + 1 - i);
      }
      final r = (soma * 10) % 11;
      return r == 10 ? 0 : r;
    }

    return dv(9) == int.parse(d[9]) && dv(10) == int.parse(d[10]);
  }

  /// Cartão SUS tem 15 dígitos.
  static bool cartaoSusValido(String valor) =>
      valor.replaceAll(RegExp(r'\D'), '').length == 15;

  static bool documentoValido(String valor) => cpfValido(valor) || cartaoSusValido(valor);

  /// RN10: sintomas que mandam ligar para o SAMU.
  static const sintomasGraves = 'Dor no peito, falta de ar intensa, desmaio ou sangramento grave';
}
