param(
  [string[]]$ExecutablePaths = @(
    'D:\KRISTAL LABORATORIAL SISTEMA\COMPILADOS\app_windows\kristal_laboratorial.exe',
    'D:\KRISTAL LABORATORIAL SISTEMA\COMPILADOS\server_windows\KRISTAL_SERVIDOR.exe'
  )
)

$ErrorActionPreference = 'Stop'

$cert = Get-ChildItem -Path Cert:\CurrentUser\My, Cert:\LocalMachine\My -CodeSigningCert |
  Where-Object {
    $_.Subject -eq 'CN=KRISTAL LABORATORIAL, O=Hospital Militar de Resende, C=BR' -and
    $_.HasPrivateKey -and
    $_.NotAfter -gt (Get-Date).AddDays(30)
  } |
  Sort-Object NotAfter -Descending |
  Select-Object -First 1
if ($null -eq $cert) {
  throw 'Nenhum certificado KRISTAL de assinatura de codigo encontrado.'
}

foreach ($exe in $ExecutablePaths) {
  $resolved = [IO.Path]::GetFullPath($exe)
  if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    throw "EXE nao encontrado: $resolved"
  }
  Set-AuthenticodeSignature -FilePath $resolved -Certificate $cert -HashAlgorithm SHA256 | Out-Null
  $signature = Get-AuthenticodeSignature -FilePath $resolved
  if ($signature.Status -ne 'Valid') {
    throw ('Assinatura invalida em {0}: {1} - {2}' -f $resolved, $signature.Status, $signature.StatusMessage)
  }
  Write-Host "EXE assinado e validado: $resolved | $($cert.Subject)"
}