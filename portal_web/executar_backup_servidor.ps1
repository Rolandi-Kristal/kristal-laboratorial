Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

$envPath = Join-Path $PSScriptRoot '.env'
if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
  throw "Configuracao do servidor ausente: $envPath"
}

$values = @{}
foreach ($line in Get-Content -LiteralPath $envPath) {
  $clean = $line.Trim()
  if ([string]::IsNullOrWhiteSpace($clean) -or
      $clean.StartsWith('#') -or
      -not $clean.Contains('=')) {
    continue
  }
  $separator = $clean.IndexOf('=')
  $values[$clean.Substring(0, $separator).Trim()] = $clean.Substring($separator + 1).Trim()
}

$apiKey = [string]$values['KRISTAL_API_KEY']
if ([string]::IsNullOrWhiteSpace($apiKey)) {
  throw 'KRISTAL_API_KEY ausente no .env.'
}
$port = [string]$values['KRISTAL_PORTAL_PORT']
if ([string]::IsNullOrWhiteSpace($port)) {
  $port = '8787'
}
$requireTls = [string]$values['KRISTAL_REQUIRE_TLS']
$scheme = if ($requireTls.Trim().ToLowerInvariant() -in @('1', 'sim', 'true', 'yes')) { 'https' } else { 'http' }
$url = "${scheme}://127.0.0.1:$port/api/server/backup"
$headers = @{ 'X-API-Key' = $apiKey; 'Accept' = 'application/json' }
try {
  $result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -TimeoutSec 16200
} catch [System.Net.WebException] {
  throw "Falha HTTP no backup automatico: $($_.Exception.Message)"
} catch [System.Net.Http.HttpRequestException] {
  throw "Falha de rede no backup automatico: $($_.Exception.Message)"
}
if ($result.status -ne 'backup_completo_criado') {
  throw "Resposta inesperada do backup: $($result.status)"
}
$result | ConvertTo-Json -Depth 8