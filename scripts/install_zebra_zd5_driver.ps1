param(
  [string]$DriverRoot = 'D:\kristal_laboratorial\drivers\impressoras\zebra_zd5\ZD5-1-17-7415',
  [switch]$AllowPrinterInstaller
)

$ErrorActionPreference = 'Stop'
function Write-KristalLog([string]$Message, [string]$Level = 'INFO') {
  $logDir = Join-Path $env:ProgramData 'KRISTAL LABORATORIAL\logs'
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  $line = '[{0}][{1}] {2}' -f (Get-Date).ToString('s'), $Level, $Message
  Add-Content -Path (Join-Path $logDir 'zebra_zd5_driver_install.log') -Value $line -Encoding UTF8
  Write-Host $line
}
function Test-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
  Write-KristalLog 'Execute como Administrador para instalar driver de impressora.' 'ERROR'
  exit 740
}
if (-not (Test-Path $DriverRoot)) {
  Write-KristalLog "Pasta do driver Zebra/ZD5 nao encontrada: $DriverRoot" 'ERROR'
  exit 2
}

$inf = Get-ChildItem -Path $DriverRoot -Recurse -Filter 'ZBRN.inf' -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $inf) {
  Write-KristalLog 'ZBRN.inf nao encontrado no pacote Zebra/ZD5.' 'ERROR'
  exit 3
}

Write-KristalLog "Instalando INF Zebra/ZD5 via pnputil: $($inf.FullName)"
$proc = Start-Process -FilePath 'pnputil.exe' -ArgumentList "/add-driver `"$($inf.FullName)`" /install" -Wait -PassThru -WindowStyle Hidden
Write-KristalLog "pnputil finalizado. Codigo=$($proc.ExitCode)"

if ($AllowPrinterInstaller) {
  $installer = Get-ChildItem -Path $DriverRoot -Recurse -Filter 'PrnInst.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -ne $installer) {
    Write-KristalLog "Executando instalador Zebra autorizado: $($installer.FullName)"
    $procExe = Start-Process -FilePath $installer.FullName -WorkingDirectory $installer.DirectoryName -Wait -PassThru
    Write-KristalLog "PrnInst finalizado. Codigo=$($procExe.ExitCode)"
  } else {
    Write-KristalLog 'PrnInst.exe nao encontrado; INF ja foi processado.' 'WARN'
  }
}

Write-KristalLog 'Instalacao Zebra/ZD5 concluida.'
exit 0
