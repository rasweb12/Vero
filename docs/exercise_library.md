# Biblioteca e execucao de exercicios

## Estado da POC

Cinco exercicios possuem metadados educativos completos: `incline-dumbbell`,
`squat`, `leg-press`, `lat-pulldown` e `biceps-curl`. Os IDs antigos foram mantidos.
O catalogo ampliado e o cadastro de exercicios personalizados continuam disponiveis.
As animacoes definitivas ainda nao foram fornecidas/revisadas: a POC usa o estado
**Animacao em preparacao**, sem representar uma animacao generica como tecnica correta.

O player implementa Rive, Lottie, WebP animado e MP4. Ele nao conta repeticoes e
nao altera o cronometro de repouso. A midia deve mostrar um ciclo completo,
com inicio/fim compativeis, e ser revisada por profissional antes de publicar.

## Arquitetura e arquivos

- `domain/training_models.dart`: Exercicio expandido, Serie e ExercicioTreino reutilizados.
- `domain/exercise_media.dart`: tipo, fonte, thumbnail, duracao, loop, versao e timeline Rive.
- `domain/exercise_library.dart`: catalogo base, busca sem acentos e filtros combinados.
- `data/exercise_repository.dart`: metadados embarcados + snapshot criptografado no LocalDatabase.
- `data/exercise_media_cache.dart`: download HTTPS sob demanda, arquivos locais e limite de disco.
- `presentation/exercise_providers.dart`: composicao Riverpod, Supabase e cache.
- `presentation/exercise_animation_player.dart`: loading/falha/placeholder, controles e ciclo de vida.
- `presentation/exercise_playback.dart`: adaptadores dos quatro formatos.
- `presentation/exercise_detail_page.dart`: conteudo educativo e prescricao real da ficha.
- `presentation/exercise_library_page.dart`: busca, filtros, cadastro personalizado e detalhe.
- Editor, lista de rotinas e treino ativo compartilham a mesma rota `exercise-detail`.

Os caminhos acima sao relativos a `lib/features/training/`. A rota nomeada esta
em `lib/shared/providers/router_provider.dart`. O tema Inter/teal existente foi preservado.
As fichas guardam IDs e series, nao nomes, musculos ou animacoes duplicados.
Notas e tecnica de intensidade sao opcionais em ExercicioTreino e preservadas ao editar series.
O detalhe mostra cada serie, pois as repeticoes/cargas podem variar entre elas.
No treino ativo, **Voltar ao treino** retorna ao treino existente, sem criar outra sessao.

## Offline e cache

Metadados locais carregam sem internet. O arquivo `assets/exercises/catalog.json`
enriquece os cinco IDs, sobre o catalogo base. A atualizacao remota e manual,
pela acao Atualizar biblioteca, e nao bloqueia a abertura do app.
O snapshot remoto fica em `exercise-catalog:v1`, criptografado pelo LocalDatabase.
Falhas de rede ou snapshot invalido preservam o ultimo cache; cache ilegivel
nao e apagado automaticamente e permite usar os metadados embarcados.

Midias remotas sao baixadas apenas ao abrir um detalhe, sem depender do plano.
O cache usa o diretorio de cache privado do app: ate 24 MiB por arquivo e 128 MiB
no total, com descarte dos arquivos menos recentemente usados. URL + tipo + versao
formam o identificador SHA-256, sem depender de nomes de exercicios. Downloads
parciais nao sao publicados. Redirecionamentos HTTP nao sao aceitos.
O sistema operacional pode limpar esse cache; por isso ele nao e um download
permanente de favoritos. Midia em cache funciona offline enquanto o arquivo existir.
Arquivos educativos nao contem dados pessoais; fotos privadas continuam no fluxo
criptografado anterior e nunca devem ir ao bucket educativo.

Reproducao pausa ao cobrir/sair da rota, rolar o player para fora da area visivel,
entrar em background ou desabilitar o ticker. Preferencia de movimento reduzido
impede autoplay; reproducao pode ser iniciada pelo controle. Recursos nativos,
timers, frames e controllers sao liberados ao desmontar o componente.

## Adicionar um exercicio

Para um exercicio pessoal, use Treinos > Biblioteca > Criar exercicio e informe
nome, grupo e equipamento. O cadastro funciona offline e pertence a conta atual.
Na selecao da ficha, criar um exercicio ja o adiciona ao editor.

Para conteudo educativo oficial, acrescente um objeto a `assets/exercises/catalog.json`
ou publique-o em `public.exercises`. Use um ID estavel como `incline-machine-press`;
nao troque IDs existentes nem use o prefixo reservado `custom-`.
Obrigatorios: `id`, `name`, `muscle_group`, `type`. Demais campos possuem defaults.
`difficulty`: beginner/intermediate/advanced/unspecified.
`instructions`, `common_errors`, `safety_tips`, `secondary_muscles`, `equipment`
e `alternatives` sao arrays. Alternativas referenciam IDs existentes, nao nomes.
`media` pode ser null. Conteudo novo aparece sem alterar a tela.

## Adicionar uma animacao

Exemplo de metadados (substitua a URL pelo arquivo real publicado):

```json
{
  "type": "rive",
  "url": "https://SEU-PROJETO.supabase.co/storage/v1/object/public/exercise-media/incline-dumbbell/v1/execution.riv",
  "local_asset": null,
  "thumbnail_url": null,
  "duration_ms": 6000,
  "loop": true,
  "version": 1,
  "animation_name": "execution"
}
```

Para embarcar offline, use `local_asset: assets/exercises/ARQUIVO.riv` e URL null.
O diretorio ja esta declarado no pubspec. O asset tem prioridade sobre a URL.
Para atualizar o remoto, incremente version e preferencialmente publique em `/v2/`;
isso invalida a chave anterior sem baixar toda a biblioteca.

- Rive: exporte timeline `execution` (ou informe animation_name), com assets embutidos.
  Use uma timeline, nao uma state machine interativa. O player controla tempo e loop.
- Lottie: JSON autonomo somente com shapes; imagens/fonts externos sao rejeitados
  para nao comprometer offline. Play/pause/restart e velocidade sao suportados.
- WebP: arquivo animado autonomo; play/pause/restart, sem controle de velocidade.
- MP4: codec compativel com Android/iOS (por exemplo H.264), sem audio necessario.
  O player silencia o video e oferece loop, pausa, reinicio e velocidade.
- Velocidades 0.5x/1x/1.5x aparecem apenas nos adaptadores que as suportam.

`thumbnail_url` e preservada para expansao do catalogo; sem thumbnail a lista usa
o icone padrao. Nao ha pre-download de animacoes em cards.

## Supabase

Migration preparada: `supabase/migrations/20261007142216_exercise_catalog.sql`.
Esta entrega nao aplica alteracoes automaticamente no projeto remoto.
Ela cria uma tabela `exercises`, com JSONB para listas e metadados de midia.
Optei por uma tabela porque esses campos sao consultados juntos e viram um unico
snapshot offline. Nao ha seis joins nem binarios no banco. Os IDs de alternativas
sao validados pelo catalogo/testes, sem foreign keys dentro de JSONB.

RLS + GRANT permitem somente leitura dos exercicios ativos a authenticated.
O app nao possui permissao de inserir/editar o catalogo oficial. Edicao e upload
sao feitos por administradores no dashboard ou backend confiavel, nunca com
service_role embutida no app. O bucket publico `exercise-media` contem somente
material educativo; organizar por `{exerciseId}/v{version}/execution.ext`.
O bucket `vero-private`, suas politicas e Auth/Resend nao foram alterados.

Depois de revisar/aplicar a migration no ambiente desejado:

```powershell
dart run tool/export_exercise_seed.dart
# Execute o SQL gerado em supabase/seeds/exercises.sql no SQL Editor.
```

O seed usa a mesma fonte JSON do app e nao sobrescreve IDs existentes no servidor.
Para alteracoes posteriores, atualize updated_at junto com o conteudo no dashboard.
Teste com usuario comum: SELECT ativo funciona; INSERT/UPDATE/DELETE falham.
Confirme que upload com chave publica falha e que o arquivo educativo publicado
abre por URL publica. Esta verificacao remota precisa ser feita apos o deploy.

## Associar a ficha e testar

1. Abra Treinos > Criar/Editar treino > Adicionar exercicio.
2. Busque pelo nome/alias, selecione o exercicio e ajuste suas series/repeticoes/cargas.
3. Salve a ficha. Toque no exercicio ou em Ver execucao no editor/treino ativo.
4. Confira o detalhe e as alternativas. Voltar nao modifica nem descarta a ficha.
5. Com midia real cadastrada, abra online uma vez; reabra em modo aviao.
6. Pause, reinicie, altere velocidade quando disponivel; role para fora do player
   e coloque o app em background para conferir a pausa.

```powershell
flutter pub get
flutter analyze
flutter test
```

Testes nao usam Supabase ou internet reais. Fontes de metadados e downloader sao
injetaveis. Os testes cobrem compatibilidade, cache, filtros, alternativas,
prescricao, placeholders, falhas, controles e lifecycle. Reproducao nativa com
assets definitivos ainda deve ser validada em Android e iOS antes de publicar.

Referencias consultadas para o conteudo, sem reutilizar fotos/videos ou copiar textos:
- NASM: https://www.nasm.org/resource-center/exercise-library/two-arm-incline-dumbbell-chest-press
- NASM: https://www.nasm.org/resource-center/exercise-library/barbell-bicep-curl
- Mayo Clinic: https://www.mayoclinic.org/healthy-lifestyle/fitness/multimedia/leg-press/vid-20084684
- Mayo Clinic: https://www.mayoclinic.org/healthy-lifestyle/fitness/multimedia/lat-pull-down/vid-20084683
- ACE: https://www.acefitness.org/resources/everyone/exercise-library/11/back-squat/
