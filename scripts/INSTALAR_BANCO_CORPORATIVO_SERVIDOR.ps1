param(
  [string]$Destino = 'D:\kristal_laboratorial',
  [string]$ServerUrl = 'https://10.4.169.64:8787',
  [string]$Confirmacao = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-Sha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return [BitConverter]::ToString($sha256.ComputeHash($stream)).Replace('-', '')
  } finally {
    $sha256.Dispose()
    $stream.Dispose()
  }
}

if (-not (Test-Administrator)) {
  throw 'Execute este instalador como Administrador no servidor KRISTAL.'
}
if ($Confirmacao -cne 'INSTALAR_BANCO_CORPORATIVO_KRISTAL') {
  throw "Confirme com -Confirmacao 'INSTALAR_BANCO_CORPORATIVO_KRISTAL'."
}

$packageRoot = Split-Path -Parent $PSScriptRoot
$dataSeed = Join-Path $packageRoot 'data_seed'
$corporateDb = Join-Path $dataSeed 'kristal_corporativo.db'
$corporateManifest = Join-Path $packageRoot 'MANIFESTO_INTEGRIDADE_BANCO_CORPORATIVO.json'
$seedInstaller = Join-Path $PSScriptRoot 'instalar_bancos_seed_servidor.ps1'
$checkpointScript = Join-Path $PSScriptRoot 'checkpoint_sqlite_kristal.py'
$packageManifest = Join-Path $packageRoot 'MANIFESTO_SHA256.json'
foreach ($required in @($corporateDb, $corporateManifest, $seedInstaller, $checkpointScript, $packageManifest)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Arquivo obrigatorio ausente: $required"
  }
}

$validation = Get-Content -LiteralPath $corporateManifest -Raw | ConvertFrom-Json
if ([string]$validation.quick_check -ne 'ok' -or
    [string]$validation.integrity_check -ne 'ok' -or
    [long]$validation.current_records -lt 1 -or
    [long]$validation.payload_hashes_validated -lt [long]$validation.current_records) {
  throw 'Manifesto de integridade corporativo rejeitado.'
}

$serverUri = $null
if (-not [Uri]::TryCreate($ServerUrl, [UriKind]::Absolute, [ref]$serverUri) -or
    $serverUri.Scheme -ne 'https') {
  throw 'ServerUrl invalida; o servidor corporativo exige HTTPS.'
}

$taskName = 'KRISTAL LABORATORIAL Servidor HMR'
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -eq $task) {
  throw "Tarefa do servidor nao encontrada: $taskName"
}

$destinationData = Join-Path $Destino 'data'
$destinationDb = Join-Path $destinationData 'kristal_corporativo.db'
$backupRoot = Join-Path $Destino ('backups\pre_corporativo_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
$backupData = Join-Path $backupRoot 'data'
New-Item -ItemType Directory -Path $destinationData -Force | Out-Null
New-Item -ItemType Directory -Path $backupData -Force | Out-Null

if ($task.State -eq 'Running') {
  Stop-ScheduledTask -TaskName $taskName
}
Get-Process -Name 'KRISTAL_SERVIDOR' -ErrorAction SilentlyContinue | Stop-Process -Force

$installExitCode = -1
try {
  if (Test-Path -LiteralPath $destinationDb -PathType Leaf) {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $python) {
      throw 'Python nao encontrado para checkpoint do banco corporativo existente.'
    }
    & $python.Source -B $checkpointScript --database $destinationDb
    if ($LASTEXITCODE -ne 0) {
      throw "Checkpoint do banco corporativo existente falhou. Codigo: $LASTEXITCODE"
    }
    foreach ($transientSuffix in @('-wal', '-shm')) {
      $transient = $destinationDb + $transientSuffix
      if (Test-Path -LiteralPath $transient) {
        Remove-Item -LiteralPath $transient -Force
      }
    }

    Write-Host "Criando backup corporativo em $backupData" -ForegroundColor Cyan
    $sourceHash = Get-Sha256 -Path $destinationDb
    $backupDb = Join-Path $backupData 'kristal_corporativo.db'
    Copy-Item -LiteralPath $destinationDb -Destination $backupDb
    $backupHash = Get-Sha256 -Path $backupDb
    if ($sourceHash -ne $backupHash) {
      throw 'Backup corporativo rejeitado por divergencia SHA-256.'
    }
  }

  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $seedInstaller `
    -PacoteRoot $packageRoot `
    -DestinoData $destinationData `
    -BackupRoot $backupRoot `
    -SubstituirExistentes `
    -SomenteCorporativo
  $installExitCode = $LASTEXITCODE
} finally {
  Start-ScheduledTask -TaskName $taskName
}
if ($installExitCode -ne 0) {
  throw "Instalacao corporativa falhou. Codigo: $installExitCode"
}

$serverProcess = $null
for ($attempt = 1; $attempt -le 60; $attempt++) {
  Start-Sleep -Seconds 1
  $serverProcess = Get-Process -Name 'KRISTAL_SERVIDOR' -ErrorAction SilentlyContinue
  if ($null -ne $serverProcess) {
    break
  }
}
if ($null -eq $serverProcess) {
  throw 'Servidor KRISTAL nao iniciou em ate 60 segundos.'
}

$healthUri = $serverUri.GetLeftPart([UriPartial]::Authority).TrimEnd('/') + '/health'
$health = $null
for ($attempt = 1; $attempt -le 60; $attempt++) {
  Start-Sleep -Seconds 1
  try {
    $health = Invoke-RestMethod -Method Get -Uri $healthUri
    break
  } catch [System.Net.WebException] {
    if ($attempt -eq 60) {
      throw
    }
  } catch [System.Net.Http.HttpRequestException] {
    if ($attempt -eq 60) {
      throw
    }
  }
}
if ($null -eq $health -or [string]$health.status -ne 'ok') {
  throw 'Servidor nao confirmou status ok depois da instalacao corporativa.'
}

Write-Host 'Banco corporativo instalado, validado por SHA-256 e servidor reiniciado com sucesso.' -ForegroundColor Green
Write-Host "Backup anterior preservado em: $backupRoot" -ForegroundColor Green
