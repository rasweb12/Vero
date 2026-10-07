param(
  [string]$ConfigPath = "config/release.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Arquivo de configuracao ausente: $ConfigPath. Copie config/release.example.json."
}

$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$required = @(
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "REVENUECAT_ANDROID_API_KEY",
  "VERO_SUPPORT_EMAIL",
  "VERO_FEEDBACK_URL"
)
foreach ($key in $required) {
  $value = $config.$key
  if ([string]::IsNullOrWhiteSpace($value) -or $value -match "YOUR_|seu-dominio") {
    throw "Configure $key em $ConfigPath antes do build."
  }
}

if ($config.SUPABASE_ANON_KEY -match "service_role|sb_secret_") {
  throw "SUPABASE_ANON_KEY nao pode ser uma chave de servidor. Use a chave publica anon/publishable."
}

$supabaseUri = $null
if (-not [Uri]::TryCreate($config.SUPABASE_URL, [UriKind]::Absolute, [ref]$supabaseUri) -or
    $supabaseUri.Scheme -ne "https" -or
    [string]::IsNullOrWhiteSpace($supabaseUri.Host)) {
  throw "SUPABASE_URL deve ser uma URL HTTPS valida."
}

$feedbackUri = $null
if (-not [Uri]::TryCreate($config.VERO_FEEDBACK_URL, [UriKind]::Absolute, [ref]$feedbackUri) -or
    $feedbackUri.Scheme -notin @("http", "https")) {
  throw "VERO_FEEDBACK_URL deve ser uma URL HTTP ou HTTPS valida."
}

if (-not (Test-Path -LiteralPath "android/key.properties")) {
  throw "Assinatura ausente: configure android/key.properties antes do build de producao."
}

$keystoreProperties = Get-Content -Raw -LiteralPath "android/key.properties" |
  ConvertFrom-StringData
$storeFile = $keystoreProperties.storeFile
if ([string]::IsNullOrWhiteSpace($storeFile)) {
  throw "android/key.properties precisa informar storeFile."
}

$storeFilePath = if ([IO.Path]::IsPathRooted($storeFile)) {
  $storeFile
} else {
  Join-Path (Get-Location) $storeFile
}
if (-not (Test-Path -LiteralPath $storeFilePath -PathType Leaf)) {
  throw "Arquivo de assinatura nao encontrado: $storeFilePath"
}

& flutter build appbundle --release --dart-define-from-file=$ConfigPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "App Bundle gerado em build/app/outputs/bundle/release/app-release.aab"
