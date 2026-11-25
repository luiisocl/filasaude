# FilaSaúde

App Flutter de fila virtual e triagem para UPA e postos de saúde. Segue o Documento de Requisitos (DRS) do grupo e foi feito para o trabalho final de **Código de Alta Performance Mobile**.

**Equipe:** Luis Guilherme Leal, Leonardo Santana, Zion Falcão Leal

## Como rodar

Requisito: Flutter **3.29 ou mais novo** (`flutter --version`).

```bash
# 1. Na pasta do projeto, gere as pastas android/ e ios/ (não mexe no lib/)
flutter create . --project-name filasaude --platforms android,ios

# 2. Baixe as dependências
flutter pub get

# 3. Rode no celular ou emulador
flutter run

# Para medir performance de verdade, use o modo profile (em aparelho físico):
flutter run --profile

# Testes das regras de negócio
flutter test
```

Não há back-end: os dados ficam no próprio aparelho (Hive) e uma simulação faz outros pacientes chegarem e serem atendidos a cada 15 segundos.

## Contas de teste

| Perfil | Login | Senha |
| --- | --- | --- |
| Paciente | CPF **529.982.247-25** (Maria Silva) + qualquer código de 4 dígitos | — |
| Recepção | recepcao@filasaude.com | 123456 |
| Enfermeiro(a) | enfermeiro@filasaude.com | 123456 |
| Médico(a) | medico@filasaude.com | 123456 |
| Coordenador(a) | coordenador@filasaude.com | 123456 |

Na tela de login da equipe, tocar numa conta de teste já preenche o e-mail e a senha.

## Roteiro de demonstração (caminho feliz)

1. **Paciente** entra com o CPF e retira a senha (Urgência, UPA Centro). Toca em "Acompanhar fila" e depois sai pelo Perfil.
2. **Recepção** vê a senha em "Chegadas", confirma a chegada e marca a prioridade "Idoso 60+". Depois sai.
3. **Enfermeiro** abre a paciente em "Triagem", preenche a queixa e os sinais vitais, escolhe **Amarelo** e salva. Na aba "Na fila", ela já aparece na posição certa.
4. **Médico** toca em "Chamar próximo" até chamar a Maria, depois em "Paciente chegou" e em "Encerrar atendimento" com o desfecho Alta.
5. **Paciente** entra de novo: a tela inicial pede a avaliação, e o atendimento aparece no Histórico.
6. **Coordenador** vê o Painel, gera o Relatório (calculado num Isolate), abre a lista de 200 mil atendimentos e o Painel de chamada (TV).

O aviso "Você foi chamado" aparece em tela cheia se o paciente estiver logado quando o médico chama. Dá para testar com dois aparelhos ou emuladores.

## Arquitetura (MVVM em camadas)

```
lib/
├── main.dart                  primeiro frame imediato (splash), cronômetro de cold start
├── app.dart                   inicialização assíncrona + escolha da área pelo perfil
├── core/                      tema, formatação, injeção de dependências (AppScope/VmScope), performance
├── domain/                    entidades e regras de negócio puras (RN01–RN12), sem Flutter
├── data/
│   ├── fila_repository.dart   estado da fila, persistência, simulação, outbox
│   ├── local_cache.dart       Hive (cache offline)
│   ├── historico.dart         200 mil registros em arrays tipados + cálculos para Isolate
│   ├── sync.dart              lote JSON comprimido com GZIP (roda em Isolate)
│   └── seed.dart              dados de demonstração
└── presentation/
    ├── viewmodels/            um ViewModel por área (paciente, recepção, enfermagem, médico, coordenação)
    ├── screens/               telas por perfil + Laboratório de performance
    └── widgets/               componentes reutilizáveis
```

- A **View** só desenha e repassa ações.
- O **ViewModel** expõe o estado já pronto para a tela e é descartado ao sair da área (`VmScope` chama `dispose`).
- O **Repositório** é a única fonte de verdade.
- Trabalho pesado (gerar histórico, relatório, compressão) vai para outro **Isolate** com `compute()`.

## Requisitos do DRS atendidos

| Requisito | Onde |
| --- | --- |
| RF01–RF03 Cadastro, login por CPF/Cartão SUS + SMS | Boas-vindas, Login, Cadastro |
| RF02/RF03 Senha pelo app e senha presencial | Paciente › Senha · Recepção › Nova senha |
| RF04/RF05 Confirmar chegada e prioridade legal | Recepção › Chegadas |
| RF06/RF07 Classificação e reclassificação de risco | Enfermagem › Triagem / Na fila |
| RF08 Fila ordenada por cor, prioridade e chegada | `FilaRules.comparar` |
| RF09/RF11 Posição, tempo estimado e avisos | Paciente › Acompanhar fila |
| RF10/RF12/RF13 Chamar, rechamar, ausência, encerrar | Médico |
| RF14 Desistir | Acompanhar fila |
| RF15/RF16 Painel e relatórios | Coordenação › Painel / Relatórios |
| RF17 Funcionários e unidade | Coordenação › Equipe / Unidade |
| RF18 Avaliação | Paciente › tela inicial e Histórico |
| RN01–RN12 | `domain/fila_rules.dart` e `data/fila_repository.dart` |
| EX01–EX17 (principais) | Mensagens e estados vazios em cada tela; modo offline no Laboratório |

## Técnicas de performance

Todas podem ser ligadas e desligadas no **Laboratório de performance** (botão na tela de boas-vindas ou menu ⋮ da equipe), para comparar "antes x depois". Veja `ROTEIRO_APRESENTACAO.md`.
