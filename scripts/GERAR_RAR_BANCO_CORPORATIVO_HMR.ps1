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

if (-not (Test-Administrator)) {
  throw 'Execute este gerador como Administrador na maquina de desenvolvimento.'
}
if ($Confirmacao -cne 'GERAR_RAR_CORPORATIVO_CRIPTOGRAFADO') {
  throw "Confirme com -Confirmacao 'GERAR_RAR_CORPORATIVO_CRIPTOGRAFADO'."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = [IO.Path]::GetFullPath($DataRoot)
$output = [IO.Path]::GetFullPath($OutputRoot)
$corporateDb = Join-Path $sourceRoot 'kristal_corporativo.db'
$corporateManifest = Join-Path $sourceRoot 'MANIFESTO_INTEGRIDADE_BANCO_CORPORATIVO.json'
foreach ($required in @($corporateDb, $corporateManifest, $RarExe)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Arquivo obrigatorio ausente: $required"
  }
}
foreach ($forbidden in @(
  (Join-Path $sourceRoot 'kristal_corporativo.db-wal'),
  (Join-Path $sourceRoot 'kristal_corporativo.db-shm')
)) {
  if (Test-Path -LiteralPath $forbidden) {
    throw "Arquivo transacional pendente; conclua o checkpoint antes do RAR: $forbidden"
  }
}

$validation = Get-Content -LiteralPath $corporateManifest -Raw | ConvertFrom-Json
if ([string]$validation.quick_check -ne 'ok' -or
    [string]$validation.integrity_check -ne 'ok' -or
    [long]$validation.current_records -lt 1 -or
    [long]$validation.payload_hashes_validated -lt [long]$validation.current_records) {
  throw 'Manifesto de integridade corporativo rejeitado.'
}

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
$stage = Join-Path $output ('.stage_corporativo_' + $stamp)
$archive = Join-Path $output ('KRISTAL_BANCO_CORPORATIVO_PRODUCAO_HMR_' + $stamp + '.rar')
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

  $stageDb = Join-Path $stageData 'kristal_corporativo.db'
  if ([IO.Path]::GetPathRoot($corporateDb) -ieq [IO.Path]::GetPathRoot($stageDb)) {
    New-Item -ItemType HardLink -Path $stageDb -Target $corporateDb | Out-Null
  } else {
    Copy-Item -LiteralPath $corporateDb -Destination $stageDb
  }
  Copy-Item -LiteralPath $corporateManifest -Destination (Join-Path $stage 'MANIFESTO_INTEGRIDADE_BANCO_CORPORATIVO.json')
  foreach ($scriptName in @(
    'instalar_bancos_seed_servidor.ps1',
    'INSTALAR_BANCO_CORPORATIVO_SERVIDOR.ps1',
    'validar_banco_corporativo_kristal.py',
    'checkpoint_sqlite_kristal.py'
  )) {
    $scriptSource = Join-Path $PSScriptRoot $scriptName
    if (-not (Test-Path -LiteralPath $scriptSource -PathType Leaf)) {
      throw "Script obrigatorio ausente: $scriptSource"
    }
    Copy-Item -LiteralPath $scriptSource -Destination (Join-Path $stageScripts $scriptName)
  }

  $instructions = @'
KRISTAL LABORATORIAL - BANCO CORPORATIVO DE PRODUCAO HMR

1. Extraia este RAR em uma pasta temporaria no servidor. O RAR solicitara a senha.
2. Abra o PowerShell como Administrador na pasta extraida.
3. Execute:

powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\INSTALAR_BANCO_CORPORATIVO_SERVIDOR.ps1" -Destino "D:\kristal_laboratorial" -ServerUrl "https://10.4.169.64:8787" -Confirmacao "INSTALAR_BANCO_CORPORATIVO_KRISTAL"

O instalador interrompe somente o servidor KRISTAL, cria e valida backup, confere SHA-256, troca o banco de forma atomica, reinicia a tarefa do Windows e testa HTTPS /health.
Nao extraia o banco diretamente sobre D:\kristal_laboratorial\data.
Nao inclua arquivos WAL ou SHM.
'@
  [IO.File]::WriteAllText(
    (Join-Path $stage 'INSTRUCOES_INSTALACAO_BANCO_CORPORATIVO.txt'),
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
  if (@($manifestItems | Where-Object { $_.caminho -like '*kristal_laboratorial.db*' }).Count -gt 0) {
    throw 'Banco operacional detectado na exportacao corporativa.'
  }
  if (@($manifestItems | Where-Object { $_.caminho -match '(?i)-wal$|-shm$' }).Count -gt 0) {
    throw 'WAL ou SHM detectado na exportacao corporativa.'
  }
  $manifest = [ordered]@{
    sistema = 'KRISTAL LABORATORIAL'
    finalidade = 'BANCO CORPORATIVO DE PRODUCAO HMR'
    gerado_em = (Get-Date).ToString('o')
    banco = 'kristal_corporativo.db'
    registros_atuais = [long]$validation.current_records
    versao_corporativa = [long]$validation.current_version
    quick_check = [string]$validation.quick_check
    integrity_check = [string]$validation.integrity_check
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
  Write-Host 'A senha nao sera exibida, armazenada nem recebida pelo script.' -ForegroundColor Cyan
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
  Write-Host "RAR_CORPORATIVO=$archive" -ForegroundColor Green
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
