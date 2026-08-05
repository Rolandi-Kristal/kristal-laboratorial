param(
  [string]$Root = 'D:\kristal_laboratorial'
)

$ErrorActionPreference = 'Stop'

$ScriptPath = Join-Path $Root 'scripts\carregar_dados_legados_operacional_kristal.py'
$LegacyRoot = Join-Path $Root 'dados_legados_kristal'
$OperationalDb = Join-Path $Root 'data\kristal_laboratorial.db'

if (-not (Test-Path $ScriptPath)) {
  throw "Script de carga nao encontrado: $ScriptPath"
}
if (-not (Test-Path $LegacyRoot)) {
  throw "Pasta de dados legados nao encontrada: $LegacyRoot"
}

New-Item -ItemType Directory -Path (Split-Path -Parent $OperationalDb) -Force | Out-Null

python $ScriptPath --legacy-root $LegacyRoot --operational-db $OperationalDb

Write-Host 'Carga operacional de dados legados finalizada.' -ForegroundColor Green
Write-Host "Banco operacional: $OperationalDb" -ForegroundColor Green
