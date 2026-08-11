param(
  [Parameter(Mandatory = $true)][string]$PacoteRoot,
  [Parameter(Mandatory = $true)][string]$DestinoData,
  [Parameter(Mandatory = $true)][string]$BackupRoot,
  [switch]$SubstituirExistentes,
  [switch]$SomenteCorporativo
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$package = [IO.Path]::GetFullPath($PacoteRoot)
$dataSeed = Join-Path $package 'data_seed'
$manifestPath = Join-Path $package 'MANIFESTO_SHA256.json'
$destinationRoot = [IO.Path]::GetFullPath($DestinoData)
$backup = [IO.Path]::GetFullPath($BackupRoot)

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  throw "Manifesto SHA-256 do pacote ausente: $manifestPath"
}
if (-not (Test-Path -LiteralPath $dataSeed -PathType Container)) {
  throw "Diretorio data_seed ausente: $dataSeed"
}
New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($null -eq $manifest.arquivos -or [int]$manifest.total_arquivos -lt 1) {
  throw 'Manifesto SHA-256 invalido ou vazio.'
}

function Get-ExpectedHash {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  $normalized = $RelativePath.Replace('/', '\')
  $entry = @($manifest.arquivos) |
    Where-Object { ([string]$_.caminho).Replace('/', '\') -ieq $normalized } |
    Select-Object -First 1
  if ($null -eq $entry -or [string]::IsNullOrWhiteSpace([string]$entry.sha256)) {
    throw "Arquivo nao registrado no manifesto: $RelativePath"
  }
  return ([string]$entry.sha256).ToUpperInvariant()
}

function Get-Sha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Arquivo ausente para calculo SHA-256: $Path"
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

function Assert-Hash {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedHash,
    [Parameter(Mandatory = $true)][string]$Description
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "$Description ausente: $Path"
  }
  $actual = (Get-Sha256 -Path $Path).ToUpperInvariant()
  if ($actual -ne $ExpectedHash) {
    throw "$Description possui SHA-256 divergente. Esperado=$ExpectedHash Atual=$actual"
  }
}

$databaseNames = if ($SomenteCorporativo) {
  @('kristal_corporativo.db')
} else {
  @('kristal_laboratorial.db', 'kristal_corporativo.db')
}

foreach ($databaseName in $databaseNames) {
  $relativePath = 'data_seed\' + $databaseName
  $source = Join-Path $dataSeed $databaseName
  $destination = Join-Path $destinationRoot $databaseName
  $expectedHash = Get-ExpectedHash -RelativePath $relativePath
  Assert-Hash -Path $source -ExpectedHash $expectedHash -Description "Banco-semente $databaseName"

  if ((Test-Path -LiteralPath $destination -PathType Leaf) -and -not $SubstituirExistentes) {
    Write-Host "Banco existente preservado sem sobrescrita: $databaseName" -ForegroundColor DarkYellow
    continue
  }

  if (Test-Path -LiteralPath $destination -PathType Leaf) {
    $backupDatabase = Join-Path (Join-Path $backup 'data') $databaseName
    if (-not (Test-Path -LiteralPath $backupDatabase -PathType Leaf)) {
      throw "Backup obrigatorio do banco existente nao encontrado: $backupDatabase"
    }
    $existingHash = Get-Sha256 -Path $destination
    Assert-Hash -Path $backupDatabase -ExpectedHash $existingHash -Description "Backup previo $databaseName"
  }

  $incoming = $destination + '.incoming'
  $rollback = $destination + '.rollback'
  foreach ($transient in @($incoming, $rollback)) {
    if (Test-Path -LiteralPath $transient) {
      throw "Arquivo transitorio de atualizacao ja existe; revise antes de continuar: $transient"
    }
  }

  Copy-Item -LiteralPath $source -Destination $incoming
  Assert-Hash -Path $incoming -ExpectedHash $expectedHash -Description "Copia temporaria $databaseName"

  $hadExisting = Test-Path -LiteralPath $destination -PathType Leaf
  if ($hadExisting) {
    Move-Item -LiteralPath $destination -Destination $rollback
  }
  try {
    Move-Item -LiteralPath $incoming -Destination $destination
    Assert-Hash -Path $destination -ExpectedHash $expectedHash -Description "Banco instalado $databaseName"
  } catch [System.IO.IOException] {
    if (Test-Path -LiteralPath $destination) {
      Move-Item -LiteralPath $destination -Destination ($destination + '.rejeitado') -Force
    }
    if ($hadExisting -and (Test-Path -LiteralPath $rollback)) {
      Move-Item -LiteralPath $rollback -Destination $destination
    }
    throw
  } catch [System.UnauthorizedAccessException] {
    if ($hadExisting -and (Test-Path -LiteralPath $rollback)) {
      Move-Item -LiteralPath $rollback -Destination $destination
    }
    throw
  }

  if (Test-Path -LiteralPath $rollback) {
    Remove-Item -LiteralPath $rollback -Force
  }
  Write-Host "Banco instalado e validado por SHA-256: $databaseName" -ForegroundColor Green
}
