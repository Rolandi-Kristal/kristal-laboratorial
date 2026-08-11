param(
  [string]$ProjectRoot = 'C:\kristal_laboratorial',
  [string]$OutputRoot = 'D:\KRISTAL LABORATORIAL SISTEMA\COMPILADOS'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$project = [IO.Path]::GetFullPath($ProjectRoot)
$output = [IO.Path]::GetFullPath($OutputRoot)
$destination = Join-Path $output 'CERTIFICADO_INSTALACAO_MAQUINAS'
$zipPath = Join-Path $output 'CERTIFICADO_INSTALACAO_MAQUINAS.zip'
$subject = 'CN=KRISTAL LABORATORIAL, O=Hospital Militar de Resende, C=BR'

if (-not $destination.StartsWith($output, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Destino de certificado fora da raiz autorizada: $destination"
}

$certificate = Get-ChildItem Cert:\CurrentUser\My, Cert:\LocalMachine\My -CodeSigningCert |
  Where-Object {
    $_.Subject -eq $subject -and
    $_.HasPrivateKey -and
    $_.NotAfter -gt (Get-Date).AddDays(30)
  } |
  Sort-Object NotAfter -Descending |
  Select-Object -First 1
if ($null -eq $certificate) {
  throw 'Certificado de assinatura KRISTAL com chave privada nao encontrado.'
}

if (Test-Path -LiteralPath $destination) {
  Remove-Item -LiteralPath $destination -Recurse -Force
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null

$publicCertificate = Join-Path $destination 'KRISTAL_LABORATORIAL_ASSINATURA_PUBLICA.cer'
Export-Certificate -Cert $certificate -FilePath $publicCertificate -Type CERT -Force | Out-Null

$sourceDirectory = Join-Path $project 'certificados'
foreach ($name in @(
  'INSTALAR_CERTIFICADO_KRISTAL_ADMIN.bat',
  'instalar_certificado_kristal_maquina.ps1',
  'instalar_certificado_kristal_usuario.ps1',
  'CERTIFICADO_ASSINATURA_INFO.txt'
)) {
  $source = Join-Path $sourceDirectory $name
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Arquivo publico obrigatorio ausente: $source"
  }
  Copy-Item -LiteralPath $source -Destination (Join-Path $destination $name) -Force
}

$exported = [Security.Cryptography.X509Certificates.X509Certificate2]::new($publicCertificate)
if ($exported.Thumbprint -ne $certificate.Thumbprint) {
  throw 'Thumbprint do certificado exportado diverge do certificado de assinatura.'
}
if ($exported.HasPrivateKey) {
  throw 'Falha critica: o pacote publico nao pode conter chave privada.'
}

$files = foreach ($file in Get-ChildItem -LiteralPath $destination -File) {
  [ordered]@{
    arquivo = $file.Name
    tamanho = $file.Length
    sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  }
}
$manifest = [ordered]@{
  sistema = 'KRISTAL LABORATORIAL'
  finalidade = 'INSTALACAO DO CERTIFICADO PUBLICO NAS ESTACOES HMR'
  gerado_em = (Get-Date).ToString('o')
  subject = $exported.Subject
  issuer = $exported.Issuer
  thumbprint = $exported.Thumbprint
  validade_inicio = $exported.NotBefore.ToString('o')
  validade_fim = $exported.NotAfter.ToString('o')
  possui_chave_privada = $exported.HasPrivateKey
  arquivos = @($files)
}
$manifestPath = Join-Path $destination 'MANIFESTO_CERTIFICADO_SHA256.json'
[IO.File]::WriteAllText(
  $manifestPath,
  ($manifest | ConvertTo-Json -Depth 5),
  [Text.UTF8Encoding]::new($false)
)
$manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
[IO.File]::WriteAllText(
  (Join-Path $destination 'MANIFESTO_CERTIFICADO_SHA256.txt'),
  ($manifestHash + '  MANIFESTO_CERTIFICADO_SHA256.json' + [Environment]::NewLine),
  [Text.UTF8Encoding]::new($false)
)

if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $destination '*') -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "CERTIFICADO_PUBLICO=$publicCertificate" -ForegroundColor Green
Write-Host "THUMBPRINT=$($exported.Thumbprint)" -ForegroundColor Green
Write-Host "PACOTE_ZIP=$zipPath" -ForegroundColor Green
Write-Host "SHA256_ZIP=$((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash)" -ForegroundColor Green
