// Dados iniciais da demonstração: unidades, equipe e pacientes já na fila.
import 'dart:math';

import '../domain/entities.dart';

class Seed {
  Seed._();

  static const unidadePrincipal = 'upa-centro';

  static List<Unidade> unidades() => [
        Unidade(
          id: unidadePrincipal,
          nome: 'UPA Centro',
          endereco: 'Av. Frei Serafim, 1500 – Centro',
          ehUpa: true,
          abre: 0,
          fecha: 24,
          distanciaKm: 1.2,
          consultorios: 4,
        ),
        Unidade(
          id: 'upa-norte',
          nome: 'UPA Zona Norte',
          endereco: 'Rua Desembargador Flávio Furtado, 320',
          ehUpa: true,
          abre: 0,
          fecha: 24,
          distanciaKm: 5.8,
          consultorios: 3,
        ),
        Unidade(
          id: 'ubs-satelite',
          nome: 'UBS Satélite',
          endereco: 'Rua Pedro Freitas, 88 – Satélite',
          ehUpa: false,
          abre: 7,
          fecha: 19,
          distanciaKm: 3.4,
          consultorios: 2,
        ),
      ];

  static List<Funcionario> funcionarios() => [
        Funcionario(id: 'f1', nome: 'Carla Menezes', email: 'recepcao@filasaude.com', perfil: Perfil.recepcao),
        Funcionario(id: 'f2', nome: 'Enf. Rafael Sousa', email: 'enfermeiro@filasaude.com', perfil: Perfil.enfermeiro),
        Funcionario(id: 'f3', nome: 'Dra. Helena Rocha', email: 'medico@filasaude.com', perfil: Perfil.medico),
        Funcionario(id: 'f4', nome: 'Marcos Albuquerque', email: 'coordenador@filasaude.com', perfil: Perfil.coordenador),
        Funcionario(id: 'f5', nome: 'Dr. Paulo Viana', email: 'paulo.viana@filasaude.com', perfil: Perfil.medico),
      ];

  /// Paciente pronto para a demonstração (login com este CPF).
  static Paciente pacienteDemo() => Paciente(
        id: 'p-demo',
        nome: 'Maria Silva',
        nascimento: DateTime(1958, 3, 14),
        telefone: '(86) 99999-0000',
        documento: '52998224725',
      );

  static const nomes = [
    'João Pereira', 'Ana Lima', 'Carlos Moura', 'Francisca Alves', 'José Santos',
    'Antônia Costa', 'Pedro Araújo', 'Luzia Rodrigues', 'Raimundo Nunes', 'Juliana Melo',
    'Francisco Ribeiro', 'Beatriz Carvalho', 'Paulo Batista', 'Tereza Gomes', 'Lucas Oliveira',
    'Sebastiana Freitas', 'Gabriel Teixeira', 'Rita Cardoso', 'Manoel Barros', 'Camila Duarte',
  ];

  static const queixas = [
    'Febre há 2 dias e dor no corpo',
    'Dor de garganta e tosse',
    'Dor abdominal leve',
    'Corte superficial na mão',
    'Dor lombar após esforço',
    'Pressão alta, sem outros sintomas',
    'Tontura ao levantar',
    'Dor de ouvido',
  ];

  static Paciente pacienteSimulado(Random r, int n) => Paciente(
        id: 'sim-$n',
        nome: nomes[r.nextInt(nomes.length)],
        nascimento: DateTime(1940 + r.nextInt(65), 1 + r.nextInt(12), 1 + r.nextInt(28)),
        telefone: '(86) 98888-${(1000 + n).toString().substring(0, 4)}',
        documento: (100000000000000 + n).toString(),
        simulado: true,
      );

  static CorRisco corSimulada(Random r) {
    final x = r.nextInt(100);
    if (x < 8) return CorRisco.laranja;
    if (x < 38) return CorRisco.amarelo;
    if (x < 88) return CorRisco.verde;
    return CorRisco.azul;
  }

  static SinaisVitais sinaisSimulados(Random r) => SinaisVitais(
        pressao: '${110 + r.nextInt(40)}/${70 + r.nextInt(20)}',
        frequenciaCardiaca: '${65 + r.nextInt(40)}',
        temperatura: '36,${r.nextInt(10)}',
        saturacao: '${94 + r.nextInt(6)}',
        dor: r.nextInt(8),
      );
}
