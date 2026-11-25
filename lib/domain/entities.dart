// Entidades do domínio do FilaSaúde.
// Camada pura: não importa Flutter, por isso pode rodar dentro de Isolates.

/// Perfis de acesso (RN11).
enum Perfil {
  paciente('Paciente'),
  recepcao('Recepção'),
  enfermeiro('Enfermeiro(a)'),
  medico('Médico(a)'),
  coordenador('Coordenador(a)');

  const Perfil(this.label);
  final String label;
}

/// Classificação de risco – Protocolo de Manchester (RN01).
/// A ordem do enum é a ordem de prioridade na fila.
enum CorRisco {
  vermelho('Vermelho', 'Emergência', 0),
  laranja('Laranja', 'Muito urgente', 10),
  amarelo('Amarelo', 'Urgente', 60),
  verde('Verde', 'Pouco urgente', 120),
  azul('Azul', 'Não urgente', 240);

  const CorRisco(this.label, this.descricao, this.tempoMaxMin);
  final String label;
  final String descricao;

  /// Tempo máximo de espera em minutos (0 = imediato).
  final int tempoMaxMin;

  String get prazoTexto => tempoMaxMin == 0 ? 'imediato' : 'até $tempoMaxMin min';
}

enum TipoAtendimento {
  urgencia('Urgência', 'U', 'Dor, febre alta, mal-estar repentino'),
  consultaUbs('Consulta na UBS', 'C', 'Renovação de receita, sintomas leves');

  const TipoAtendimento(this.label, this.prefixo, this.descricao);
  final String label;
  final String prefixo;
  final String descricao;
}

/// Prioridades previstas em lei (RN03).
enum PrioridadeLegal {
  nenhuma('Sem prioridade'),
  idoso('Idoso 60+'),
  gestante('Gestante'),
  deficiencia('Pessoa com deficiência'),
  lactante('Lactante / criança de colo'),
  autista('Pessoa autista');

  const PrioridadeLegal(this.label);
  final String label;
}

/// Etapas de uma senha, do início ao fim.
enum EtapaSenha {
  aguardandoChegada('Aguardando chegada'),
  aguardandoTriagem('Aguardando triagem'),
  aguardandoMedico('Aguardando atendimento médico'),
  chamado('Chamado'),
  emAtendimento('Em atendimento'),
  emergencia('Emergência – sala vermelha'),
  finalizado('Finalizado'),
  expirada('Expirada'),
  desistiu('Desistência'),
  cancelada('Cancelada');

  const EtapaSenha(this.label);
  final String label;

  bool get ativa =>
      this != finalizado && this != expirada && this != desistiu && this != cancelada;
}

enum Desfecho {
  alta('Alta'),
  retorno('Retorno agendado'),
  observacao('Observação'),
  transferencia('Transferência');

  const Desfecho(this.label);
  final String label;
}

enum OrigemSenha { app, presencial }

// ---------------------------------------------------------------------------

class Unidade {
  Unidade({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.ehUpa,
    required this.abre,
    required this.fecha,
    required this.distanciaKm,
    required this.consultorios,
  });

  final String id;
  String nome;
  final String endereco;
  final bool ehUpa;

  /// Horário de funcionamento (horas). UPA = 0 a 24.
  int abre;
  int fecha;
  final double distanciaKm;
  int consultorios;

  bool get aberta24h => abre == 0 && fecha == 24;

  bool estaAberta(DateTime agora) => aberta24h || (agora.hour >= abre && agora.hour < fecha);

  String get horarioTexto =>
      aberta24h ? 'Aberta 24h' : '${abre.toString().padLeft(2, '0')}h às ${fecha.toString().padLeft(2, '0')}h';

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'endereco': endereco,
        'ehUpa': ehUpa,
        'abre': abre,
        'fecha': fecha,
        'distanciaKm': distanciaKm,
        'consultorios': consultorios,
      };

  factory Unidade.fromJson(Map<String, dynamic> j) => Unidade(
        id: j['id'] as String,
        nome: j['nome'] as String,
        endereco: j['endereco'] as String,
        ehUpa: j['ehUpa'] as bool,
        abre: j['abre'] as int,
        fecha: j['fecha'] as int,
        distanciaKm: (j['distanciaKm'] as num).toDouble(),
        consultorios: j['consultorios'] as int,
      );
}

class Paciente {
  Paciente({
    required this.id,
    required this.nome,
    required this.nascimento,
    required this.telefone,
    required this.documento,
    this.simulado = false,
  });

  final String id;
  String nome;
  DateTime nascimento;
  String telefone;

  /// CPF ou Cartão SUS, só dígitos.
  final String documento;

  /// Pacientes criados pela simulação de demonstração.
  final bool simulado;

  String get primeiroNome => nome.trim().split(' ').first;

  /// "Maria S." – o nome completo não aparece em listas (LGPD).
  String get nomeCurto {
    final partes = nome.trim().split(' ');
    if (partes.length < 2) return partes.first;
    return '${partes.first} ${partes.last[0]}.';
  }

  int idade(DateTime hoje) {
    var anos = hoje.year - nascimento.year;
    if (hoje.month < nascimento.month ||
        (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
      anos--;
    }
    return anos;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'nascimento': nascimento.toIso8601String(),
        'telefone': telefone,
        'documento': documento,
        'simulado': simulado,
      };

  factory Paciente.fromJson(Map<String, dynamic> j) => Paciente(
        id: j['id'] as String,
        nome: j['nome'] as String,
        nascimento: DateTime.parse(j['nascimento'] as String),
        telefone: j['telefone'] as String,
        documento: j['documento'] as String,
        simulado: j['simulado'] as bool? ?? false,
      );
}

class SinaisVitais {
  const SinaisVitais({
    this.pressao = '',
    this.frequenciaCardiaca = '',
    this.temperatura = '',
    this.saturacao = '',
    this.glicemia = '',
    this.dor = 0,
  });

  final String pressao;
  final String frequenciaCardiaca;
  final String temperatura;
  final String saturacao;
  final String glicemia;
  final int dor;

  Map<String, dynamic> toJson() => {
        'pressao': pressao,
        'fc': frequenciaCardiaca,
        'temp': temperatura,
        'sat': saturacao,
        'gli': glicemia,
        'dor': dor,
      };

  factory SinaisVitais.fromJson(Map<String, dynamic> j) => SinaisVitais(
        pressao: j['pressao'] as String? ?? '',
        frequenciaCardiaca: j['fc'] as String? ?? '',
        temperatura: j['temp'] as String? ?? '',
        saturacao: j['sat'] as String? ?? '',
        glicemia: j['gli'] as String? ?? '',
        dor: j['dor'] as int? ?? 0,
      );
}

/// Registro de auditoria de mudança de cor (RNF10).
class Reclassificacao {
  const Reclassificacao({
    required this.de,
    required this.para,
    required this.motivo,
    required this.responsavel,
    required this.horario,
  });

  final CorRisco? de;
  final CorRisco para;
  final String motivo;
  final String responsavel;
  final DateTime horario;

  Map<String, dynamic> toJson() => {
        'de': de?.index,
        'para': para.index,
        'motivo': motivo,
        'resp': responsavel,
        'hora': horario.toIso8601String(),
      };

  factory Reclassificacao.fromJson(Map<String, dynamic> j) => Reclassificacao(
        de: j['de'] == null ? null : CorRisco.values[j['de'] as int],
        para: CorRisco.values[j['para'] as int],
        motivo: j['motivo'] as String,
        responsavel: j['resp'] as String,
        horario: DateTime.parse(j['hora'] as String),
      );
}

class Triagem {
  Triagem({
    required this.cor,
    required this.queixa,
    required this.sinais,
    required this.enfermeiro,
    required this.horario,
    List<Reclassificacao>? historico,
  }) : historico = historico ?? [];

  CorRisco cor;
  final String queixa;
  final SinaisVitais sinais;
  final String enfermeiro;

  /// Momento da classificação atual: o prazo da cor conta a partir daqui.
  DateTime horario;
  final List<Reclassificacao> historico;

  Map<String, dynamic> toJson() => {
        'cor': cor.index,
        'queixa': queixa,
        'sinais': sinais.toJson(),
        'enf': enfermeiro,
        'hora': horario.toIso8601String(),
        'hist': historico.map((r) => r.toJson()).toList(),
      };

  factory Triagem.fromJson(Map<String, dynamic> j) => Triagem(
        cor: CorRisco.values[j['cor'] as int],
        queixa: j['queixa'] as String,
        sinais: SinaisVitais.fromJson(Map<String, dynamic>.from(j['sinais'] as Map)),
        enfermeiro: j['enf'] as String,
        horario: DateTime.parse(j['hora'] as String),
        historico: (j['hist'] as List)
            .map((e) => Reclassificacao.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class Senha {
  Senha({
    required this.id,
    required this.codigo,
    required this.pacienteId,
    required this.unidadeId,
    required this.tipo,
    required this.origem,
    required this.retiradaEm,
    this.etapa = EtapaSenha.aguardandoChegada,
    this.prioridade = PrioridadeLegal.nenhuma,
    this.simulada = false,
  });

  final String id;
  final String codigo;
  final String pacienteId;
  final String unidadeId;
  final TipoAtendimento tipo;
  final OrigemSenha origem;
  final DateTime retiradaEm;
  final bool simulada;

  EtapaSenha etapa;
  PrioridadeLegal prioridade;
  DateTime? chegadaEm;

  /// Usado para ordenar a fila. Começa na chegada; volta para o fim
  /// da cor quando o paciente não responde a 2 chamadas (RN07).
  DateTime? ordemFila;
  Triagem? triagem;
  int chamadas = 0;
  DateTime? ultimaChamadaEm;
  int? consultorio;
  String? medico;
  DateTime? atendimentoInicio;
  DateTime? finalizadoEm;
  Desfecho? desfecho;
  String? observacao;
  int? avaliacao;
  String? comentarioAvaliacao;

  CorRisco? get cor => triagem?.cor;

  Map<String, dynamic> toJson() => {
        'id': id,
        'codigo': codigo,
        'pac': pacienteId,
        'uni': unidadeId,
        'tipo': tipo.index,
        'origem': origem.index,
        'retirada': retiradaEm.toIso8601String(),
        'sim': simulada,
        'etapa': etapa.index,
        'prio': prioridade.index,
        'chegada': chegadaEm?.toIso8601String(),
        'ordem': ordemFila?.toIso8601String(),
        'triagem': triagem?.toJson(),
        'chamadas': chamadas,
        'ultChamada': ultimaChamadaEm?.toIso8601String(),
        'consultorio': consultorio,
        'medico': medico,
        'iniAtend': atendimentoInicio?.toIso8601String(),
        'fim': finalizadoEm?.toIso8601String(),
        'desfecho': desfecho?.index,
        'obs': observacao,
        'aval': avaliacao,
        'avalTxt': comentarioAvaliacao,
      };

  factory Senha.fromJson(Map<String, dynamic> j) {
    DateTime? d(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    final s = Senha(
      id: j['id'] as String,
      codigo: j['codigo'] as String,
      pacienteId: j['pac'] as String,
      unidadeId: j['uni'] as String,
      tipo: TipoAtendimento.values[j['tipo'] as int],
      origem: OrigemSenha.values[j['origem'] as int],
      retiradaEm: DateTime.parse(j['retirada'] as String),
      etapa: EtapaSenha.values[j['etapa'] as int],
      prioridade: PrioridadeLegal.values[j['prio'] as int],
      simulada: j['sim'] as bool? ?? false,
    );
    s
      ..chegadaEm = d('chegada')
      ..ordemFila = d('ordem')
      ..triagem = j['triagem'] == null
          ? null
          : Triagem.fromJson(Map<String, dynamic>.from(j['triagem'] as Map))
      ..chamadas = j['chamadas'] as int? ?? 0
      ..ultimaChamadaEm = d('ultChamada')
      ..consultorio = j['consultorio'] as int?
      ..medico = j['medico'] as String?
      ..atendimentoInicio = d('iniAtend')
      ..finalizadoEm = d('fim')
      ..desfecho = j['desfecho'] == null ? null : Desfecho.values[j['desfecho'] as int]
      ..observacao = j['obs'] as String?
      ..avaliacao = j['aval'] as int?
      ..comentarioAvaliacao = j['avalTxt'] as String?;
    return s;
  }
}

class Funcionario {
  Funcionario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    this.senha = '123456',
    this.ativo = true,
  });

  final String id;
  String nome;
  String email;
  Perfil perfil;
  String senha;
  bool ativo;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'perfil': perfil.index,
        'senha': senha,
        'ativo': ativo,
      };

  factory Funcionario.fromJson(Map<String, dynamic> j) => Funcionario(
        id: j['id'] as String,
        nome: j['nome'] as String,
        email: j['email'] as String,
        perfil: Perfil.values[j['perfil'] as int],
        senha: j['senha'] as String? ?? '123456',
        ativo: j['ativo'] as bool? ?? true,
      );
}
