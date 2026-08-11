Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$portalDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$installRoot = Split-Path -Parent $portalDir
$serverExe = Join-Path $installRoot 'KRISTAL_SERVIDOR\KRISTAL_SERVIDOR.exe'
$envFile = Join-Path $portalDir '.env'
$logDir = Join-Path $portalDir 'logs'
$logFile = Join-Path $logDir 'servidor_autostart.log'
$pidFile = Join-Path $portalDir 'kristal_laboratorial_server.pid'

New-Item -ItemType Directory -Path $logDir -Force | Out-Null

function Write-KristalLog {
  param([Parameter(Mandatory = $true)][string]$Message)
  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
  Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $serverExe -PathType Leaf)) {
  throw "EXE do servidor nao encontrado: $serverExe"
}
if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
  throw "Configuracao .env do servidor nao encontrada: $envFile"
}

$existing = Get-Process -Name 'KRISTAL_SERVIDOR' -ErrorAction SilentlyContinue
if ($null -ne $existing) {
  Write-KristalLog "Servidor ja esta em execucao. PID(s): $($existing.Id -join ', ')"
  exit 0
}

Write-KristalLog 'Iniciando servidor compilado em modo de producao.'
$process = Start-Process -FilePath $serverExe -WorkingDirectory $portalDir -WindowStyle Hidden -PassThru
Set-Content -LiteralPath $pidFile -Value $process.Id -Encoding ASCII
Write-KristalLog "Servidor compilado iniciado. PID=$($process.Id)."