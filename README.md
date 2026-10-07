# Vero

Vero e um aplicativo Flutter para controle de treino, medidas corporais e evolucao fisica. A direcao do produto e simples: elegante, calmo, premium, sem anuncios e sem promessas irreais.

Frase-guia: **Seu ritmo. Seus resultados.**

## Stack

- Flutter 3.x e Dart 3.x com null-safety
- Riverpod 2.x para estado
- Isar para banco local offline-first
- `flutter_secure_storage` para segredos locais
- `shared_preferences` para preferencias leves, como tema
- Clean Architecture simplificada, com pasta por feature
- Supabase Auth e Postgres para conta e perfil
- GoRouter para rotas nomeadas e protecao de sessao

## Como Rodar

Instale Flutter 3.x com Dart >= 3.12.2, Android Studio e o Android SDK 36.
Execute `flutter doctor` e aceite as licencas com `flutter doctor --android-licenses`.
Os comandos abaixo usam o SDK instalado nesta maquina; em outra, use `flutter` no PATH.

```powershell
C:\develop\flutter\bin\flutter.bat pub get
C:\develop\flutter\bin\flutter.bat pub run build_runner build --delete-conflicting-outputs
C:\develop\flutter\bin\flutter.bat analyze
C:\develop\flutter\bin\flutter.bat test
C:\develop\flutter\bin\flutter.bat devices
C:\develop\flutter\bin\flutter.bat run -d emulator-5554 --dart-define-from-file=config/supabase.json
```

No Windows, builds com plugins podem exigir Developer Mode habilitado para suporte a symlinks.

Abra um emulador no Device Manager do Android Studio antes de executar. Substitua
`emulator-5554` pelo ID retornado por `flutter devices`.

### Instalar APK no emulador ou celular Android

```powershell
flutter build apk --debug --dart-define-from-file=config/supabase.json
flutter install --debug -d emulator-5554
```

O APK fica em `build/app/outputs/flutter-apk/app-debug.apk`. Tambem pode ser
arrastado para a janela do emulador. Para celular fisico, ative a depuracao USB,
conecte o cabo, autorize o computador e use o ID listado em `flutter devices`.
Este APK e de desenvolvimento, sem assinatura de distribuicao configurada.

### APK release para testes

```powershell
.\tool\build_test_release.ps1 -CreateSigningKey
```

O comando usa `config/supabase.json` e gera `build/app/outputs/flutter-apk/app-release.apk`.
`-CreateSigningKey` autoriza criar a primeira chave, mas nunca substitui uma chave
existente. Nos proximos builds, execute o comando sem essa opcao. Para reutilizar
as dependencias ja instaladas, adicione `-NoPub`.

Guarde uma copia privada de `android/key.properties` e
`android/app/vero-upload-keystore.jks`; ambos sao ignorados pelo Git. Essa
assinatura e diferente da assinatura debug: exporte seus dados antes de remover
a versao debug para instalar o release. O APK de testes nao comprova prontidao
para a loja e nao elimina a necessidade de configurar e-mails publicos e compras.
O build de publicacao continua usando `tool/build_release.ps1`.

O arquivo `config/supabase.json` precisa existir antes do build. No Windows,
`powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_debug.ps1`
valida esse arquivo e o inclui automaticamente no APK. Para executar diretamente,
adicione `-Run -DeviceId emulator-5554`. O perfil `Vero (Supabase)` do VS Code
tambem inclui a configuracao. O build Android recusa compilar sem os defines
de conta, evitando distribuir um APK com cadastro e login indisponiveis.

Android e o alvo validado nesta sprint. iOS exige macOS/Xcode e validacao propria;
web nao e suportada pela inicializacao segura atual.

## Estrutura

```text
lib/
+-- features/
|   +-- auth/
|   +-- home/
|   +-- training/
|   +-- measurements/
|   +-- progress/
|   +-- photos/
|   +-- subscription/
|   +-- profile/
+-- shared/
|   +-- constants/
|   +-- database/
|   +-- models/
|   +-- providers/
|   +-- theme/
|   +-- utils/
|   +-- widgets/
+-- main.dart
```

## Design System

Paleta inicial:

- Fundo claro: `#F8F9FA`
- Fundo escuro: `#121417`
- Primaria: `#0D9488`
- Secundaria: `#3B82F6`
- Texto forte: `#1F2937`
- Texto leve: `#6B7280`

A fonte Inter variavel esta embarcada em `assets/fonts/Inter.ttf`, com licenca
em `assets/fonts/OFL.txt`, e funciona offline. Origem: [Google Fonts](https://github.com/google/fonts/tree/main/ofl/inter).
`AppTheme` centraliza a hierarquia: titulos 34/28/20/16, corpo 16/14 e labels 14/12.

Componentes base:

- `VeroButton`
- `VeroCard`
- `VeroTextField`

## Tema

O tema claro/escuro usa `ThemeModeController` com Riverpod e persistencia em `SharedPreferences`.

Modos suportados:

- Sistema
- Claro
- Escuro

## Banco Local

`IsarDatabase.open()` inicializa uma instancia nomeada `vero` e expoe `LocalDatabase` por `localDatabaseProvider`.

Isar 3.1.0+1 nao oferece criptografia nativa do arquivo. Optamos por cifrar os
valores antes de grava-los, usando AES-256-GCM do pacote `cryptography`:

- `LocalDatabase.write/read` sao a porta de entrada e retornam `Result` (sucesso/falha).
- `RecordCipher` usa nonce novo em cada gravacao e autentica o identificador do registro.
- A chave aleatoria permanece em `flutter_secure_storage`; SHA-256 deriva os 32 bytes para AES.
- Identificadores, datas, tamanho e estrutura do banco NAO sao cifrados. Use IDs opacos;
  nunca coloque nome, e-mail ou informacoes de saude na chave do registro.
- Nao grave campos sensiveis diretamente em colecoes Isar nas proximas features.
- Chave invalida nao e substituida automaticamente; erros nao apagam registros.
- Inspector Isar e backup Android automatico estao desabilitados.

Esta e criptografia de valores, nao do arquivo inteiro. Backup de chaves entre
dispositivos e recuperacao de conta serao projetados na sprint de sincronizacao.
Nao existe migracao de valores antigos em texto puro; a fundacao anterior nao
gravava dados de usuario. Chave perdida torna os valores cifrados irrecuperaveis.

Referencia: [API AES-GCM](https://pub.dev/documentation/cryptography/latest/cryptography/AesGcm-class.html).

### Arquitetura

`main.dart` abre preferencias e banco antes de montar `ProviderScope`. Falhas de
inicializacao exibem uma tela recuperavel ao reabrir, sem expor detalhes internos.
Cada feature agrupa suas telas e, quando necessario, dominio e repositorios.
Widgets usam providers; persistencia fica em `shared/database`; componentes
reutilizaveis ficam em `shared/widgets`. O tema fica em `shared/theme`, evitando
duplicar configuracoes em `lib/theme`.

O ajuste em `android/build.gradle.kts` fornece namespace e compileSdk ao plugin
Isar antigo. Reavaliar esse ajuste ao atualizar ou substituir Isar.

## Qualidade

As regras de lint vivem em `analysis_options.yaml`. A intencao e manter codigo legivel para um time pequeno: retornos explicitos, imports ordenados, pouco estado mutavel e sem `print` em fluxo normal.

## Proximos Sprints

### Fechamento da Sprint 1 - 17/09/2026

- [x] Projeto Flutter/Dart e estrutura por feature.
- [x] Paleta, Inter local, hierarquia tipografica e componentes base.
- [x] Riverpod 2.x e tema claro/escuro/sistema persistente.
- [x] Inicializacao Isar e criptografia de valores AES-256-GCM (nao do arquivo inteiro).
- [x] Lints e documentacao de instalacao/arquitetura.
- [x] `flutter analyze --no-pub`: sem problemas.
- [x] `flutter test --no-pub`: 8 testes aprovados.
- [x] `flutter build apk --debug --no-pub`: APK gerado.

Os testes cobrem cifra/autenticacao, reabertura e atualizacao do banco real no
Windows, persistencia do tema e troca de tema em tela de 320px. O teste nativo
do Isar usa a DLL do plugin no cache e e ignorado fora do Windows. A instalacao
e a execucao deste APK atualizado em emulador/celular nao foram verificadas
neste fechamento. Validacao iOS e distribuicao nas lojas ficam para suas sprints.

## Sprints 2 a 4

Implementadas no codigo: autenticacao por e-mail/senha, confirmacao e recuperacao
por codigo, perfil com metas/preferencias, selecao local de planos, rotinas,
biblioteca de 18 exercicios, historico e treino ativo offline.

### Configurar Supabase

1. Crie um projeto Supabase e habilite o provedor Email com confirmacao de e-mail.
2. Execute `supabase/migrations/202609180001_profiles.sql` no SQL Editor do projeto.
   A tabela `profiles` tem RLS e permite somente ler/inserir/editar o proprio perfil.
3. Em Authentication > Email Templates, use os modelos de
   `supabase/templates/confirmation.html` e `supabase/templates/recovery.html`
   para Confirm signup e Reset password. Eles mostram `{{ .Token }}`.
4. Configure entrega de e-mail/SMTP e os destinatarios de teste no Supabase.
5. Configure `config/supabase.json` seguindo `config/supabase.example.json`, com
   a URL e chave publica publishable ou anon. Nunca use `service_role` no app.
   O arquivo local esta ignorado pelo Git. Chaves publicas estarao no APK por design;
   a protecao de dados depende de Auth e RLS, nao de esconder essa chave.
6. Execute ou compile com a configuracao:

```powershell
flutter run -d emulator-5554 --dart-define-from-file=config/supabase.json
flutter build apk --debug --dart-define-from-file=config/supabase.json
```

O build Android exige a configuracao de conta. O fluxo usa codigo digitado no
app, nao deep links; por isso os modelos de e-mail acima sao necessarios.
Referencias: [templates de e-mail](https://supabase.com/docs/guides/auth/auth-email-templates)
e [verificacao OTP](https://supabase.com/docs/reference/dart/auth-verifyotp).

Se um APK antigo mostrar "Nao foi possivel conectar ao servico de conta",
ele pode ter sido compilado sem os defines do Supabase. Incluir o arquivo no
repositorio local nao altera um APK ja instalado: gere e instale um novo APK.
Em uma instalacao nova do projeto, preencha o arquivo local seguindo o exemplo:

```powershell
Copy-Item config/supabase.example.json config/supabase.json
notepad config/supabase.json
flutter run -d emulator-5554 --dart-define-from-file=config/supabase.json
```

Nunca use `service_role` no JSON. A configuracao fica no build; o usuario final
nao precisa informar a URL ou a chave do projeto.

Se Auth retornar `Error sending confirmation email`, o servidor falhou ao enviar
a mensagem. Confira o erro detalhado em Supabase > Logs > Auth e no painel de
envios do Resend. O app traduz esse caso como falha de envio, inclusive quando
GoTrue entrega o JSON de um HTTP 500 dentro de uma excecao sem `code`.
Configurar o SMTP e o dominio remetente acontece no Supabase/Resend; o APK nao
contem credenciais de SMTP. Veja o [guia oficial do Resend](https://resend.com/docs/send-with-supabase-smtp).

### Conta e perfil

- `features/auth`: contrato de autenticacao, adaptador Supabase, controller e telas.
- A sessao e persistida em `flutter_secure_storage`, isolada por projeto Supabase.
- Logout usa escopo local: sai deste aparelho e conserva os dados locais cifrados.
- `Usuario` e serializado dentro do Isar pela camada `LocalDatabase`; os campos
  pessoais nao viram colunas Isar em texto puro. No Supabase fica em `profiles`.
- O e-mail exibido vem de Auth e nao pode ser alterado pelo formulario de perfil.
- Perfil ja carregado funciona offline. Salvar grava primeiro no aparelho; se o
  envio falhar, exibe pendencia e permite reenviar ao salvar novamente conectado.
- A sincronizacao e o backup Premium ficam descritos em `features/sync`.
- Free/Mensal/Anual continuam visiveis no paywall, mas somente entitlements
  verificados pelo RevenueCat liberam recursos Premium.
- A preferencia de lembretes ainda nao agenda notificacoes (Sprint 12).

### Treinos offline

Execucao visual, POC de cinco exercicios, formatos de midia, cache, cadastro de
conteudo e deploy do catalogo: [guia da biblioteca](docs/exercise_library.md).
Use Ver execucao na ficha ou durante o treino. As animacoes definitivas ainda
estao em preparacao; instrucoes e seguranca ja funcionam offline.

- A biblioteca inclui Peck deck (tambem encontrado como Pec deck ou voador),
  crucifixos, crossover, remadas, variacoes de agachamento e outros exercicios.
  A busca reconhece nomes alternativos e texto com ou sem acentos.
- Em Treinos > Biblioteca, o botao `+` abre o cadastro de exercicio personalizado
  com nome, grupo muscular e equipamento. No editor, Adicionar exercicio > `+`
  permite criar e incluir o novo exercicio diretamente na rotina.
- Os personalizados funcionam offline, ficam cifrados com os treinos e sao
  separados por conta. Nao exigem Premium. Tambem seguem no backup e na exportacao
  dos dados de treino. Nomes duplicados no mesmo grupo/equipamento sao recusados.
- O formato local de treinos agora usa a versao 2; dados anteriores da versao 1
  continuam legiveis. Aplicativos antigos nao leem esse formato, portanto nao
  instale uma versao anterior depois de salvar treinos na versao nova.
- `Treino`: ID, nome, exercicios e segundos de repouso.
- `Exercicio`: ID estavel, nome, grupo muscular e tipo/equipamento.
- `Serie`: repeticoes, carga em kg e conclusao.
- `TrainingSession`: copia da rotina, inicio, fim, series realizadas e prazo de repouso.
- Cada conta tem rotinas, historico e treino ativo cifrados no Isar. A fila local
  serializa alteracoes; a interface so confirma quando a gravacao termina.
- Editar/excluir uma rotina nao altera sessoes ja iniciadas nem historico.
- As rotinas se alternam na sugestao de proximo treino. Constancia semanal conta
  dias locais distintos com pelo menos uma serie concluida, de segunda a domingo.
- Comparacao usa o mesmo exercicio e numero de serie no ultimo treino concluido.
- Repouso usa prazo persistido e continua correto ao retornar ao app. A vibracao
  usa o retorno tatil do sistema enquanto a tela esta aberta; nao ha alarme em
  segundo plano nem garantia de vibracao com o processo encerrado.
- Login inicial, cadastro e recuperacao precisam de internet. Depois de entrar,
  criar/editar rotinas, treinar, retomar e consultar historico nao acessam a rede.

Rotas: `/home`, `/training`, `/training/new`, `/training/edit/:id`,
`/training/active`, `/training/history/:id`, `/exercises`, `/profile`, `/plans`
e as rotas publicas `/login`, `/register`, `/confirm`, `/recovery`.

### Validacao e limites

Os testes usam adaptadores de autenticacao simulados, armazenamento seguro
simulado e banco Isar real no teste nativo Windows. Ha testes de formulario,
recuperacao, logout, isolamento de conta, falha de gravacao, retomada do treino,
cronometro, historico e layouts estreitos. Os testes visuais usam Inter local.

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Configuracao remota, entrega real de e-mails, politicas RLS no projeto hospedado,
vibracao em aparelho fisico e builds iOS ainda exigem validacao no ambiente final.
O historico ainda e carregado como um documento por conta; paginacao e reducao
de regravacoes estao previstas para a Sprint 14. As Sprints 14 a 16 permanecem
no roadmap.

## Sprints 5 a 7

### Medidas e peso

`features/measurements` inclui `RegistroMedida` (peso, circunferencias, data e
notas), registro rapido, selecao de metricas, valores atuais, variacao em relacao
ao registro anterior e exclusao com confirmacao. Os registros ficam cifrados
no Isar e separados por conta. Datas retroativas sao ordenadas cronologicamente.

O Free pode selecionar e registrar ate cinco tipos de medida. Premium permite
todas as metricas cadastradas. Ao voltar para Free, o app nao apaga registros:
as cinco primeiras metricas selecionadas ficam ativas e podem ser personalizadas.
A validacao acontece no controller, inclusive para chamadas fora do formulario.

A meta de peso e a mesma do Perfil; o atalho em Medidas abre sua edicao.
A projecao inicial usa somente registros do usuario: exige ao menos quatro dias
registrados ao longo de 14 dias, compara medias moveis e nao estima uma data se
a tendencia for quase nula, contraria a meta ou implicar mais de dois anos.
Ela e uma extrapolacao da tendencia, nao uma promessa nem recomendacao de saude.

### Graficos

`features/progress` usa `fl_chart`: peso, media movel, linha de meta, medidas
individuais e percentual semanal de dias treinados. Registros no mesmo dia sao
agregados pela media; a media movel usa ate sete dias com registro (nao preenche
dias sem dados). Constancia conta dias distintos e divide por sete; a semana
atual e identificada como em andamento.

Os periodos dos graficos sao limitados a tres meses de calendario no Free.
Premium oferece 3/6/12 meses ou todo o historico. A restricao e aplicada antes
de montar os pontos. Nao se apagam registros antigos. Ha animacao de baixo para
cima e respeito a preferencia do sistema de reduzir animacoes.

### Fotos privadas

`features/photos` inclui camera/galeria via `image_picker`, organizacao por data,
selecao de duas fotos para comparar lado a lado, zoom e exclusao com confirmacao.
O Free pode manter cinco fotos; Premium nao tem limite definido pelo app.
Importacoes sao serializadas para impedir que toques simultaneos ultrapassem
o limite. Um downgrade nao apaga fotos; bloqueia novas inclusoes acima do limite.

As copias do app ficam em `ApplicationSupport/photos/<hash-da-conta>`.
Conteudo e nomes dos arquivos sao cifrados com AES-256-GCM; o catalogo tambem
fica cifrado no Isar. O nome original nao e salvo. As imagens sao limitadas a
1600 px no maior lado e recodificadas como PNG sem EXIF/localizacao. O limite
de entrada e 20 MB. Apenas a copia do seletor dentro do cache do app e removida
apos a importacao; originais da galeria nao sao apagados.

No Android, o seletor do sistema solicita o acesso necessario; nao adicionamos
permissao ampla de armazenamento. No iOS, `Info.plist` contem as descricoes de
camera e biblioteca. Negacao de permissao, cancelamento e falhas de leitura
possuem tratamento. A recuperacao de selecao interrompida no Android preserva
a data escolhida e verifica a conta que iniciou a operacao.

Nas Sprints 5 a 7, fotos nao eram enviadas a servidores. Se houver falha ao
limpar um arquivo apos exclusao, o app informa a pendencia; o arquivo restante
continua cifrado. O backup Premium das fotos foi adicionado na Sprint 8.

Dependencias adicionadas: `fl_chart` e `image_picker`. Referencias oficiais:
[fl_chart](https://pub.dev/packages/fl_chart) e
[image_picker](https://pub.dev/packages/image_picker).

### Validacao

Testes cobrem limites por plano, isolamento entre contas, datas e valores invalidos,
persistencia offline, projecao, filtros de periodo, autenticacao da cifra,
arquivos adulterados, limpeza apos falha de gravacao, importacoes concorrentes,
registro com virgula decimal e comparacao/exclusao de fotos. Capturas de interface
em `test/goldens` incluem medidas e graficos em telas estreitas.

Camera, permissoes e encerramento de processo pelo Android ainda precisam ser
validados em dispositivo real. Testes de interface usam fotos sinteticas de teste,
sem dados pessoais. A configuracao Supabase continua necessaria para login real;
o APK sem `--dart-define-from-file` nao inclui uma conta de demonstracao.

## Sprints 8 e 9

### Sincronizacao e nuvem

`features/sync` mantem uma fila cifrada por conta no Isar. Ao tocar em
"Sincronizar agora", o Vero compara hashes locais, envia os documentos para a
tabela `sync_records` e envia as copias cifradas das fotos para o bucket privado
`vero-private`. Sem conexao, os dados continuam disponiveis no aparelho e a fila
fica pendente para a proxima tentativa.

Conflitos usam a data da alteracao: a copia local e a remota sao comparadas com
o ultimo estado sincronizado e a versao mais recente vence. Fotos sao enviadas
como bytes AES-256-GCM ja cifrados; o Storage nunca recebe a imagem em claro.
Cada conta tem uma chave de sincronizacao aleatoria em `sync_keys`, protegida
por RLS; o aparelho reempacota o arquivo com sua chave local ao baixar. As
politicas RLS limitam registros e objetos ao `auth.uid()` da propria conta.
Execute `supabase/migrations/202609300001_sync_and_storage.sql` depois da
migracao de perfis. O backup em nuvem exige Premium validado.

### Assinaturas

O paywall usa `in_app_purchase` para consultar a disponibilidade e os precos da
loja e `purchases_flutter` para compra, restauracao e validacao server-side pelo
RevenueCat. Os produtos esperados sao `premium_mensal` e `premium_anual`, com o
entitlement `premium`. O cancelamento/renovacao abre a URL de gerenciamento
retornada pela loja.

Configure as chaves publicas por plataforma ao executar ou compilar:

```powershell
flutter run -d emulator-5554 `
  --dart-define=REVENUECAT_ANDROID_API_KEY=public_android_key
flutter build apk --debug `
  --dart-define=REVENUECAT_ANDROID_API_KEY=public_android_key
```

O APK sem essa chave continua no Free. A selecao local do paywall nao libera
Premium; isso evita conceder recursos pagos sem uma resposta valida do
RevenueCat. Antes da publicacao, cadastre os produtos e o entitlement no
RevenueCat, associe Google Play/App Store e teste renovacao, cancelamento,
restauracao e perda de conexao em sandbox.

Dependencias adicionadas: `in_app_purchase`, `purchases_flutter` e
`url_launcher`. A tela de sincronizacao e assinaturas foi validada por analise
estatica e pelo teste focado de planos; testes de compra reais dependem das
lojas e das chaves de sandbox.

## Sprints 10 e 11

### Assistente de progresso

`features/progress/domain/progress_assistant.dart` concentra os calculos do
assistente sem tabelas genericas: a Pontuacao de Constancia usa dias distintos
treinados, periodo e meta semanal do proprio usuario. A deteccao de estagnacao
compara os quatro treinos concluidos mais recentes com os quatro anteriores e
so sinaliza depois de pelo menos 14 dias sem evolucao, usando uma margem
conservadora de 2%.

A tela de progresso mostra a pontuacao, marcos de treino, uma mensagem de
celebracao e uma sugestao curta. As sugestoes sao apresentadas de forma suave,
sem notificacoes insistentes. A projecao de meta continua usando somente os
registros do usuario, conforme a regra da Sprint 5.

### Relatorios e compartilhamento

Usuarios Premium podem abrir `/reports` pela tela de Progresso. O relatorio
mensal resume frequencia, volume de treino, peso, meta e variacao das medidas.
Ele pode ser exportado como PDF com `pdf` e compartilhado pelo sistema com
`printing`. Tambem e possivel gerar uma imagem de progresso em PNG e
compartilha-la com `share_plus`. O Free ve o bloqueio do recurso e um atalho
para o paywall.

Dependencias adicionadas: `pdf`, `printing` e `share_plus`. Os testes focados
das Sprints 10 e 11 verificam os algoritmos e a geracao dos bytes do PDF. O
compartilhamento real precisa ser conferido em emulador ou aparelho, e a
assinatura Premium depende das credenciais Supabase/RevenueCat configuradas.

## Sprints 12 e 13

### Lembretes

`features/notifications` agenda localmente um lembrete diario no horario
escolhido pelo usuario. O Vero tambem agenda um aviso unico depois de sete dias
sem treino, com texto suave e sem chamadas para bater metas. Ao concluir um
treino, o aviso de inatividade e recalculado. Desligar a chave cancela os dois
agendamentos.

No Android, a permissao de notificacoes e solicitada no primeiro uso e os
agendamentos sao restaurados apos reiniciar o aparelho. O horario usa o fuso
local do dispositivo. No iOS, a permissao e solicitada pelo mesmo fluxo. O
Supabase nao e necessario para os lembretes.

### Privacidade e seguranca

`/settings`, acessivel pelo Perfil, reune lembretes, bloqueio de tela,
exportacao e exclusao. A exportacao gera um JSON com perfil, treinos, medidas,
preferencias e fotos descriptografadas somente no arquivo que o usuario escolhe
compartilhar. As chaves de criptografia nunca entram na exportacao.

Apagar meus dados remove os registros locais, fotos privadas, fila de
sincronizacao, perfil, backups e objetos do Storage. A migracao
`supabase/migrations/202609300002_privacy_delete.sql` precisa ser aplicada para
habilitar a exclusao dos dados remotos. A conta de autenticacao do Supabase nao
e removida pelo app; isso exige uma operacao administrativa no servidor.

O bloqueio de tela usa `local_auth`, com biometria e fallback para PIN, padrao
ou senha do aparelho. O estado fica somente no dispositivo. Android declara
`USE_BIOMETRIC` e iOS declara `NSFaceIDUsageDescription`.

Dependencias adicionadas: `flutter_local_notifications`, `flutter_timezone`,
`timezone` e `local_auth`. Referencias oficiais: [notificacoes locais](https://pub.dev/packages/flutter_local_notifications),
[fuso do aparelho](https://pub.dev/packages/flutter_timezone) e
[autenticacao local](https://pub.dev/packages/local_auth).

Os testes focados das Sprints 12 e 13 cobrem horario, preservacao do perfil e
persistencia da preferencia de bloqueio. Notificacoes, biometria e exclusao
remota ainda precisam de validacao em emulador/aparelho com permissoes reais e
Supabase configurado.

## Sprints 14 a 16

### Desempenho e QA

O historico de treinos usa paginas de 20 itens na interface e so materializa a
proxima pagina quando o usuario se aproxima do fim da lista. Fotos ja sao
redimensionadas antes da criptografia. Timers, listeners e providers de tela
sao descartados nos ciclos de vida normais.

Os testes focados cobrem paginacao, configuracao de autenticacao e preservacao
de dados. A validacao completa de offline, permissoes, compras, notificacoes e
compartilhamento deve ser repetida na faixa interna das lojas, em um aparelho
de entrada e em um aparelho intermediario.

### Preparacao de lancamento

`config/release.example.json` documenta os defines de producao: Supabase,
RevenueCat, contato de suporte e canal de feedback. O script
`tool/build_release.ps1` recusa o build quando faltam esses valores ou
`android/key.properties`. A assinatura real nunca fica no repositorio.

O checklist de loja esta em `docs/release/sprint-16-checklist.md`. Crashlytics
continua opcional e deve ser ativado somente depois de cadastrar o projeto
Firebase e revisar os textos de privacidade. Capturas, video, produtos da loja,
chave de assinatura e contato real sao configuracoes externas que ainda
precisam ser fornecidas pelo produto.
