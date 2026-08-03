$ErrorActionPreference = 'Stop'
$portalDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path $portalDir 'logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logFile = Join-Path $logDir 'servidor_autostart.log'
$pidFile = Join-Path $portalDir 'kristal_laboratorial_server.pid'

function Write-KristalLog([string]$Message) {
  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
  Add-Content -Path $logFile -Value $line -Encoding UTF8
}

Set-Location $portalDir
Write-KristalLog 'Inicializacao automatica solicitada.'

python gerar_segredos_portal.py 2>&1 | ForEach-Object { Write-KristalLog $_ }
if ($LASTEXITCODE -ne 0) {
  throw 'Falha ao gerar/verificar segredos do portal.'
}

if (-not (Test-Path '.venv\Scripts\python.exe')) {
  Write-KristalLog 'Criando ambiente virtual Python.'
  python -m venv .venv 2>&1 | ForEach-Object { Write-KristalLog $_ }
  if ($LASTEXITCODE -ne 0) {
    throw 'Falha ao criar ambiente virtual Python.'
  }
}

Write-KristalLog 'Verificando dependencias do servidor.'
& '.\.venv\Scripts\python.exe' -c 'import fastapi, uvicorn, multipart' *> $null
$depsOk = $LASTEXITCODE -eq 0
if (-not $depsOk) {
  Write-KristalLog 'Instalando dependencias do servidor.'
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & '.\.venv\Scripts\python.exe' -m pip install -r requirements.txt *> (Join-Path $logDir 'pip_install.log')
  $pipExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference
  if ($pipExitCode -ne 0) {
    throw 'Falha ao instalar dependencias do servidor.'
  }
  Write-KristalLog 'Dependencias instaladas.'
}

$existing = Get-CimInstance Win32_Process | Where-Object {
  $_.CommandLine -like '*kristal_laboratorial*portal_web*main.py*' -or
  ($_.CommandLine -like '*portal_web*main.py*' -and $_.CommandLine -like '*python*')
}
if ($null -ne $existing) {
  Write-KristalLog "Servidor ja esta em execucao. PID(s): $($existing.ProcessId -join ', ')"
  exit 0
}

$env:KRISTAL_PORTAL_HOST = '0.0.0.0'
if (-not $env:KRISTAL_PORTAL_PORT) {
  $env:KRISTAL_PORTAL_PORT = '8787'
}

Write-KristalLog "Iniciando servidor em 0.0.0.0:$env:KRISTAL_PORTAL_PORT."
$process = Start-Process -FilePath '.\.venv\Scripts\python.exe' -ArgumentList 'main.py' -WorkingDirectory $portalDir -WindowStyle Hidden -PassThru
Set-Content -Path $pidFile -Value $process.Id -Encoding ASCII
Write-KristalLog "Servidor iniciado. PID=$($process.Id)."
