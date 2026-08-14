param(
  [string]$Destino = 'D:\kristal_laboratorial',
  [string]$ServerUrl = 'https://10.4.169.64:8787',
  [ValidatePattern('^(?:[01]\d|2[0-3]):[0-5]\d$')]
  [string]$BackupHorario = '23:00'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ExpectedThumbprint = '41A4507029802AC7A0BADBA496F7BD532E03748A'
$TaskName = 'KRISTAL LABORATORIAL Servidor HMR'
$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverSource = Join-Path $packageRoot 'KRISTAL_SERVIDOR'
$manifestPath = Join-Path $packageRoot 'MANIFESTO_ARQUIVOS_SERVIDOR.json'
$scriptsSource = Join-Path $packageRoot 'scripts_servidor'
$serverDestination = Join-Path $Destino 'KRISTAL_SERVIDOR'
$portalDestination = Join-Path $Destino 'portal_web'
$envPath = Join-Path $portalDestination '.env'
$backupRoot = Join-Path $Destino ('backups\pre_server_binary_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-Sha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
  finally { $sha.Dispose(); $stream.Dispose() }
}

function Copy-Tree {
  param([Parameter(Mandatory = $true)][string]$Source, [Parameter(Mandatory = $true)][string]$Destination)
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  & robocopy.exe $Source $Destination /E /COPY:DAT /DCOPY:DA /R:2 /W:2 /XJ | Out-Host
  if ($LASTEXITCODE -gt 7) { throw "Falha ao copiar $Source para $Destination. Codigo: $LASTEXITCODE" }
}

function Get-EnvValue {
  param([Parameter(Mandatory = $true)][string]$Name)
  $prefix = $Name + '='
  $line = Get-Content -LiteralPath $envPath |
    Where-Object { $_ -clike ($prefix + '*') } |
    Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($line)) { throw "Variavel ausente no .env: $Name" }
  return $line.Substring($prefix.Length).Trim()
}

function Resolve-DataPath {
  param([Parameter(Mandatory = $true)][string]$ConfiguredPath)
  if ([IO.Path]::IsPathRooted($ConfiguredPath)) { return [IO.Path]::GetFullPath($ConfiguredPath) }
  return [IO.Path]::GetFullPath((Join-Path $portalDestination $ConfiguredPath))
}

if (-not (Test-Administrator)) { throw 'Execute este atualizador como Administrador no servidor HMR.' }
foreach ($required in @($serverSource, $manifestPath, $scriptsSource, $envPath)) {
  if (-not (Test-Path -LiteralPath $required)) { throw "Componente obrigatorio ausente: $required" }
}
$serverUri = $null
if (-not [Uri]::TryCreate($ServerUrl, [UriKind]::Absolute, [ref]$serverUri) -or
    $serverUri.Scheme -ne 'https' -or [string]::IsNullOrWhiteSpace($serverUri.Host)) {
  throw 'ServerUrl invalida; informe URL HTTPS absoluta.'
}

$databasePaths = [ordered]@{
  portal = Resolve-DataPath -ConfiguredPath (Get-EnvValue -Name 'KRISTAL_DB_PATH')
  operacional = Resolve-DataPath -ConfiguredPath (Get-EnvValue -Name 'KRISTAL_OPERATIONAL_DB_PATH')
  corporativo = Resolve-DataPath -ConfiguredPath (Get-EnvValue -Name 'KRISTAL_CORPORATE_DB_PATH')
}
$databaseEvidence = [ordered]@{}
foreach ($entry in $databasePaths.GetEnumerator()) {
  if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) {
    throw "Banco $($entry.Key) ausente no servidor: $($entry.Value)"
  }
  $item = Get-Item -LiteralPath $entry.Value
  if ($item.Length -le 0) { throw "Banco $($entry.Key) vazio: $($entry.Value)" }
  $databaseEvidence[$entry.Key] = [ordered]@{
    path = $entry.Value
    length = $item.Length
    sha256 = Get-Sha256 -Path $entry.Value
  }
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.modo -ne 'RELEASE_PRODUCAO') { throw 'Manifesto do servidor nao e de producao.' }
foreach ($entry in $manifest.arquivos) {
  $relative = [string]$entry.caminho
  if ([string]::IsNullOrWhiteSpace($relative) -or [IO.Path]::IsPathRooted($relative) -or $relative.Contains('..')) {
    throw "Caminho inseguro no manifesto: $relative"
  }
  $source = Join-Path $serverSource $relative
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Arquivo ausente: $relative" }
  if ((Get-Sha256 -Path $source) -ne [string]$entry.sha256) { throw "SHA-256 divergente: $relative" }
}
$sourceExe = Join-Path $serverSource 'KRISTAL_SERVIDOR.exe'
$signature = Get-AuthenticodeSignature -FilePath $sourceExe
if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or
    $signature.SignerCertificate.Thumbprint -ne $ExpectedThumbprint) {
  throw 'Assinatura Authenticode do servidor rejeitada.'
}

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -ne $task -and $task.State -eq 'Running') { Stop-ScheduledTask -TaskName $TaskName }
Get-Process -Name 'KRISTAL_SERVIDOR' -ErrorAction SilentlyContinue | Stop-Process -Force

$completed = $false
try {
  if (Test-Path -LiteralPath $serverDestination -PathType Container) {
    Copy-Tree -Source $serverDestination -Destination (Join-Path $backupRoot 'KRISTAL_SERVIDOR')
  }
  New-Item -ItemType Directory -Path (Join-Path $backupRoot 'scripts_servidor') -Force | Out-Null
  foreach ($name in @(
    'iniciar_servidor_background.ps1',
    'instalar_autostart_windows.ps1',
    'instalar_backup_automatico_windows.ps1',
    'executar_backup_servidor.ps1',
    'executar_backup_servidor.py',
    'configurar_firewall_hmr.ps1'
  )) {
    $current = Join-Path $portalDestination $name
    if (Test-Path -LiteralPath $current -PathType Leaf) {
      Copy-Item -LiteralPath $current -Destination (Join-Path $backupRoot 'scripts_servidor') -Force
    }
  }

  Copy-Tree -Source $serverSource -Destination $serverDestination
  foreach ($entry in $manifest.arquivos) {
    $installed = Join-Path $serverDestination ([string]$entry.caminho)
    if ((Get-Sha256 -Path $installed) -ne [string]$entry.sha256) {
      throw "Instalacao do servidor divergente: $($entry.caminho)"
    }
  }
  foreach ($sourceScript in Get-ChildItem -LiteralPath $scriptsSource -File) {
    Copy-Item -LiteralPath $sourceScript.FullName -Destination $portalDestination -Force
  }

  foreach ($entry in $databaseEvidence.GetEnumerator()) {
    $current = Get-Item -LiteralPath $entry.Value.path
    if ($current.Length -ne [long]$entry.Value.length -or
        (Get-Sha256 -Path $entry.Value.path) -ne [string]$entry.Value.sha256) {
      throw "Banco $($entry.Key) foi alterado durante a atualizacao; operacao rejeitada."
    }
  }

  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $portalDestination 'instalar_backup_automatico_windows.ps1') -Horario $BackupHorario
  if ($LASTEXITCODE -ne 0) { throw "Falha ao instalar backup automatico. Codigo: $LASTEXITCODE" }

  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $portalDestination 'instalar_autostart_windows.ps1')
  if ($LASTEXITCODE -ne 0) { throw "Falha ao instalar autostart. Codigo: $LASTEXITCODE" }

  $healthUri = $serverUri.GetLeftPart([UriPartial]::Authority).TrimEnd('/') + '/health'
  $health = $null
  for ($attempt = 1; $attempt -le 60; $attempt++) {
    Start-Sleep -Seconds 1
    try {
      $health = Invoke-RestMethod -Method Get -Uri $healthUri -TimeoutSec 5
      if ([string]$health.status -eq 'ok') { break }
    } catch [System.Net.WebException] {
      if ($attempt -eq 60) { throw }
    } catch [System.Net.Http.HttpRequestException] {
      if ($attempt -eq 60) { throw }
    }
  }
  if ($null -eq $health -or [string]$health.status -ne 'ok') {
    throw 'Servidor nao confirmou /health status ok.'
  }
  $completed = $true
} finally {
  if (-not $completed) {
    $backupServer = Join-Path $backupRoot 'KRISTAL_SERVIDOR'
    if (Test-Path -LiteralPath $backupServer -PathType Container) {
      Copy-Tree -Source $backupServer -Destination $serverDestination
    }
    $restoredTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $restoredTask) { Start-ScheduledTask -TaskName $TaskName }
  }
}

Write-Host 'SERVIDOR ATUALIZADO, BANCOS PRESERVADOS E AUTOSTART ATIVO.' -ForegroundColor Green
Write-Host "Backup do binario anterior: $backupRoot" -ForegroundColor Green
foreach ($entry in $databaseEvidence.GetEnumerator()) {
  Write-Host "Banco preservado: $($entry.Key) | $($entry.Value.path) | SHA-256 $($entry.Value.sha256)" -ForegroundColor Green
}
