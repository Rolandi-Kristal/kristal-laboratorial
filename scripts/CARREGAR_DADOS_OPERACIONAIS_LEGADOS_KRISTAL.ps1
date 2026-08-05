param(
  [string]$Root = 'D:\kristal_laboratorial'
)

$ErrorActionPreference = 'Stop'

$ScriptPath = Join-Path $Root 'scripts\carregar_dados_legados_operacional_kristal.py'
$RawScriptPath = Join-Path $Root 'scripts\carregar_todos_dados_brutos_legados_kristal.py'
$LegacyRoot = Join-Path $Root 'dados_legados_kristal'
$OperationalDb = Join-Path $Root 'data\kristal_laboratorial.db'

if (-not (Test-Path $ScriptPath)) {
  throw "Script de carga nao encontrado: $ScriptPath"
}
if (-not (Test-Path $RawScriptPath)) {
  throw "Script de carga bruta total nao encontrado: $RawScriptPath"
}
if (-not (Test-Path $LegacyRoot)) {
  throw "Pasta de dados legados nao encontrada: $LegacyRoot"
}

New-Item -ItemType Directory -Path (Split-Path -Parent $OperationalDb) -Force | Out-Null

Write-Host 'Etapa 1/2: carga operacional para telas e rotinas KRISTAL.' -ForegroundColor Cyan
python $ScriptPath --legacy-root $LegacyRoot --operational-db $OperationalDb

Write-Host 'Etapa 2/2: carga bruta total de todos os INSERTs dos RARs, sem excecao.' -ForegroundColor Cyan
python $RawScriptPath --legacy-root $LegacyRoot --operational-db $OperationalDb

Write-Host 'Carga de dados legados finalizada.' -ForegroundColor Green
Write-Host "Banco operacional: $OperationalDb" -ForegroundColor Green
