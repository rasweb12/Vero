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

if (-not (Test-Path -LiteralPath "android/key.properties")) {
  throw "Assinatura ausente: configure android/key.properties antes do build de producao."
}

& flutter build appbundle --release --dart-define-from-file=$ConfigPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "App Bundle gerado em build/app/outputs/bundle/release/app-release.aab"
