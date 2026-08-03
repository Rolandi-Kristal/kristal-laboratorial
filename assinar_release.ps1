$ErrorActionPreference = 'Stop'
$exe = 'C:\kristal_laboratorial\build\windows\x64\runner\Release\kristal_laboratorial.exe'
if (-not (Test-Path $exe)) {
  throw "EXE nao encontrado: $exe"
}
$cert = Get-ChildItem -Path Cert:\CurrentUser\My, Cert:\LocalMachine\My -CodeSigningCert |
  Where-Object { $_.Subject -like '*KRISTAL*' } |
  Sort-Object NotAfter -Descending |
  Select-Object -First 1
if ($null -eq $cert) {
  throw 'Nenhum certificado KRISTAL de assinatura de codigo encontrado.'
}
Set-AuthenticodeSignature -FilePath $exe -Certificate $cert -HashAlgorithm SHA256 | Out-Null
$signature = Get-AuthenticodeSignature -FilePath $exe
if ($signature.Status -ne 'Valid') {
  throw "Assinatura invalida: $($signature.Status) - $($signature.StatusMessage)"
}
Write-Host "EXE assinado e validado: $($cert.Subject)"
