$releasePath = "build\windows\x64\runner\Release"
$zipPath = "build\KRISTAL_LABORATORIAL_WINDOWS_RELEASE.zip"

if (!(Test-Path $releasePath)) {
  Write-Host "Pasta de release nao encontrada. Rode build_windows_release.ps1 primeiro." -ForegroundColor Red
  exit 1
}

if (Test-Path $zipPath) {
  Remove-Item $zipPath -Force
}

Compress-Archive -Path "$releasePath\*" -DestinationPath $zipPath
Write-Host "Pacote criado: $zipPath" -ForegroundColor Green
