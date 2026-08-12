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
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Arquivo ausente para SHA-256: $Path"
  }
  $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return [BitConverter]::ToString($sha256.ComputeHash($stream)).Replace('-', '')
  } finally {
    $sha256.Dispose()
    $stream.Dispose()
  }
}

function Assert-ValidationManifest {
  param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][ValidateSet('operacional', 'corporativo')][string]$Kind
  )
  if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Manifesto de integridade ausente: $ManifestPath"
  }
  $validation = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
  if ([string]$validation.quick_check -ne 'ok' -or [string]$validation.integrity_check -ne 'ok') {
    throw "Manifesto $Kind rejeitado: verificacao SQLite nao aprovada."
  }
  if ($Kind -eq 'operacional') {
    if ([long]$validation.completed_sources -ne 8 -or
        [long]$validation.distinct_legacy_tables -ne 185 -or
        [long]$validation.total_rows -ne 35385785) {
      throw 'Manifesto operacional rejeitado: contagens legadas divergentes.'
    }
  } elseif ([long]$validation.current_records -lt 1 -or
            [long]$validation.payload_hashes_validated -lt [long]$validation.current_records) {
    throw 'Manifesto corporativo rejeitado: registros ou hashes incompletos.'
  }
}

function Assert-OperationalEntitiesManifest {
  param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$DatabasePath
  )
  if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Manifesto de entidades operacionais ausente: $ManifestPath"
  }
  $validation = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
  if ([long]$validation.database_bytes -ne (Get-Item -LiteralPath $DatabasePath).Length) {
    throw 'Manifesto de entidades rejeitado: tamanho do banco divergente.'
  }
  $requiredTables = @(
    'pacientes',
    'exames',
    'pedidos',
    'amostras',
    'resultados',
    'legacy_operational_manifest'
  )
  $tableCounts = @{}
  foreach ($table in @($validation.tables)) {
    $tableCounts[[string]$table.table] = [long]$table.rows
  }
  foreach ($requiredTable in $requiredTables) {
    if (-not $tableCounts.ContainsKey($requiredTable) -or [long]$tableCounts[$requiredTable] -lt 1) {
      throw "Manifesto de entidades rejeitado: tabela ausente ou vazia: $requiredTable"
    }
    if ([long]$validation.empty_ids.$requiredTable -ne 0) {
      throw "Manifesto de entidades rejeitado: IDs vazios em $requiredTable."
    }
  }
  foreach ($orphanProperty in @(
    'orphan_orders',
    'orphan_samples_patients',
    'orphan_samples_orders',
    'orphan_results_patients',
    'orphan_results_orders',
    'orphan_results_samples'
  )) {
    if ([long]$validation.$orphanProperty -ne 0) {
      throw "Manifesto de entidades rejeitado: relacionamento orfao em $orphanProperty."
    }
  }
}
if (-not (Test-Administrator)) {
  throw 'Execute este instalador como Administrador no servidor KRISTAL.'
}
if ($Confirmacao -cne 'INSTALAR_BANCOS_COMPLETOS_KRISTAL') {
  throw "Confirme com -Confirmacao 'INSTALAR_BANCOS_COMPLETOS_KRISTAL'."
}

$packageRoot = Split-Path -Parent $PSScriptRoot
$dataSeed = Join-Path $packageRoot 'data_seed'
$operationalDb = Join-Path $dataSeed 'kristal_laboratorial.db'
$corporateDb = Join-Path $dataSeed 'kristal_corporativo.db'
$operationalManifest = Join-Path $packageRoot 'MANIFESTO_INTEGRIDADE_BANCO_PRODUCAO.json'
$entitiesManifest = Join-Path $packageRoot 'MANIFESTO_ENTIDADES_OPERACIONAIS.json'
$corporateManifest = Join-Path $packageRoot 'MANIFESTO_INTEGRIDADE_BANCO_CORPORATIVO.json'
$packageManifest = Join-Path $packageRoot 'MANIFESTO_SHA256.json'
$seedInstaller = Join-Path $PSScriptRoot 'instalar_bancos_seed_servidor.ps1'
$checkpointScript = Join-Path $PSScriptRoot 'checkpoint_sqlite_kristal.py'
foreach ($required in @(
  $operationalDb,
  $corporateDb,
  $operationalManifest,
  $entitiesManifest,
  $corporateManifest,
  $packageManifest,
  $seedInstaller,
  $checkpointScript
)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Arquivo obrigatorio ausente: $required"
  }
}
Assert-ValidationManifest -ManifestPath $operationalManifest -Kind operacional
Assert-OperationalEntitiesManifest -ManifestPath $entitiesManifest -DatabasePath $operationalDb
Assert-ValidationManifest -ManifestPath $corporateManifest -Kind corporativo

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
$python = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $python) {
  throw 'Python nao encontrado para checkpoint seguro dos bancos existentes.'
}

$destinationData = Join-Path $Destino 'data'
$backupRoot = Join-Path $Destino ('backups\pre_bancos_completos_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
$backupData = Join-Path $backupRoot 'data'
New-Item -ItemType Directory -Path $destinationData -Force | Out-Null
New-Item -ItemType Directory -Path $backupData -Force | Out-Null

$databaseNames = @('kristal_laboratorial.db', 'kristal_corporativo.db')
$existingBefore = @{}
if ($task.State -eq 'Running') {
  Stop-ScheduledTask -TaskName $taskName
}
Get-Process -Name 'KRISTAL_SERVIDOR' -ErrorAction SilentlyContinue | Stop-Process -Force

$installExitCode = -1
$rollbackRequired = $false
try {
  foreach ($databaseName in $databaseNames) {
    $destinationDb = Join-Path $destinationData $databaseName
    $existingBefore[$databaseName] = Test-Path -LiteralPath $destinationDb -PathType Leaf
    if (-not $existingBefore[$databaseName]) {
      continue
    }
    & $python.Source -B $checkpointScript --database $destinationDb
    if ($LASTEXITCODE -ne 0) {
      throw "Checkpoint do banco existente falhou: $databaseName. Codigo: $LASTEXITCODE"
    }
    foreach ($suffix in @('-wal', '-shm')) {
      $transient = $destinationDb + $suffix
      if (Test-Path -LiteralPath $transient) {
        Remove-Item -LiteralPath $transient -Force
      }
    }
    $sourceHash = Get-Sha256 -Path $destinationDb
    $backupDb = Join-Path $backupData $databaseName
    Copy-Item -LiteralPath $destinationDb -Destination $backupDb
    if ((Get-Sha256 -Path $backupDb) -ne $sourceHash) {
      throw "Backup rejeitado por divergencia SHA-256: $databaseName"
    }
  }

  $rollbackRequired = $true
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $seedInstaller `
    -PacoteRoot $packageRoot `
    -DestinoData $destinationData `
    -BackupRoot $backupRoot `
    -SubstituirExistentes
  $installExitCode = $LASTEXITCODE
  if ($installExitCode -ne 0) {
    foreach ($databaseName in $databaseNames) {
      $destinationDb = Join-Path $destinationData $databaseName
      $backupDb = Join-Path $backupData $databaseName
      if ([bool]$existingBefore[$databaseName]) {
        if (-not (Test-Path -LiteralPath $backupDb -PathType Leaf)) {
          throw "Rollback impossivel; backup ausente: $backupDb"
        }
        Copy-Item -LiteralPath $backupDb -Destination $destinationDb -Force
      } elseif (Test-Path -LiteralPath $destinationDb -PathType Leaf) {
        Remove-Item -LiteralPath $destinationDb -Force
      }
    }
    $rollbackRequired = $false
    throw "Instalacao dos bancos falhou e foi revertida. Codigo: $installExitCode"
  }

  Copy-Item -LiteralPath $operationalManifest -Destination (Join-Path $destinationData 'MANIFESTO_INTEGRIDADE_BANCO_PRODUCAO.json') -Force
  Copy-Item -LiteralPath $entitiesManifest -Destination (Join-Path $destinationData 'MANIFESTO_ENTIDADES_OPERACIONAIS.json') -Force
  Copy-Item -LiteralPath $corporateManifest -Destination (Join-Path $destinationData 'MANIFESTO_INTEGRIDADE_BANCO_CORPORATIVO.json') -Force
  $rollbackRequired = $false
} finally {
  if ($rollbackRequired) {
    Write-Warning 'A instalacao foi interrompida antes da conclusao. Verifique os backups antes de liberar o servidor.'
  }
  Start-ScheduledTask -TaskName $taskName
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
    if ($attempt -eq 60) { throw }
  } catch [System.Net.Http.HttpRequestException] {
    if ($attempt -eq 60) { throw }
  }
}
if ($null -eq $health -or [string]$health.status -ne 'ok') {
  throw 'Servidor nao confirmou status ok depois da instalacao dos bancos.'
}

Write-Host 'Bancos operacional e corporativo instalados com SHA-256, backup e reinicio do servidor.' -ForegroundColor Green
Write-Host "Backup anterior preservado em: $backupRoot" -ForegroundColor Green
