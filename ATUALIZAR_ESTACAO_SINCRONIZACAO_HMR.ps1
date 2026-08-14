param(
  [string]$Destino = 'D:\kristal_laboratorial',
  [Parameter(Mandatory = $true)][string]$TrustedCaCertificate,
  [string]$AuthorizedWindowsUser = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ExpectedThumbprint = '41A4507029802AC7A0BADBA496F7BD532E03748A'
$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$appSource = Join-Path $packageRoot 'app_windows'
$manifestPath = Join-Path $packageRoot 'MANIFESTO_ARQUIVOS_APP.json'
$configurator = Join-Path $packageRoot 'CONFIGURAR_SINCRONIZACAO_ESTACAO_HMR.ps1'
$appDestination = Join-Path $Destino 'KRISTAL_LABORATORIAL'
$backupDestination = Join-Path $Destino ('backups\pre_sync_client_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-Sha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  $stream = [IO.File]::OpenRead($Path)
  try {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose() }
  } finally { $stream.Dispose() }
}

function Copy-Tree {
  param([Parameter(Mandatory = $true)][string]$Source, [Parameter(Mandatory = $true)][string]$Destination)
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  & robocopy.exe $Source $Destination /E /COPY:DAT /DCOPY:DA /R:2 /W:2 /XJ | Out-Host
  if ($LASTEXITCODE -gt 7) { throw "Falha ao copiar $Source para $Destination. Codigo: $LASTEXITCODE" }
}

if (-not (Test-Administrator)) { throw 'Execute este script como Administrador.' }
foreach ($required in @($appSource, $manifestPath, $configurator)) {
  if (-not (Test-Path -LiteralPath $required)) { throw "Componente ausente no pacote: $required" }
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.modo -ne 'RELEASE_PRODUCAO') { throw 'Manifesto do aplicativo nao e de producao.' }
foreach ($entry in $manifest.arquivos) {
  $relative = [string]$entry.caminho
  if ([string]::IsNullOrWhiteSpace($relative) -or [IO.Path]::IsPathRooted($relative) -or $relative.Contains('..')) {
    throw "Caminho inseguro no manifesto: $relative"
  }
  $source = Join-Path $appSource $relative
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Arquivo ausente: $relative" }
  if ((Get-Sha256 -Path $source) -ne [string]$entry.sha256) { throw "SHA-256 divergente: $relative" }
}
$sourceExe = Join-Path $appSource 'kristal_laboratorial.exe'
$signature = Get-AuthenticodeSignature -FilePath $sourceExe
if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or
    $signature.SignerCertificate.Thumbprint -ne $ExpectedThumbprint) {
  throw 'Assinatura Authenticode do aplicativo rejeitada.'
}

Get-Process -Name 'kristal_laboratorial' -ErrorAction SilentlyContinue | Stop-Process -Force
if (Test-Path -LiteralPath $appDestination -PathType Container) {
  Copy-Tree -Source $appDestination -Destination (Join-Path $backupDestination 'KRISTAL_LABORATORIAL')
}
Copy-Tree -Source $appSource -Destination $appDestination
foreach ($entry in $manifest.arquivos) {
  $installed = Join-Path $appDestination ([string]$entry.caminho)
  if ((Get-Sha256 -Path $installed) -ne [string]$entry.sha256) { throw "Instalacao divergente: $($entry.caminho)" }
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $configurator `
  -ServerUrl 'https://10.4.169.64:8787' `
  -TrustedCaCertificate $TrustedCaCertificate `
  -AuthorizedWindowsUser $AuthorizedWindowsUser
if ($LASTEXITCODE -ne 0) { throw "Configuracao da sincronizacao falhou. Codigo: $LASTEXITCODE" }

Start-Process -FilePath (Join-Path $appDestination 'kristal_laboratorial.exe') -WorkingDirectory $appDestination
Write-Host 'ESTACAO ATUALIZADA E SINCRONIZACAO INICIADA.' -ForegroundColor Green
Write-Host "Backup da versao anterior: $backupDestination" -ForegroundColor Green