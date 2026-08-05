param(
  [string]$Destino = 'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial',
  [switch]$ConfigurarServidor,
  [switch]$CriarAtalhoDesktop
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PacoteRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppOrigem = Join-Path $PacoteRoot 'app_windows'
$PortalOrigem = Join-Path $PacoteRoot 'portal_web'
$ConfigOrigem = Join-Path $PacoteRoot 'config'
$ScriptsOrigem = Join-Path $PacoteRoot 'scripts'
$LegadoOrigem = Join-Path $PacoteRoot 'dados_legados_kristal'
$CertificadosOrigem = Join-Path $PacoteRoot 'certificados'

$AppDestino = Join-Path $Destino 'KRISTAL_LABORATORIAL'
$PortalDestino = Join-Path $Destino 'portal_web'
$ConfigDestino = Join-Path $Destino 'config'
$ScriptsDestino = Join-Path $Destino 'scripts'
$LegadoDestino = Join-Path $Destino 'dados_legados_kristal'
$CertificadosDestino = Join-Path $Destino 'certificados'
$BackupRoot = Join-Path $Destino ('backups\pre_update_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-Step {
  param([Parameter(Mandatory = $true)][string]$Message)
  Write-Host "`n[KRISTAL] $Message" -ForegroundColor Cyan
}

function Get-NormalizedPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
}

function Test-SamePath {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )
  return [string]::Equals(
    (Get-NormalizedPath -Path $Source),
    (Get-NormalizedPath -Path $Destination),
    [System.StringComparison]::OrdinalIgnoreCase
  )
}

function Test-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-RobocopyDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [string[]]$AdditionalArguments = @()
  )

  if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    Write-Host "Ignorado; origem inexistente: $Source" -ForegroundColor DarkYellow
    return
  }

  if (Test-SamePath -Source $Source -Destination $Destination) {
    Write-Host "Origem e destino iguais; copia ignorada com seguranca: $Source" -ForegroundColor DarkYellow
    return
  }

  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  $arguments = @($Source, $Destination, '/E', '/COPY:DAT', '/DCOPY:DA', '/R:2', '/W:2', '/XJ')
  $arguments += $AdditionalArguments
  & robocopy @arguments | Out-Host
  $robocopyExitCode = $LASTEXITCODE
  if ($robocopyExitCode -gt 7) {
    throw "Robocopy falhou da origem '$Source' para '$Destination'. Codigo: $robocopyExitCode"
  }
}

function Stop-KristalProcesses {
  Write-Step -Message 'Interrompendo processos da KRISTAL para obter backup consistente'
  Get-Process -Name 'kristal_laboratorial' -ErrorAction SilentlyContinue | Stop-Process -Force

  $pythonServers = Get-CimInstance Win32_Process -ErrorAction Stop |
    Where-Object { $null -ne $_.CommandLine -and $_.CommandLine -like '*portal_web*main.py*' }
  foreach ($process in $pythonServers) {
    Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
  }
}

function Backup-ExistingData {
  Write-Step -Message "Criando backup anterior a atualizacao em $BackupRoot"
  New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null

  $items = @(
    'portal_web\.env',
    'portal_web\data',
    'portal_web\logs',
    'portal_web\storage',
    'portal_web\backups',
    'data',
    'logs',
    'exports',
    'certificados',
    'relatorios'
  )

  foreach ($relativePath in $items) {
    $source = Join-Path $Destino $relativePath
    if (-not (Test-Path -LiteralPath $source)) {
      continue
    }

    $backupDestination = Join-Path $BackupRoot $relativePath
    Write-Host "Preservando: $relativePath"
    if (Test-Path -LiteralPath $source -PathType Container) {
      Invoke-RobocopyDirectory -Source $source -Destination $backupDestination
    } else {
      $backupParent = Split-Path -Parent $backupDestination
      New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
      Copy-Item -LiteralPath $source -Destination $backupDestination -Force
    }
  }

  Write-Host 'Backups historicos existentes foram mantidos no local original.' -ForegroundColor Green
}

function Sync-PackageDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [string[]]$AdditionalArguments = @()
  )
  Write-Step -Message "Atualizando $Name"
  Invoke-RobocopyDirectory -Source $Source -Destination $Destination -AdditionalArguments $AdditionalArguments
}

if (-not (Test-Admin)) {
  throw 'Execute este script como Administrador no servidor ou estacao do HMR.'
}

if (-not (Test-Path -LiteralPath (Join-Path $AppOrigem 'kristal_laboratorial.exe') -PathType Leaf)) {
  throw "Aplicativo Windows nao encontrado em $AppOrigem"
}
if (-not (Test-Path -LiteralPath (Join-Path $PortalOrigem 'main.py') -PathType Leaf)) {
  throw "Portal web nao encontrado em $PortalOrigem"
}
if (-not (Get-Command robocopy -ErrorAction SilentlyContinue)) {
  throw 'Robocopy nao foi encontrado no Windows.'
}

Write-Step -Message "Iniciando atualizacao. Pacote: $PacoteRoot | Destino: $Destino"
New-Item -ItemType Directory -Path $Destino -Force | Out-Null

Stop-KristalProcesses
Backup-ExistingData

Sync-PackageDirectory -Name 'aplicativo Windows' -Source $AppOrigem -Destination $AppDestino
Sync-PackageDirectory -Name 'portal web' -Source $PortalOrigem -Destination $PortalDestino -AdditionalArguments @(
  '/XF', '.env', '*.db', '*.sqlite', '*.sqlite3', '*.log', '*.pid',
  'SEGREDOS_INICIAIS_ADMIN.txt', 'senha admin.txt', '*.pyc',
  '/XD', '.venv', '__pycache__', 'data', 'logs', 'storage', 'backups'
)
Sync-PackageDirectory -Name 'configuracoes' -Source $ConfigOrigem -Destination $ConfigDestino
Sync-PackageDirectory -Name 'scripts operacionais' -Source $ScriptsOrigem -Destination $ScriptsDestino
Sync-PackageDirectory -Name 'dados legados preservados' -Source $LegadoOrigem -Destination $LegadoDestino
Sync-PackageDirectory -Name 'certificados publicos' -Source $CertificadosOrigem -Destination $CertificadosDestino

foreach ($directory in @('data', 'logs', 'exports', 'exports\sire', 'backups', 'certificados', 'drivers', 'relatorios')) {
  New-Item -ItemType Directory -Path (Join-Path $Destino $directory) -Force | Out-Null
}
foreach ($directory in @('data', 'logs', 'storage', 'backups')) {
  New-Item -ItemType Directory -Path (Join-Path $PortalDestino $directory) -Force | Out-Null
}

Write-Step -Message 'Validando configuracao unica do superusuario'
$superEnv = Join-Path $ConfigDestino 'superusuario.env'
if (-not (Test-Path -LiteralPath $superEnv -PathType Leaf)) {
  throw "Configuracao unica do superusuario nao encontrada: $superEnv"
}
$superPasswordLine = Get-Content -LiteralPath $superEnv |
  Where-Object { $_ -like 'KRISTAL_SUPERUSER_PASSWORD=*' } |
  Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($superPasswordLine)) {
  throw "KRISTAL_SUPERUSER_PASSWORD nao definida em $superEnv"
}
$superPassword = $superPasswordLine.Substring('KRISTAL_SUPERUSER_PASSWORD='.Length)
if ([string]::IsNullOrWhiteSpace($superPassword)) {
  throw "KRISTAL_SUPERUSER_PASSWORD vazia em $superEnv"
}

$envPath = Join-Path $PortalDestino '.env'
if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
  $envExample = Join-Path $PortalDestino '.env.example'
  if (-not (Test-Path -LiteralPath $envExample -PathType Leaf)) {
    throw "Nem .env nem .env.example foram encontrados em $PortalDestino"
  }
  Copy-Item -LiteralPath $envExample -Destination $envPath -Force
}

$envLines = @(Get-Content -LiteralPath $envPath)
$envLines = @($envLines | Where-Object { $_ -notmatch '^KRISTAL_SUPERUSER_PASSWORD=' })
$envLines += ('KRISTAL_SUPERUSER_PASSWORD=' + $superPassword)
Set-Content -LiteralPath $envPath -Value $envLines -Encoding UTF8

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $pythonCommand) {
  throw 'Python nao foi encontrado no PATH do servidor.'
}

Write-Step -Message 'Gerando e validando segredos do portal'
Push-Location $PortalDestino
try {
  & $pythonCommand.Source 'gerar_segredos_portal.py'
  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao gerar segredos do portal. Codigo: $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

Write-Step -Message 'Validando assinatura digital do aplicativo'
$certificatePath = Join-Path $CertificadosDestino 'KRISTAL_LABORATORIAL_ASSINATURA_PUBLICA.cer'
if (Test-Path -LiteralPath $certificatePath -PathType Leaf) {
  Import-Certificate -FilePath $certificatePath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
  Import-Certificate -FilePath $certificatePath -CertStoreLocation Cert:\LocalMachine\TrustedPublisher | Out-Null
}

$applicationPath = Join-Path $AppDestino 'kristal_laboratorial.exe'
$signature = Get-AuthenticodeSignature -FilePath $applicationPath
if ($signature.Status -ne 'Valid') {
  throw "Assinatura do EXE invalida: $($signature.Status) - $($signature.StatusMessage)"
}

if ($CriarAtalhoDesktop) {
  Write-Step -Message 'Criando atalho na area de trabalho publica'
  $desktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
  $shortcutPath = Join-Path $desktop 'KRISTAL LABORATORIAL.lnk'
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $applicationPath
  $shortcut.WorkingDirectory = $AppDestino
  $shortcut.IconLocation = $applicationPath
  $shortcut.Save()
}

if ($ConfigurarServidor) {
  Write-Step -Message 'Configurando firewall, backup automatico e inicializacao do servidor'
  foreach ($scriptName in @(
    'configurar_firewall_hmr.ps1',
    'instalar_backup_automatico_windows.ps1',
    'instalar_autostart_windows.ps1'
  )) {
    $scriptPath = Join-Path $PortalDestino $scriptName
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
      throw "Script obrigatorio do servidor nao encontrado: $scriptPath"
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath
    if ($LASTEXITCODE -ne 0) {
      throw "Falha na execucao de $scriptName. Codigo: $LASTEXITCODE"
    }
  }
}

Write-Host "`nKRISTAL LABORATORIAL instalada e atualizada com sucesso." -ForegroundColor Green
Write-Host "Backup anterior: $BackupRoot" -ForegroundColor Green
Write-Host "Aplicativo: $applicationPath" -ForegroundColor Green
Write-Host "Servidor web: $PortalDestino" -ForegroundColor Green
Write-Host 'Portal: http://10.4.169.64:8787' -ForegroundColor Green
Write-Host 'Execute a carga de dados somente depois desta mensagem de sucesso.' -ForegroundColor Yellow
