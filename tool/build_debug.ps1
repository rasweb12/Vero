param(
  [string]$ConfigPath = "config/supabase.json",
  [string]$FlutterCommand = "flutter",
  [string]$DeviceId,
  [switch]$Run,
  [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$configurationPath = if ([IO.Path]::IsPathRooted($ConfigPath)) {
  $ConfigPath
} else {
  Join-Path $projectRoot $ConfigPath
}

if (-not (Test-Path -LiteralPath $configurationPath -PathType Leaf)) {
  throw "Configuracao ausente. Preencha config/supabase.json antes de gerar ou executar o app."
}

$configuration = Get-Content -Raw -LiteralPath $configurationPath | ConvertFrom-Json
$url = [string]$configuration.SUPABASE_URL
$key = [string]$configuration.SUPABASE_ANON_KEY
$supabaseUri = $null
if (-not [Uri]::TryCreate($url, [UriKind]::Absolute, [ref]$supabaseUri) -or
    $supabaseUri.Scheme -ne "https" -or
    [string]::IsNullOrWhiteSpace($supabaseUri.Host) -or
    $url -match "YOUR_PROJECT" -or
    $key.Length -lt 20 -or
    $key -match "YOUR_PUBLIC|service_role|^sb_secret_") {
  throw "Configuracao de conta invalida. Use a URL HTTPS e a chave publica anon/publishable do Supabase."
}

if ($CheckOnly) {
  Write-Host "Configuracao de conta validada."
  return
}

$flutterArguments = if ($Run) { @("run") } else { @("build", "apk") }
$flutterArguments += @("--debug", "--dart-define-from-file=$configurationPath")
if ($Run -and -not [string]::IsNullOrWhiteSpace($DeviceId)) {
  $flutterArguments += @("-d", $DeviceId)
}

Push-Location -LiteralPath $projectRoot
try {
  & $FlutterCommand --suppress-analytics @flutterArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter falhou com codigo $LASTEXITCODE."
  }
  if (-not $Run) {
    Write-Host "APK configurado: build/app/outputs/flutter-apk/app-debug.apk"
  }
} finally {
  Pop-Location
}
