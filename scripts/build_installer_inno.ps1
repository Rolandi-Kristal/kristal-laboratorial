Write-Host "KRISTAL LABORATORIAL - Build Instalador .EXE" -ForegroundColor Cyan

$iss = "scripts\create_installer_inno.iss"
$isccPaths = @(
  "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)

$iscc = $null
foreach ($path in $isccPaths) {
  if (Test-Path $path) {
    $iscc = $path
    break
  }
}

if ($null -eq $iscc) {
  Write-Host "Inno Setup 6 nao encontrado. Instale o Inno Setup 6 para gerar o instalador .exe." -ForegroundColor Red
  exit 1
}

.\scripts\build_windows_release.ps1
if ($LASTEXITCODE -ne 0) {
  Write-Host "Build Windows falhou." -ForegroundColor Red
  exit $LASTEXITCODE
}

& $iscc $iss
if ($LASTEXITCODE -eq 0) {
  Write-Host "Instalador criado em: installer\KRISTAL_LABORATORIAL_Setup.exe" -ForegroundColor Green
}
