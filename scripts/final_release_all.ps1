Write-Host "KRISTAL LABORATORIAL - Pipeline Final" -ForegroundColor Cyan

.\scripts\final_check.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

.\scripts\build_windows_release.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

.\scripts\compact_release.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Pipeline final concluido. Sistema pronto para empacotamento/instalacao." -ForegroundColor Green
