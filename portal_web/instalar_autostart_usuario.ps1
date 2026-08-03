$ErrorActionPreference = 'Stop'
$portalDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startupDir = [Environment]::GetFolderPath('Startup')
if ([string]::IsNullOrWhiteSpace($startupDir)) {
  throw 'Pasta Startup do usuario nao encontrada.'
}
$shortcutPath = Join-Path $startupDir 'KRISTAL LABORATORIAL Servidor HMR.lnk'
$target = 'powershell.exe'
$scriptPath = Join-Path $portalDir 'iniciar_servidor_background.ps1'
if (-not (Test-Path $scriptPath)) {
  throw "Script de inicializacao nao encontrado: $scriptPath"
}
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $target
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$shortcut.WorkingDirectory = $portalDir
$shortcut.Description = 'Inicia automaticamente o servidor web da KRISTAL LABORATORIAL.'
$shortcut.Save()
Write-Host "Inicializacao automatica configurada para o usuario atual: $shortcutPath"
