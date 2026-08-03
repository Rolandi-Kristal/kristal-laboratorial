Write-Host "KRISTAL LABORATORIAL - Build Windows Release" -ForegroundColor Cyan

flutter clean
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter analyze
if ($LASTEXITCODE -ne 0) {
  Write-Host "flutter analyze encontrou erros. Corrija antes do build." -ForegroundColor Red
  exit $LASTEXITCODE
}

flutter build windows --release
if ($LASTEXITCODE -eq 0) {
  Write-Host "Build concluido em: build\windows\x64\runner\Release" -ForegroundColor Green
}
