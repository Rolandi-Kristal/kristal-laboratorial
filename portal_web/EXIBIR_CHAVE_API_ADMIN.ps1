param(
  [switch]$ConfirmarExibicao
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
  throw 'Execute este script em um PowerShell aberto como Administrador no servidor KRISTAL.'
}
if (-not $ConfirmarExibicao) {
  throw 'A exibicao exige o parametro -ConfirmarExibicao para evitar exposicao acidental.'
}

$envPath = Join-Path $PSScriptRoot '.env'
if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
  throw "Arquivo de configuracao do servidor nao encontrado: $envPath"
}

$prefix = 'KRISTAL_API_KEY='
$matches = @(Get-Content -LiteralPath $envPath |
  Where-Object { $_ -clike ($prefix + '*') })
if ($matches.Count -ne 1) {
  throw "O .env deve possuir exatamente uma definicao de KRISTAL_API_KEY; encontradas: $($matches.Count)."
}

$apiKey = $matches[0].Substring($prefix.Length).Trim()
try {
  if ([string]::IsNullOrWhiteSpace($apiKey) -or
      $apiKey.Length -lt 32 -or
      $apiKey -eq 'troque_por_uma_chave_forte') {
    throw 'KRISTAL_API_KEY ausente, curta ou ainda configurada com valor de exemplo.'
  }

  Write-Warning 'Dado sigiloso: use esta chave somente no instalador das estacoes autorizadas do HMR.'
  Write-Host 'KRISTAL_API_KEY do servidor:' -ForegroundColor Cyan
  [Console]::Out.WriteLine($apiKey)
  Write-Host 'Feche este PowerShell apos configurar as estacoes.' -ForegroundColor Yellow
} finally {
  $apiKey = $null
  $matches = @()
}
