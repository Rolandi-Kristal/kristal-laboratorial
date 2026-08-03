$ErrorActionPreference = 'Stop'
$startupDir = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupDir 'KRISTAL LABORATORIAL Servidor HMR.lnk'
if (Test-Path $shortcutPath) {
  Remove-Item -Path $shortcutPath -Force
  Write-Host "Atalho removido: $shortcutPath"
} else {
  Write-Host "Atalho nao encontrado: $shortcutPath"
}
