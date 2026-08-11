param(
  [string]$ProjectRoot = 'C:\kristal_laboratorial',
  [string]$OutputRoot = 'D:\KRISTAL LABORATORIAL SISTEMA',
  [string]$CompiledRoot = 'D:\KRISTAL LABORATORIAL SISTEMA\COMPILADOS',
  [string]$DataSeedRoot = 'D:\KRISTAL LABORATORIAL SISTEMA\KRISTAL_BUILD_STAGE_20260810\data'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$project = [IO.Path]::GetFullPath($ProjectRoot)
$compiled = [IO.Path]::GetFullPath($CompiledRoot)
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$packageName = 'KRISTAL_LABORATORIAL_PRODUCAO_HMR_' + $stamp
$package = Join-Path ([IO.Path]::GetFullPath($OutputRoot)) $packageName

function Copy-Directory {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [string[]]$Extra = @()
  )
  if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "Diretorio obrigatorio ausente: $Source"
  }
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  $arguments = @($Source, $Destination, '/E', '/COPY:DAT', '/DCOPY:DA', '/R:2', '/W:2', '/XJ')
  $arguments += $Extra
  & robocopy @arguments | Out-Host
  if ($LASTEXITCODE -gt 7) {
    throw "Robocopy falhou: $Source -> $Destination. Codigo: $LASTEXITCODE"
  }
}

New-Item -ItemType Directory -Path $package -Force | Out-Null

Copy-Directory -Source (Join-Path $compiled 'app_windows') -Destination (Join-Path $package 'app_windows')
Copy-Directory -Source (Join-Path $compiled 'server_windows') -Destination (Join-Path $package 'server_windows')
Copy-Directory -Source (Join-Path $compiled 'CERTIFICADO_INSTALACAO_MAQUINAS') -Destination (Join-Path $package 'CERTIFICADO_INSTALACAO_MAQUINAS')
$certificateZip = Join-Path $compiled 'CERTIFICADO_INSTALACAO_MAQUINAS.zip'
if (-not (Test-Path -LiteralPath $certificateZip -PathType Leaf)) {
  throw "Pacote de certificado publico ausente: $certificateZip"
}
Copy-Item -LiteralPath $certificateZip -Destination (Join-Path $package 'CERTIFICADO_INSTALACAO_MAQUINAS.zip') -Force
Copy-Directory -Source (Join-Path $project 'portal_web') -Destination (Join-Path $package 'portal_web') -Extra @(
  '/XF', '.env', '*.db', '*.sqlite', '*.sqlite3', '*.log', '*.pid',
  'SEGREDOS_INICIAIS_ADMIN.txt', 'senha admin.txt', '*.pyc',
  '/XD', '.venv', '__pycache__', 'data', 'logs', 'storage', 'backups'
)
Copy-Directory -Source (Join-Path $project 'scripts') -Destination (Join-Path $package 'scripts')
Copy-Directory -Source (Join-Path $project 'certificados') -Destination (Join-Path $package 'certificados')

$integrationDestination = Join-Path $package 'integracoes'
foreach ($integrationName in @(
  'ADAPTADOR_SERIAL_USB_MCS99XX',
  'AUDLYTE',
  'AUDMAX',
  'BH-5390',
  'BS360E',
  'FATURAMENTO_SIRE',
  'hematologia',
  'KRISTAL_DATABASE_CLIENT',
  'kristal_sire',
  'LABMAX_PREMIUM',
  'URIVISION720'
)) {
  $source = Join-Path (Join-Path $project 'integracoes') $integrationName
  Copy-Directory -Source $source -Destination (Join-Path $integrationDestination $integrationName)
}
Copy-Directory -Source (Join-Path $project 'externos\hyper_terminal') -Destination (Join-Path $integrationDestination 'hyper_terminal')
Copy-Directory -Source (Join-Path $project 'dados_legados_kristal') -Destination (Join-Path $package 'dados_legados_kristal')
Copy-Directory -Source $DataSeedRoot -Destination (Join-Path $package 'data_seed') -Extra @('/XF', '*-wal', '*-shm')

$configSource = Join-Path $project 'config'
if (Test-Path -LiteralPath $configSource -PathType Container) {
  Copy-Directory -Source $configSource -Destination (Join-Path $package 'config')
}
foreach ($fileName in @(
  'INSTALAR_PRODUCAO_HMR_ADMIN.ps1',
  'LEIA_ME_CORRECAO_INSTALADOR_HMR.txt',
  'requirements-build.txt'
)) {
  $source = Join-Path $project $fileName
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Arquivo obrigatorio ausente: $source"
  }
  Copy-Item -LiteralPath $source -Destination (Join-Path $package $fileName)
}

$manifestItems = foreach ($file in Get-ChildItem -LiteralPath $package -Recurse -File) {
  if ($file.Name -in @('MANIFESTO_SHA256.json', 'MANIFESTO_SHA256.txt')) {
    continue
  }
  [ordered]@{
    caminho = $file.FullName.Substring($package.Length + 1)
    tamanho = $file.Length
    sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  }
}
$manifest = [ordered]@{
  sistema = 'KRISTAL LABORATORIAL'
  finalidade = 'PRODUCAO CORPORATIVA HMR'
  gerado_em = (Get-Date).ToString('o')
  arquivos = @($manifestItems)
  total_arquivos = @($manifestItems).Count
  total_bytes = [long](($manifestItems | Measure-Object -Property tamanho -Sum).Sum)
}
$manifestPath = Join-Path $package 'MANIFESTO_SHA256.json'
[IO.File]::WriteAllText(
  $manifestPath,
  ($manifest | ConvertTo-Json -Depth 6),
  [Text.UTF8Encoding]::new($false)
)
$manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
[IO.File]::WriteAllText(
  (Join-Path $package 'MANIFESTO_SHA256.txt'),
  ($manifestHash + '  MANIFESTO_SHA256.json' + [Environment]::NewLine),
  [Text.UTF8Encoding]::new($false)
)

Write-Host "PACOTE=$package" -ForegroundColor Green
Write-Host "MANIFESTO_SHA256=$manifestHash" -ForegroundColor Green
