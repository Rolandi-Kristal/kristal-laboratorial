$ErrorActionPreference = 'Stop'
$ruleName = 'KRISTAL LABORATORIAL Portal HMR 8787'
$port = 8787

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Execute este script como Administrador para liberar a porta no Firewall do Windows.'
}

$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($null -eq $existing) {
  New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $port -Profile Domain,Private | Out-Null
  Write-Host "Regra criada: TCP $port liberada para perfis Domain e Private."
} else {
  Set-NetFirewallRule -DisplayName $ruleName -Enabled True -Direction Inbound -Action Allow -Profile Domain,Private | Out-Null
  Write-Host "Regra existente reativada: TCP $port liberada."
}
