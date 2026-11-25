import 'package:filasaude/data/historico.dart';
import 'package:filasaude/domain/entities.dart';
import 'package:filasaude/domain/fila_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Senha _senha(String id, {CorRisco? cor, PrioridadeLegal prio = PrioridadeLegal.nenhuma, required DateTime chegada}) {
  final s = Senha(
    id: id,
    codigo: id,
    pacienteId: 'p$id',
    unidadeId: 'u',
    tipo: TipoAtendimento.urgencia,
    origem: OrigemSenha.presencial,
    retiradaEm: chegada,
    etapa: EtapaSenha.aguardandoMedico,
    prioridade: prio,
  )
    ..chegadaEm = chegada
    ..ordemFila = chegada;
  if (cor != null) {
    s.triagem = Triagem(cor: cor, queixa: '', sinais: const SinaisVitais(), enfermeiro: '', horario: chegada);
  }
  return s;
}

void main() {
  final t0 = DateTime(2026, 11, 24, 8);

  test('RN03: cor primeiro, depois prioridade legal, depois chegada', () {
    final a = _senha('A', cor: CorRisco.verde, chegada: t0);
    final b = _senha('B', cor: CorRisco.amarelo, chegada: t0.add(const Duration(minutes: 30)));
    final c = _senha('C', cor: CorRisco.verde, prio: PrioridadeLegal.idoso, chegada: t0.add(const Duration(minutes: 10)));
    final fila = [a, b, c]..sort(FilaRules.comparar);
    expect(fila.map((s) => s.id), ['B', 'C', 'A']);
  });

  test('RN09: tempo estimado e EX12 sem médico', () {
    expect(FilaRules.tempoEstimado(pessoasAFrente: 3, medicosAtivos: 2), const Duration(minutes: 24));
    expect(FilaRules.tempoEstimado(pessoasAFrente: 3, medicosAtivos: 0), isNull);
  });

  test('RN08: excedeu o tempo máximo da cor', () {
    final s = _senha('X', cor: CorRisco.laranja, chegada: t0);
    expect(FilaRules.excedeuTempo(s, t0.add(const Duration(minutes: 9))), isFalse);
    expect(FilaRules.excedeuTempo(s, t0.add(const Duration(minutes: 11))), isTrue);
  });

  test('Validação de CPF', () {
    expect(FilaRules.cpfValido('529.982.247-25'), isTrue);
    expect(FilaRules.cpfValido('111.111.111-11'), isFalse);
    expect(FilaRules.cpfValido('529.982.247-24'), isFalse);
  });

  test('Relatório: versão compacta e versão com mapas dão o mesmo resultado', () {
    const p = GeracaoParams(5000, 20000);
    final compacto = calcularRelatorio(RelatorioParams(gerarHistoricoCompacto(p), 19700, 20000));
    final objetos = calcularRelatorioObjetos(gerarHistoricoObjetos(p), 19700, 20000);
    expect(compacto.total, objetos.total);
    expect(compacto.p90EsperaPorCor, objetos.p90EsperaPorCor);
    expect(compacto.desfechos, objetos.desfechos);
  });
}
