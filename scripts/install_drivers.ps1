param(
  [string]$AppDir = "",
  [switch]$Quiet,
  [switch]$AllowUnknownExe
)

$ErrorActionPreference = "Continue"

function Write-KristalLog {
  param([string]$Message, [string]$Level = "INFO")

  $logDir = Join-Path $env:ProgramData "KRISTAL LABORATORIAL\logs"
  if (!(Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
  }

  $logFile = Join-Path $logDir "driver_install.log"
  $line = "[{0}][{1}] {2}" -f (Get-Date).ToString("s"), $Level, $Message
  Add-Content -Path $logFile -Value $line -Encoding UTF8

  if (-not $Quiet) {
    Write-Host $line
  }
}

function Test-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-InstallerArgs {
  param(
    [string]$FileName,
    $Manifest
  )

  try {
    $argsMap = $Manifest.knownInstallerArgs
    if ($null -ne $argsMap) {
      $property = $argsMap.PSObject.Properties | Where-Object { $_.Name -ieq $FileName } | Select-Object -First 1
      if ($null -ne $property) {
        return [string]$property.Value
      }
    }
  } catch {
    return ""
  }

  return ""
}

function Test-KnownInstaller {
  param(
    [string]$FileName,
    $Manifest
  )

  if ($null -eq $Manifest.knownInstallerNames) {
    return $false
  }

  foreach ($name in $Manifest.knownInstallerNames) {
    if ($name -ieq $FileName) {
      return $true
    }
  }

  return $false
}

if ([string]::IsNullOrWhiteSpace($AppDir)) {
  $AppDir = Split-Path -Parent $PSScriptRoot
}

Write-KristalLog "KRISTAL LABORATORIAL - instalação automática de drivers iniciada."
Write-KristalLog "AppDir=$AppDir"

if (!(Test-Admin)) {
  Write-KristalLog "Permissão de administrador necessária para instalar drivers. Execute como administrador." "ERROR"
  exit 740
}

$manifestPath = Join-Path $AppDir "drivers\DriverManifest.json"

if (!(Test-Path $manifestPath)) {
  Write-KristalLog "DriverManifest.json não encontrado: $manifestPath" "ERROR"
  exit 2
}

try {
  $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
  Write-KristalLog "Falha ao ler DriverManifest.json: $_" "ERROR"
  exit 3
}

$driverRoot = Join-Path $AppDir $manifest.driverRoot
$installedDir = Join-Path $env:ProgramData "KRISTAL LABORATORIAL\drivers"

if (!(Test-Path $driverRoot)) {
  Write-KristalLog "Pasta de drivers não encontrada: $driverRoot" "ERROR"
  exit 4
}

if (!(Test-Path $installedDir)) {
  New-Item -Path $installedDir -ItemType Directory -Force | Out-Null
}

Write-KristalLog "Raiz dos drivers: $driverRoot"
Write-KristalLog "Destino controlado: $installedDir"

try {
  Copy-Item -Path (Join-Path $driverRoot "*") -Destination $installedDir -Recurse -Force
  Write-KristalLog "Drivers copiados para ProgramData."
} catch {
  Write-KristalLog "Falha ao copiar drivers para ProgramData: $_" "ERROR"
}

# 1) Instala todos os .INF via pnputil
if ($manifest.policy.installInfWithPnPUtil -eq $true) {
  $infFiles = Get-ChildItem -Path $driverRoot -Recurse -Filter "*.inf" -File -ErrorAction SilentlyContinue

  if ($infFiles.Count -eq 0) {
    Write-KristalLog "Nenhum arquivo INF encontrado." "WARN"
  }

  foreach ($inf in $infFiles) {
    Write-KristalLog "Instalando INF via pnputil: $($inf.FullName)"

    try {
      $proc = Start-Process -FilePath "pnputil.exe" -ArgumentList "/add-driver `"$($inf.FullName)`" /install" -Wait -PassThru -WindowStyle Hidden
      Write-KristalLog "pnputil finalizado. Código=$($proc.ExitCode) Arquivo=$($inf.Name)"
    } catch {
      Write-KristalLog "Falha ao instalar INF $($inf.FullName): $_" "ERROR"
    }
  }
}

# 2) Instala todos os .MSI de forma silenciosa
if ($manifest.policy.installMsiQuiet -eq $true) {
  $msiFiles = Get-ChildItem -Path $driverRoot -Recurse -Filter "*.msi" -File -ErrorAction SilentlyContinue

  foreach ($msi in $msiFiles) {
    Write-KristalLog "Instalando MSI silencioso: $($msi.FullName)"

    try {
      $args = "/i `"$($msi.FullName)`" /qn /norestart"
      $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait -PassThru
      Write-KristalLog "msiexec finalizado. Código=$($proc.ExitCode) Arquivo=$($msi.Name)"
    } catch {
      Write-KristalLog "Falha ao instalar MSI $($msi.FullName): $_" "ERROR"
    }
  }
}

# 3) Executa apenas instaladores EXE conhecidos por padrão
$exeFiles = Get-ChildItem -Path $driverRoot -Recurse -Filter "*.exe" -File -ErrorAction SilentlyContinue

foreach ($exe in $exeFiles) {
  $isKnown = Test-KnownInstaller -FileName $exe.Name -Manifest $manifest

  if (($manifest.policy.runKnownInstallersOnly -eq $true) -and (-not $isKnown) -and (-not $AllowUnknownExe)) {
    Write-KristalLog "EXE ignorado por segurança: $($exe.FullName)" "WARN"
    continue
  }

  $args = Get-InstallerArgs -FileName $exe.Name -Manifest $manifest

  Write-KristalLog "Executando instalador EXE: $($exe.FullName) $args"

  try {
    if ([string]::IsNullOrWhiteSpace($args)) {
      $proc = Start-Process -FilePath $exe.FullName -Wait -PassThru
    } else {
      $proc = Start-Process -FilePath $exe.FullName -ArgumentList $args -Wait -PassThru
    }

    Write-KristalLog "EXE finalizado. Código=$($proc.ExitCode) Arquivo=$($exe.Name)"
  } catch {
    Write-KristalLog "Falha ao executar EXE $($exe.FullName): $_" "ERROR"
  }
}

# 4) Registra resumo
$summary = @{
  DateTime = (Get-Date).ToString("s")
  AppDir = $AppDir
  DriverRoot = $driverRoot
  ProgramDataDriverCopy = $installedDir
  InfCount = @(Get-ChildItem -Path $driverRoot -Recurse -Filter "*.inf" -File -ErrorAction SilentlyContinue).Count
  MsiCount = @(Get-ChildItem -Path $driverRoot -Recurse -Filter "*.msi" -File -ErrorAction SilentlyContinue).Count
  ExeCount = @(Get-ChildItem -Path $driverRoot -Recurse -Filter "*.exe" -File -ErrorAction SilentlyContinue).Count
  DllCount = @(Get-ChildItem -Path $driverRoot -Recurse -Filter "*.dll" -File -ErrorAction SilentlyContinue).Count
  DrvCount = @(Get-ChildItem -Path $driverRoot -Recurse -Filter "*.drv" -File -ErrorAction SilentlyContinue).Count
}

$summaryPath = Join-Path $env:ProgramData "KRISTAL LABORATORIAL\logs\driver_install_summary.json"
$summary | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8

Write-KristalLog "Resumo salvo em: $summaryPath"
Write-KristalLog "Instalação automática de drivers finalizada."
exit 0
