$ErrorActionPreference = 'Stop'
$expectedThumbprint = '41A4507029802AC7A0BADBA496F7BD532E03748A'
$certPath = Join-Path $PSScriptRoot 'KRISTAL_LABORATORIAL_ASSINATURA_PUBLICA.cer'
if (-not (Test-Path -LiteralPath $certPath -PathType Leaf)) {
  throw "Certificado nao encontrado: $certPath"
}
$certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($certPath)
if ($certificate.Thumbprint -ne $expectedThumbprint) {
  throw "Certificado rejeitado: thumbprint inesperado $($certificate.Thumbprint)."
}
if ($certificate.HasPrivateKey) {
  throw 'Certificado rejeitado: o pacote de instalacao nao pode conter chave privada.'
}
if ((Get-Date) -lt $certificate.NotBefore -or (Get-Date) -gt $certificate.NotAfter) {
  throw 'Certificado rejeitado: periodo de validade invalido.'
}
$codeSigningOid = '1.3.6.1.5.5.7.3.3'
$hasCodeSigningEku = $certificate.Extensions |
  Where-Object { $_.Oid.Value -eq '2.5.29.37' } |
  ForEach-Object { $_.EnhancedKeyUsages } |
  Where-Object { $_.Value -eq $codeSigningOid }
if ($null -eq $hasCodeSigningEku) {
  throw 'Certificado rejeitado: finalidade de assinatura de codigo ausente.'
}
Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\CurrentUser\Root | Out-Null
Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\CurrentUser\TrustedPublisher | Out-Null
Write-Host 'Certificado KRISTAL validado e instalado em CurrentUser\Root e CurrentUser\TrustedPublisher.'