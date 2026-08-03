$ErrorActionPreference = 'Stop'
$envPath = Join-Path $PSScriptRoot '.env'
$port = 8787
if (Test-Path $envPath) {
  $line = Get-Content -Path $envPath | Where-Object { $_ -like 'KRISTAL_PORTAL_PORT=*' } | Select-Object -First 1
  if ($null -ne $line) {
    $value = $line.Split('=', 2)[1]
    if (-not [int]::TryParse($value, [ref]$port)) {
      throw "KRISTAL_PORTAL_PORT invalida no .env: $value"
    }
  }
}
$connections = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
if ($null -eq $connections) {
  Write-Host "Porta $port livre para KRISTAL LABORATORIAL."
  exit 0
}
$owners = $connections | Select-Object -ExpandProperty OwningProcess -Unique
Write-Host "Porta $port ja esta em uso. Processos: $($owners -join ', ')"
foreach ($pid in $owners) {
  Get-Process -Id $pid -ErrorAction SilentlyContinue | Select-Object Id,ProcessName,Path
}
exit 1
