# Roteiro da apresentação – FilaSaúde

Trabalho final de Código de Alta Performance Mobile, com 10 minutos no total. Os campos **[ ]** são números que vocês medem no próprio celular: não inventem valores.

---

## 1. Introdução e contexto (1 min)

- **App:** FilaSaúde. **Equipe:** Luis Guilherme Leal, Leonardo Santana, Zion Falcão Leal.
- **Problema:** na UPA o paciente espera horas na recepção sem saber quanto falta, e a fila é controlada no papel. O app dá uma senha virtual, mostra a posição em tempo real e ordena o atendimento pela gravidade (Protocolo de Manchester).
- **Desafio de performance esperado:**
  1. **Listas grandes:** o coordenador consulta 200 mil atendimentos do ano.
  2. **Processamento pesado:** o relatório filtra, agrupa e **ordena** esses registros (percentil 90 da espera).
  3. **Falta de conexão:** a fila de uma UPA não pode parar se a internet cair.
  4. **Aparelhos simples:** muitos pacientes usam celulares de entrada.

## 2. Stack e arquitetura (1,5 min)

- **Flutter + Dart.** O código é compilado AOT para ARM nativo. O próprio motor desenha cada pixel e mira 60/120 FPS. Uma base de código atende Android e iOS. **Isolates** dão paralelismo real sem compartilhar memória.
- **Só 2 dependências** (`hive` e `hive_flutter`): menos código carregado no cold start e APK menor. Gráficos, máscaras e injeção de dependência foram feitos à mão.
- **MVVM em camadas** (mostrar a pasta `lib/`):
  - `domain/`: regras de negócio puras, sem Flutter. Por isso podem rodar dentro de um Isolate.
  - `data/`: repositório, cache Hive, cálculos pesados.
  - `presentation/`: ViewModels (`ChangeNotifier`) + telas.
- **Como isso evita travar a Main Thread:** a View só desenha. O cálculo pesado vai para `compute()` (outro Isolate) e volta pronto. O ViewModel avisa a tela, e só os widgets que dependem dele se reconstroem (`InheritedNotifier`).

## 3. Demonstração – caminho feliz (2 min)

Rodar em **modo profile** num **aparelho físico** (`flutter run --profile`) com o medidor de FPS ligado (Laboratório › "Mostrar medidor de FPS").

1. Abrir o app: a splash aparece na hora (primeiro frame antes de abrir o banco).
2. Paciente retira a senha → Recepção confirma → Enfermeiro classifica → Médico chama.
3. Destacar: transições suaves, medidor estável em ~60 FPS, nenhum engasgo ao rolar as listas.

## 4. Mergulho técnico (3,5 min) – escolham 2 ou 3

### A) Concorrência: Isolates (`compute`)
- Onde: `data/historico.dart` e `presentation/viewmodels/coordenador_viewmodel.dart › gerarRelatorio`. Também `data/sync.dart` (compressão).
- **Antes:** o relatório de 200 mil registros rodava na thread da UI, e a tela congelava durante o cálculo.
- **Depois:** `compute(calcularRelatorio, params)` roda em outro Isolate, e a UI continua a 60 FPS.
- **Demonstração ao vivo:** no Laboratório, rodar "Calcular relatório" nos dois modos. No modo antes, o indicador girando **congela**.

### B) Memória e CPU: arrays tipados + sem vazamentos
- **Antes:** cada atendimento era um `Map` (200 mil objetos no heap, que o coletor de lixo precisa percorrer).
- **Depois:** 5 arrays contíguos (`Int32List`, `Uint8List`, `Uint16List`) com **10 bytes por registro**, cerca de 2 MB no total (o Laboratório mostra o valor exato).
- **Sem memory leaks:**
  - Todo ViewModel para de escutar o repositório no `dispose` (`base_viewmodel.dart`).
  - Timers e `StreamSubscription` são cancelados (`Tique`, shells).
  - `TextEditingController` é liberado.
  - Pacientes simulados antigos são removidos da memória.
- **Menos rebuilds:**
  - Relógios e contagens regressivas ficam isolados em `RepaintBoundary` (só o número é redesenhado).
  - Widgets `const` e `IndexedStack` nas abas.

### C) Otimização de UI: listas
- Onde: `coordenador_shell.dart › AtendimentosListScreen`.
- **Antes:** `Column` dentro de `SingleChildScrollView` com 3.000 itens, todos montados de uma vez.
- **Depois:**
  - `ListView.builder` só monta os itens visíveis.
  - `itemExtent` fixo dispensa medir cada item.
  - **Paginação** de 50 em 50 com carregamento antes de chegar ao fim (lazy loading).

### D) Rede e dados offline
- **Cache Hive:** o app abre com o estado da última sessão e a pessoa já logada, sem rede.
- **Outbox:** toda ação vira uma operação guardada no Hive. Sem internet, ela fica na fila e é enviada quando a conexão volta (EX13).
- Envio em **lotes de 50**, em JSON **comprimido com GZIP** (dentro de um Isolate). O Laboratório mostra os bytes antes e depois da compressão.
- **Gravação com debounce:** várias mudanças seguidas viram uma única gravação no disco (antes, cada mudança gravava o estado inteiro).
- **Demonstração:** Laboratório › desligar "Conectado", fazer uma triagem, ver "N operações na fila", religar e ver o envio.

## 5. Métricas – antes x depois (1,5 min)

Como medir (sempre em `--profile` e no mesmo aparelho):

1. **Laboratório de performance:** tem a chave "Otimizações LIGADAS/DESLIGADAS". Rodem cada teste nos dois modos e tirem print da lista "Resultados desta sessão".
2. **Flutter DevTools › Performance:** gravar a rolagem da lista de atendimentos e o cálculo do relatório. Tirar print do gráfico de frames (barras vermelhas = jank).
3. **DevTools › Memory:** heap depois de "Gerar 200 mil registros" nos dois modos.
4. **Cold start:** `flutter run --profile --trace-startup` gera `build/start_up_info.json` (`timeToFirstFrameMicros`). Troquem o modo no Laboratório, fechem o app e meçam de novo.

| Métrica | Antes (otimizações off) | Depois (on) |
| --- | --- | --- |
| Cold start até o 1º frame | [ ] ms | [ ] ms |
| Gerar 200 mil registros | [ ] ms, [ ] frames com jank | [ ] ms, [ ] frames com jank |
| Relatório de 12 meses | [ ] ms, [ ] frames com jank | [ ] ms, [ ] frames com jank |
| Memória do histórico (DevTools) | [ ] MB | [ ] MB |
| FPS rolando a lista de atendimentos | [ ] FPS | [ ] FPS |
| Lote de 50 operações | [ ] KB em JSON | [ ] KB com GZIP |

> Frase modelo: "Antes, o relatório travava a tela por [ ] ms e gerava [ ] frames com jank. Depois, com o Isolate, a tela ficou em [ ] FPS durante todo o cálculo."

## 6. Lições aprendidas (30 s)

Sugestões de pontos verdadeiros deste projeto. Ajustem com o que vocês viveram:

- **Desafio técnico:** telas abertas por cima (`Navigator.push`) não "enxergavam" o ViewModel da área. Resolvemos com `VmScope.push`, que repassa o mesmo ViewModel sem criar outro.
- **Outro desafio:** timers e streams esquecidos seguem vivos depois que a tela fecha. Viramos regra: todo `listen` e `Timer.periodic` tem `cancel` no `dispose`.
- **Próximos passos:**
  - Back-end real com WebSocket no lugar da simulação.
  - Notificações push de verdade (Firebase).
  - Testes de performance automatizados (`integration_test` com `traceAction`).
  - Imagens/ícones com cache quando houver fotos de unidades.
