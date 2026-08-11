param(
  [string]$DataRoot = 'D:\KRISTAL LABORATORIAL SISTEMA\KRISTAL_BUILD_STAGE_20260810\data',
  [string]$OutputRoot = 'D:\KRISTAL LABORATORIAL SISTEMA\EXPORTACAO_SERVIDOR',
  [string]$RarExe = 'C:\Program Files\WinRAR\Rar.exe',
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

function Assert-ChildPath {
  param(
    [Parameter(Mandatory = $true)][string]$Parent,
    [Parameter(Mandatory = $true)][string]$Child
  )
  $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
  $childFull = [IO.Path]::GetFullPath($Child)
  if (-not $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Caminho fora da raiz autorizada: $childFull"
  }
}

function Assert-ManifestDatabase {
  param(
    [Parameter(Mandatory = $true)][psobject]$Validation,
    [Parameter(Mandatory = $true)][string]$DatabasePath,
    [Parameter(Mandatory = $true)][ValidateSet('operacional', 'corporativo')][string]$Kind
  )
  if ([string]$Validation.quick_check -ne 'ok' -or [string]$Validation.integrity_check -ne 'ok') {
    throw "Manifesto $Kind rejeitado: quick_check/integrity_check nao aprovados."
  }
  if ([IO.Path]::GetFullPath([string]$Validation.database) -ine [IO.Path]::GetFullPath($DatabasePath)) {
    throw "Manifesto $Kind aponta para banco diferente do arquivo de exportacao."
  }
  if ([long]$Validation.database_bytes -ne (Get-Item -LiteralPath $DatabasePath).Length) {
    throw "Manifesto $Kind rejeitado: tamanho do banco divergente."
  }
  if ($Kind -eq 'operacional') {
    if ([long]$Validation.completed_sources -ne 8 -or
        [long]$Validation.distinct_legacy_tables -ne 185 -or
        [long]$Validation.total_rows -ne 35385785) {
      throw 'Manifesto operacional rejeitado: contagens legadas divergentes.'
    }
    $sources = @($Validation.sources)
    if ($sources.Count -ne 8 -or @($sources | Where-Object { [string]$_.status -ne 'CONCLUIDO' }).Count -ne 0) {
      throw 'Manifesto operacional rejeitado: fontes nao concluidas.'
    }
  } elseif ([long]$Validation.current_records -lt 1 -or
            [long]$Validation.payload_hashes_validated -lt [long]$Validation.current_records) {
    throw 'Manifesto corporativo rejeitado: registros ou hashes incompletos.'
  }
}

if (-not (Test-Administrator)) {
  throw 'Execute este gerador como Administrador na maquina de desenvolvimento.'
}
if ($Confirmacao -cne 'GERAR_RAR_BANCOS_COMPLETOS_CRIPTOGRAFADO') {
  throw "Confirme com -Confirmacao 'GERAR_RAR_BANCOS_COMPLETOS_CRIPTOGRAFADO'."
}

$sourceRoot = [IO.Path]::GetFullPath($DataRoot)
$output = [IO.Path]::GetFullPath($OutputRoot)
$operationalDb = Join-Path $sourceRoot 'kristal_laboratorial.db'
$corporateDb = Join-Path $sourceRoot 'kristal_corporativo.db'
$operationalManifest = Join-Path $sourceRoot 'MANIFESTO_INTEGRIDADE_BANCO_PRODUCAO.json'
$corporateManifest = Join-Path $sourceRoot 'MANIFESTO_INTEGRIDADE_BANCO_CORPORATIVO.json'
foreach ($required in @($operationalDb, $corporateDb, $operationalManifest, $corporateManifest, $RarExe)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Arquivo obrigatorio ausente: $required"
  }
}
foreach ($database in @($operationalDb, $corporateDb)) {
  foreach ($suffix in @('-wal', '-shm')) {
    $transient = $database + $suffix
    if (Test-Path -LiteralPath $transient) {
      throw "Arquivo transacional pendente; conclua checkpoint antes do RAR: $transient"
    }
  }
}

$operationalValidation = Get-Content -LiteralPath $operationalManifest -Raw | ConvertFrom-Json
$corporateValidation = Get-Content -LiteralPath $corporateManifest -Raw | ConvertFrom-Json
Assert-ManifestDatabase -Validation $operationalValidation -DatabasePath $operationalDb -Kind operacional
Assert-ManifestDatabase -Validation $corporateValidation -DatabasePath $corporateDb -Kind corporativo

$rarItem = Get-Item -LiteralPath $RarExe
$rarVersion = [Version]$rarItem.VersionInfo.FileVersion
$rarSignature = Get-AuthenticodeSignature -LiteralPath $RarExe
if ($rarVersion -lt [Version]'7.23.0' -or
    $rarSignature.Status -ne 'Valid' -or
    [string]$rarSignature.SignerCertificate.Subject -notlike '*win.rar GmbH*') {
  throw 'RAR rejeitado: exige versao 7.23 ou superior e assinatura valida da win.rar GmbH.'
}
$rarLicense = Join-Path (Split-Path -Parent $RarExe) 'rarreg.key'
if (-not (Test-Path -LiteralPath $rarLicense -PathType Leaf)) {
  throw 'Licenca WinRAR nao encontrada. A exportacao de producao exige instalacao licenciada.'
}

New-Item -ItemType Directory -Path $output -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$stage = Join-Path $output ('.stage_bancos_completos_' + $stamp)
$archive = Join-Path $output ('KRISTAL_BANCOS_COMPLETOS_PRODUCAO_HMR_' + $stamp + '.rar')
$archiveHashFile = $archive + '.sha256'
Assert-ChildPath -Parent $output -Child $stage
Assert-ChildPath -Parent $output -Child $archive
if ((Test-Path -LiteralPath $stage) -or (Test-Path -LiteralPath $archive)) {
  throw 'Destino de exportacao ja existe; nenhuma sobrescrita foi realizada.'
}

$success = $false
try {
  $stageData = Join-Path $stage 'data_seed'
  $stageScripts = Join-Path $stage 'scripts'
  New-Item -ItemType Directory -Path $stageData -Force | Out-Null
  New-Item -ItemType Directory -Path $stageScripts -Force | Out-Null

  foreach ($databaseName in @('kristal_laboratorial.db', 'kristal_corporativo.db')) {
    $sourceDb = Join-Path $sourceRoot $databaseName
    $stageDb = Join-Path $stageData $databaseName
    if ([IO.Path]::GetPathRoot($sourceDb) -ieq [IO.Path]::GetPathRoot($stageDb)) {
      New-Item -ItemType HardLink -Path $stageDb -Target $sourceDb | Out-Null
    } else {
      Copy-Item -LiteralPath $sourceDb -Destination $stageDb
    }
  }
  Copy-Item -LiteralPath $operationalManifest -Destination (Join-Path $stage 'MANIFESTO_INTEGRIDADE_BANCO_PRODUCAO.json')
  Copy-Item -LiteralPath $corporateManifest -Destination (Join-Path $stage 'MANIFESTO_INTEGRIDADE_BANCO_CORPORATIVO.json')
  foreach ($scriptName in @(
    'instalar_bancos_seed_servidor.ps1',
    'INSTALAR_BANCOS_COMPLETOS_SERVIDOR.ps1',
    'checkpoint_sqlite_kristal.py',
    'validar_banco_producao_kristal.py',
    'validar_banco_corporativo_kristal.py'
  )) {
    $scriptSource = Join-Path $PSScriptRoot $scriptName
    if (-not (Test-Path -LiteralPath $scriptSource -PathType Leaf)) {
      throw "Script obrigatorio ausente: $scriptSource"
    }
    Copy-Item -LiteralPath $scriptSource -Destination (Join-Path $stageScripts $scriptName)
  }

  $instructions = @'
KRISTAL LABORATORIAL - BANCOS COMPLETOS DE PRODUCAO HMR

Este pacote contem dados de saude protegidos. Mantenha o pendrive sob custodia.

1. No servidor, copie o RAR para uma pasta temporaria do disco D:.
2. Extraia o RAR. A senha sera solicitada; nao a registre em arquivo de texto.
3. Abra PowerShell como Administrador na pasta extraida.
4. Execute:

powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\INSTALAR_BANCOS_COMPLETOS_SERVIDOR.ps1" -Destino "D:\kristal_laboratorial" -ServerUrl "https://10.4.169.64:8787" -Confirmacao "INSTALAR_BANCOS_COMPLETOS_KRISTAL"

O instalador para somente o servidor KRISTAL, consolida WAL, cria backup, valida SHA-256,
substitui os bancos, reinicia a tarefa automatica e testa HTTPS /health.
Nao copie os arquivos diretamente sobre D:\kristal_laboratorial\data.
'@
  [IO.File]::WriteAllText(
    (Join-Path $stage 'INSTRUCOES_TRANSFERENCIA_E_INSTALACAO.txt'),
    $instructions,
    [Text.UTF8Encoding]::new($false)
  )

  $manifestItems = foreach ($file in Get-ChildItem -LiteralPath $stage -Recurse -File) {
    [ordered]@{
      caminho = $file.FullName.Substring($stage.Length + 1)
      tamanho = $file.Length
      sha256 = Get-Sha256 -Path $file.FullName
    }
  }
  if (@($manifestItems | Where-Object { $_.caminho -match '(?i)-wal$|-shm$' }).Count -gt 0) {
    throw 'WAL ou SHM detectado na exportacao completa.'
  }
  $manifest = [ordered]@{
    sistema = 'KRISTAL LABORATORIAL'
    finalidade = 'BANCOS COMPLETOS DE PRODUCAO HMR'
    gerado_em = (Get-Date).ToString('o')
    fontes_legadas = [long]$operationalValidation.completed_sources
    tabelas_legadas = [long]$operationalValidation.distinct_legacy_tables
    linhas_legadas = [long]$operationalValidation.total_rows
    registros_corporativos = [long]$corporateValidation.current_records
    versao_corporativa = [long]$corporateValidation.current_version
    quick_check_operacional = [string]$operationalValidation.quick_check
    integrity_check_operacional = [string]$operationalValidation.integrity_check
    quick_check_corporativo = [string]$corporateValidation.quick_check
    integrity_check_corporativo = [string]$corporateValidation.integrity_check
    arquivos = @($manifestItems)
    total_arquivos = @($manifestItems).Count
    total_bytes = [long](($manifestItems | Measure-Object -Property tamanho -Sum).Sum)
  }
  $manifestPath = Join-Path $stage 'MANIFESTO_SHA256.json'
  [IO.File]::WriteAllText(
    $manifestPath,
    ($manifest | ConvertTo-Json -Depth 6),
    [Text.UTF8Encoding]::new($false)
  )
  $manifestHash = Get-Sha256 -Path $manifestPath
  [IO.File]::WriteAllText(
    (Join-Path $stage 'MANIFESTO_SHA256.txt'),
    ($manifestHash + '  MANIFESTO_SHA256.json' + [Environment]::NewLine),
    [Text.UTF8Encoding]::new($false)
  )

  Write-Host 'O RAR solicitara uma senha forte diretamente no console.' -ForegroundColor Cyan
  Write-Host 'Conteudo e nomes dos arquivos serao criptografados; a senha nao sera armazenada.' -ForegroundColor Cyan
  Push-Location $stage
  try {
    & $RarExe a -r -ma5 -m5 -s -htb -rr1p -qo+ -hp -idq -y $archive '*'
    $createExitCode = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  if ($createExitCode -ne 0) {
    throw "Criacao do RAR falhou. Codigo: $createExitCode"
  }

  Write-Host 'Digite novamente a senha para o teste integral do RAR.' -ForegroundColor Cyan
  & $RarExe t -p -idq -y $archive
  $testExitCode = $LASTEXITCODE
  if ($testExitCode -ne 0) {
    throw "Teste integral do RAR falhou. Codigo: $testExitCode"
  }

  $archiveHash = Get-Sha256 -Path $archive
  [IO.File]::WriteAllText(
    $archiveHashFile,
    ($archiveHash + '  ' + [IO.Path]::GetFileName($archive) + [Environment]::NewLine),
    [Text.UTF8Encoding]::new($false)
  )
  $success = $true
  Write-Host "RAR_BANCOS_COMPLETOS=$archive" -ForegroundColor Green
  Write-Host "RAR_SHA256=$archiveHash" -ForegroundColor Green
} finally {
  if (Test-Path -LiteralPath $stage) {
    Assert-ChildPath -Parent $output -Child $stage
    Remove-Item -LiteralPath $stage -Recurse -Force
  }
  if (-not $success) {
    foreach ($partial in @($archive, $archiveHashFile)) {
      if (Test-Path -LiteralPath $partial) {
        Assert-ChildPath -Parent $output -Child $partial
        Remove-Item -LiteralPath $partial -Force
      }
    }
  }
}
