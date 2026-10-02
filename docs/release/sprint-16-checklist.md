# Vero - checklist de lancamento

## Antes do build

- Aplicar as migrations de perfil, sincronizacao e privacidade no Supabase.
- Configurar produtos e entitlement `premium` no RevenueCat.
- Criar `config/release.json` a partir de `config/release.example.json`.
- Configurar `android/key.properties` com uma chave de assinatura de producao.
- Definir `VERO_SUPPORT_EMAIL` e `VERO_FEEDBACK_URL` reais.
- Revisar politicas de privacidade, termos e textos da loja.
- Testar cadastro, login, recuperacao, treino, medida, foto, sync e exclusao.

## Build

```powershell
.\tool\build_release.ps1
```

O script exige configuracao Supabase, chaves publicas RevenueCat e assinatura
Android antes de gerar o App Bundle. Nunca coloque `service_role`, chave privada
ou senha de assinatura no JSON usado pelo app.

## Validacao final

- Instalar o `.aab` em uma faixa interna do Google Play.
- Testar notificacoes, biometria, compra sandbox e compartilhamento em aparelho.
- Conferir tamanho do APK/AAB, simbolos de erro e politica de backup.
- Preencher capturas, video, descricao, contato de suporte e canal de feedback.
- Ativar Crashlytics somente depois de cadastrar o projeto Firebase e revisar
  a politica de privacidade.
