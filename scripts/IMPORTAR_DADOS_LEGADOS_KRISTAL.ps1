param(
  [Parameter(Mandatory = $true)]
  [string]$Origem,
  [string]$Destino = 'D:\kristal_laboratorial',
  [string]$RarExe = ''
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonScript = Join-Path $scriptDir 'importar_dados_legados_kristal.py'
if (-not (Test-Path $pythonScript)) {
  throw "Importador Python nao encontrado: $pythonScript"
}
if (-not (Test-Path $Origem)) {
  throw "Pasta de origem nao encontrada: $Origem"
}
New-Item -ItemType Directory -Path $Destino -Force | Out-Null
$logDir = Join-Path $Destino 'logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logFile = Join-Path $logDir ('importacao_dados_legados_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')

$argsList = @($pythonScript, '--source-dir', $Origem, '--dest-root', $Destino)
if ($RarExe.Trim()) {
  $argsList += @('--rar-exe', $RarExe)
}

Write-Host 'KRISTAL LABORATORIAL - Importacao de dados legados' -ForegroundColor Cyan
Write-Host "Origem: $Origem"
Write-Host "Destino: $Destino"
Write-Host "Log: $logFile"

$process = Start-Process -FilePath 'python' -ArgumentList $argsList -Wait -PassThru -NoNewWindow -RedirectStandardOutput $logFile -RedirectStandardError ($logFile + '.err')
if ($process.ExitCode -ne 0) {
  Get-Content ($logFile + '.err') -ErrorAction SilentlyContinue
  throw "Importacao falhou com codigo $($process.ExitCode). Verifique: $logFile"
}
Get-Content $logFile
Write-Host 'Importacao finalizada. Dados preservados permanentemente no repositório KRISTAL.' -ForegroundColor Green