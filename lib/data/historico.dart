// Histórico de atendimentos da unidade (base para os relatórios do
// coordenador). São centenas de milhares de registros, por isso este arquivo
// concentra as duas otimizações de memória e CPU do app:
//
// 1. Estrutura compacta: em vez de uma lista de objetos/mapas (cada registro
//    vira um objeto no heap), os campos ficam em arrays tipados contíguos
//    (Int32List, Uint8List, Uint16List): poucos bytes por registro e quase
//    nada para o coletor de lixo percorrer.
// 2. Processamento em Isolate: as funções top-level abaixo são chamadas com
//    `compute()`, que roda numa thread separada e não trava a UI.
//
// No modo "não otimizado" (Laboratório de performance) o app usa a versão
// com List<Map> e calcula tudo na thread principal, para comparar no DevTools.
import 'dart:math';
import 'dart:typed_data';

class HistoricoCompacto {
  HistoricoCompacto(this.dias, this.cores, this.esperas, this.duracoes, this.flags);

  /// Dia do atendimento (dias desde 1970-01-01).
  final Int32List dias;

  /// Índice de CorRisco (0 = vermelho ... 4 = azul).
  final Uint8List cores;

  /// Minutos de espera até o atendimento.
  final Uint16List esperas;

  /// Minutos de atendimento médico.
  final Uint16List duracoes;

  /// bit 0 = desistência; bits 1-2 = desfecho (0 alta, 1 retorno, 2 observação, 3 transferência).
  final Uint8List flags;

  int get length => dias.length;

  int get bytes =>
      dias.lengthInBytes +
      cores.lengthInBytes +
      esperas.lengthInBytes +
      duracoes.lengthInBytes +
      flags.lengthInBytes;
}

/// Parâmetros de geração (precisa ser um único argumento para o compute).
class GeracaoParams {
  const GeracaoParams(this.quantidade, this.hojeDia);
  final int quantidade;
  final int hojeDia;
}

int diaDe(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

DateTime dataDoDia(int dia) => DateTime.fromMillisecondsSinceEpoch(dia * 86400000, isUtc: true);

// Distribuição realista: a maioria verde/amarelo, poucos vermelhos.
const _pesoCor = [2, 8, 30, 50, 10];

int _sortearCor(Random r) {
  var x = r.nextInt(100);
  for (var i = 0; i < _pesoCor.length; i++) {
    if (x < _pesoCor[i]) return i;
    x -= _pesoCor[i];
  }
  return 3;
}

const _esperaBase = [0, 8, 45, 95, 160];

/// Versão otimizada: arrays tipados. Determinística (semente fixa) para que
/// as medições "antes x depois" usem exatamente os mesmos dados.
HistoricoCompacto gerarHistoricoCompacto(GeracaoParams p) {
  final r = Random(42);
  final n = p.quantidade;
  final dias = Int32List(n);
  final cores = Uint8List(n);
  final esperas = Uint16List(n);
  final duracoes = Uint16List(n);
  final flags = Uint8List(n);
  for (var i = 0; i < n; i++) {
    final cor = _sortearCor(r);
    dias[i] = p.hojeDia - 1 - r.nextInt(365);
    cores[i] = cor;
    esperas[i] = _esperaBase[cor] + r.nextInt(_esperaBase[cor] ~/ 2 + 10);
    duracoes[i] = 6 + r.nextInt(20);
    final desistiu = cor >= 3 && r.nextInt(100) < 7;
    final desfecho = r.nextInt(100) < 78 ? 0 : 1 + r.nextInt(3);
    flags[i] = (desistiu ? 1 : 0) | (desfecho << 1);
  }
  return HistoricoCompacto(dias, cores, esperas, duracoes, flags);
}

/// Versão "antes": um Map por registro. Mesmos números, muito mais memória.
List<Map<String, Object>> gerarHistoricoObjetos(GeracaoParams p) {
  final c = gerarHistoricoCompacto(p);
  return List.generate(
    c.length,
    (i) => {
      'dia': c.dias[i],
      'cor': c.cores[i],
      'espera': c.esperas[i],
      'duracao': c.duracoes[i],
      'desistiu': c.flags[i] & 1 == 1,
      'desfecho': c.flags[i] >> 1,
    },
    growable: false,
  );
}

// ---------------------------------------------------------------------------
// Relatório

class RelatorioParams {
  const RelatorioParams(this.historico, this.inicioDia, this.fimDia);
  final HistoricoCompacto historico;
  final int inicioDia;
  final int fimDia;
}

class Relatorio {
  Relatorio({
    required this.total,
    required this.desistencias,
    required this.porCor,
    required this.mediaEsperaPorCor,
    required this.p90EsperaPorCor,
    required this.mediaDuracao,
    required this.porDiaSemana,
    required this.desfechos,
    required this.dentroDoPrazoPct,
  });

  final int total;
  final int desistencias;
  final List<int> porCor;
  final List<double> mediaEsperaPorCor;

  /// 90% dos pacientes esperaram até este tempo (exige ordenar os dados).
  final List<int> p90EsperaPorCor;
  final double mediaDuracao;

  /// Segunda (0) a domingo (6).
  final List<int> porDiaSemana;
  final List<int> desfechos;
  final double dentroDoPrazoPct;

  double get taxaDesistencia => total == 0 ? 0 : desistencias / total;
}

const _prazoCor = [0, 10, 60, 120, 240];

Relatorio _montar(
  List<List<int>> esperasPorCor,
  int total,
  int desist,
  int somaDuracao,
  List<int> porDia,
  List<int> desf,
) {
  final medias = <double>[];
  final p90 = <int>[];
  var dentro = 0;
  for (var c = 0; c < 5; c++) {
    final l = esperasPorCor[c];
    if (l.isEmpty) {
      medias.add(0);
      p90.add(0);
      continue;
    }
    var soma = 0;
    for (final v in l) {
      soma += v;
      if (v <= _prazoCor[c] || c == 0) dentro++;
    }
    medias.add(soma / l.length);
    l.sort(); // O(n log n): o trecho mais pesado do relatório.
    p90.add(l[((l.length - 1) * 0.9).round()]);
  }
  final atendidos = total - desist;
  return Relatorio(
    total: total,
    desistencias: desist,
    porCor: [for (final l in esperasPorCor) l.length],
    mediaEsperaPorCor: medias,
    p90EsperaPorCor: p90,
    mediaDuracao: atendidos == 0 ? 0 : somaDuracao / atendidos,
    porDiaSemana: porDia,
    desfechos: desf,
    dentroDoPrazoPct: total == 0 ? 0 : dentro * 100 / total,
  );
}

/// Executado em Isolate via compute() no modo otimizado.
Relatorio calcularRelatorio(RelatorioParams p) {
  final h = p.historico;
  final esperas = List.generate(5, (_) => <int>[]);
  final porDia = List.filled(7, 0);
  final desf = List.filled(4, 0);
  var total = 0, desist = 0, somaDur = 0;
  for (var i = 0; i < h.length; i++) {
    final dia = h.dias[i];
    if (dia < p.inicioDia || dia > p.fimDia) continue;
    total++;
    esperas[h.cores[i]].add(h.esperas[i]);
    porDia[(dia + 3) % 7]++; // 01/01/1970 foi quinta-feira
    if (h.flags[i] & 1 == 1) {
      desist++;
    } else {
      somaDur += h.duracoes[i];
      desf[h.flags[i] >> 1]++;
    }
  }
  return _montar(esperas, total, desist, somaDur, porDia, desf);
}

/// Versão "antes": percorre a lista de mapas, na thread principal.
Relatorio calcularRelatorioObjetos(List<Map<String, Object>> lista, int inicioDia, int fimDia) {
  final esperas = List.generate(5, (_) => <int>[]);
  final porDia = List.filled(7, 0);
  final desf = List.filled(4, 0);
  var total = 0, desist = 0, somaDur = 0;
  for (final m in lista) {
    final dia = m['dia']! as int;
    if (dia < inicioDia || dia > fimDia) continue;
    total++;
    esperas[m['cor']! as int].add(m['espera']! as int);
    porDia[(dia + 3) % 7]++;
    if (m['desistiu']! as bool) {
      desist++;
    } else {
      somaDur += m['duracao']! as int;
      desf[m['desfecho']! as int]++;
    }
  }
  return _montar(esperas, total, desist, somaDur, porDia, desf);
}
