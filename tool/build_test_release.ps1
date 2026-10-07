param(
  [string]$ConfigPath = "config/supabase.json",
  [string]$FlutterCommand = "flutter",
  [string]$KeytoolCommand = "keytool",
  [switch]$CreateSigningKey,
  [switch]$NoPub
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$configurationPath = if ([IO.Path]::IsPathRooted($ConfigPath)) {
  $ConfigPath
} else {
  Join-Path $projectRoot $ConfigPath
}

& (Join-Path $PSScriptRoot "build_debug.ps1") -ConfigPath $configurationPath -CheckOnly

$propertiesPath = Join-Path $projectRoot "android/key.properties"
$keystorePath = Join-Path $projectRoot "android/app/vero-upload-keystore.jks"

Push-Location -LiteralPath $projectRoot
try {
  if (-not (Test-Path -LiteralPath $propertiesPath)) {
    if (-not $CreateSigningKey) {
      throw "Assinatura ausente. Use -CreateSigningKey somente para criar a primeira chave."
    }
    if (Test-Path -LiteralPath $keystorePath) {
      throw "Uma chave ja existe sem key.properties. Restaure suas credenciais; ela nao sera substituida."
    }
    foreach ($privateFile in @("android/key.properties", "android/app/vero-upload-keystore.jks")) {
      & git check-ignore --quiet -- $privateFile
      if ($LASTEXITCODE -ne 0) {
        throw "Arquivo de assinatura precisa estar ignorado pelo Git: $privateFile"
      }
    }
    $null = Get-Command $KeytoolCommand -ErrorAction Stop

    # Generated credentials stay in the ignored signing file, never in Dart defines.
    $passwordBytes = New-Object byte[] 32
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
      $random.GetBytes($passwordBytes)
    } finally {
      $random.Dispose()
    }
    $password = [Convert]::ToBase64String($passwordBytes)
    $storeFile = $keystorePath.Replace('\', '/')
    $propertiesText = @(
      "storePassword=$password",
      "keyPassword=$password",
      "keyAlias=upload",
      "storeFile=$storeFile"
    ) -join "`n"
    $propertyBytes = (New-Object Text.UTF8Encoding($false)).GetBytes($propertiesText + "`n")
    $stream = [IO.File]::Open($propertiesPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try {
      $stream.Write($propertyBytes, 0, $propertyBytes.Length)
    } finally {
      $stream.Dispose()
    }

    # Environment indirection keeps the password out of the process command line.
    $previousPassword = [Environment]::GetEnvironmentVariable("VERO_SIGNING_PASSWORD", "Process")
    try {
      [Environment]::SetEnvironmentVariable("VERO_SIGNING_PASSWORD", $password, "Process")
      & $KeytoolCommand -genkeypair -keystore $keystorePath -storetype JKS `
        -keyalg RSA -keysize 3072 -validity 10000 -alias upload `
        -dname "CN=Vero" -storepass:env VERO_SIGNING_PASSWORD -keypass:env VERO_SIGNING_PASSWORD
      if ($LASTEXITCODE -ne 0) {
        throw "Nao foi possivel gerar a assinatura. Preserve key.properties para recuperar as credenciais."
      }
    } finally {
      [Environment]::SetEnvironmentVariable("VERO_SIGNING_PASSWORD", $previousPassword, "Process")
      $password = $null
    }
    Write-Host "Chave criada. Guarde uma copia privada do keystore e de android/key.properties."
  }

  $properties = Get-Content -Raw -LiteralPath $propertiesPath | ConvertFrom-StringData
  foreach ($field in @("storeFile", "storePassword", "keyAlias", "keyPassword")) {
    if ([string]::IsNullOrWhiteSpace($properties.$field)) {
      throw "Campo de assinatura ausente em android/key.properties: $field"
    }
  }
  $existingKeystore = if ([IO.Path]::IsPathRooted($properties.storeFile)) {
    $properties.storeFile
  } else {
    Join-Path (Join-Path $projectRoot "android/app") $properties.storeFile
  }
  if (-not (Test-Path -LiteralPath $existingKeystore -PathType Leaf)) {
    throw "Keystore nao encontrado. Restaure a chave de assinatura original."
  }

  $flutterArguments = @("build", "apk", "--release", "--dart-define-from-file=$configurationPath")
  if ($NoPub) {
    $flutterArguments += "--no-pub"
  }
  & $FlutterCommand --suppress-analytics @flutterArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter falhou com codigo $LASTEXITCODE."
  }
  $apkPath = Join-Path $projectRoot "build/app/outputs/flutter-apk/app-release.apk"
  if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
    throw "Flutter terminou sem gerar o APK esperado."
  }
  Write-Host "APK release de testes: $apkPath"
  Write-Host "Este comando nao valida os requisitos de publicacao. Para a loja, use build_release.ps1."
} finally {
  Pop-Location
}
