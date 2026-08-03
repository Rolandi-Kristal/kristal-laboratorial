Write-Host "KRISTAL LABORATORIAL - Verificacao final" -ForegroundColor Cyan

flutter clean
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter analyze
if ($LASTEXITCODE -ne 0) {
  Write-Host "ERROS encontrados no flutter analyze." -ForegroundColor Red
  exit $LASTEXITCODE
}

flutter test
if ($LASTEXITCODE -ne 0) {
  Write-Host "Testes falharam." -ForegroundColor Yellow
}

Write-Host "Verificacao final concluida." -ForegroundColor Green
