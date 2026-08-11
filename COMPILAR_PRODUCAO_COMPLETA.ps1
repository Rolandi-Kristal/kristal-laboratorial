param(
  [string]$ProjectRoot = 'C:\kristal_laboratorial',
  [string]$OutputRoot = 'D:\KRISTAL LABORATORIAL SISTEMA\COMPILADOS'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$project = [IO.Path]::GetFullPath($ProjectRoot)
$output = [IO.Path]::GetFullPath($OutputRoot)
$appFinal = Join-Path $output 'app_windows'
$symbols = Join-Path $output 'simbolos_flutter'

foreach ($commandName in @('flutter', 'dart', 'python', 'robocopy')) {
  if ($null -eq (Get-Command $commandName -ErrorAction SilentlyContinue)) {
    throw "Comando obrigatorio nao encontrado: $commandName"
  }
}
if (-not (Test-Path -LiteralPath (Join-Path $project 'pubspec.yaml') -PathType Leaf)) {
  throw "Projeto Flutter invalido: $project"
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
foreach ($generated in @($appFinal, $symbols)) {
  $resolved = [IO.Path]::GetFullPath($generated)
  if (-not $resolved.StartsWith($output, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Destino de compilacao fora da raiz autorizada: $resolved"
  }
  if (Test-Path -LiteralPath $resolved) {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
New-Item -ItemType Directory -Path $symbols -Force | Out-Null

$previousPythonPath = $env:PYTHONPATH
Push-Location $project
try {
  $env:PYTHONPATH = $project + [IO.Path]::PathSeparator + (Join-Path $project 'portal_web')
  Write-Host '1/7 Testes Python do servidor' -ForegroundColor Cyan
  & python -B -m unittest discover -s portal_web\tests -v
  if ($LASTEXITCODE -ne 0) { throw 'Testes Python falharam.' }

  Write-Host '2/7 Dependencias Flutter' -ForegroundColor Cyan
  & flutter clean
  if ($LASTEXITCODE -ne 0) { throw 'flutter clean falhou.' }
  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get falhou.' }

  Write-Host '3/7 Analise estatica Dart' -ForegroundColor Cyan
  & dart analyze lib test
  if ($LASTEXITCODE -ne 0) { throw 'Analise estatica Dart falhou.' }

  Write-Host '4/7 Testes Flutter' -ForegroundColor Cyan
  & flutter test
  if ($LASTEXITCODE -ne 0) { throw 'Testes Flutter falharam.' }

  Write-Host '5/7 Compilacao Flutter Release ofuscada' -ForegroundColor Cyan
  & flutter build windows --release --obfuscate --split-debug-info $symbols
  if ($LASTEXITCODE -ne 0) { throw 'Compilacao Flutter Release falhou.' }

  $flutterRelease = Join-Path $project 'build\windows\x64\runner\Release'
  if (-not (Test-Path -LiteralPath (Join-Path $flutterRelease 'kristal_laboratorial.exe') -PathType Leaf)) {
    throw "Executavel Flutter nao encontrado: $flutterRelease"
  }
  & robocopy $flutterRelease $appFinal /E /COPY:DAT /DCOPY:DA /R:2 /W:2 | Out-Host
  if ($LASTEXITCODE -gt 7) { throw "Falha ao copiar aplicativo para $appFinal." }

  Write-Host '6/7 Compilacao do servidor Windows' -ForegroundColor Cyan
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $project 'COMPILAR_SERVIDOR_PRODUCAO.ps1') -ProjectRoot $project -OutputRoot $output
  if ($LASTEXITCODE -ne 0) { throw 'Compilacao do servidor falhou.' }

  Write-Host '7/7 Assinatura Authenticode e hashes finais' -ForegroundColor Cyan
  $executables = @(
    (Join-Path $appFinal 'kristal_laboratorial.exe'),
    (Join-Path (Join-Path $output 'server_windows') 'KRISTAL_SERVIDOR.exe')
  )
  foreach ($executable in $executables) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $project 'assinar_release.ps1') -ExecutablePaths $executable
    if ($LASTEXITCODE -ne 0) {
      throw "Assinatura do executavel falhou: $executable"
    }
  }

  $hashes = foreach ($exe in $executables) {
    $signature = Get-AuthenticodeSignature -FilePath $exe
    if ($signature.Status -ne 'Valid') {
      throw "Assinatura final invalida: $exe - $($signature.Status)"
    }
    [ordered]@{
      arquivo = $exe
      tamanho = (Get-Item -LiteralPath $exe).Length
      sha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
      assinatura = $signature.Status.ToString()
      certificado = $signature.SignerCertificate.Subject
      thumbprint = $signature.SignerCertificate.Thumbprint
      validade = $signature.SignerCertificate.NotAfter.ToString('o')
    }
  }
  $manifestPath = Join-Path $output 'MANIFESTO_COMPILADOS_ASSINADOS.json'
  [IO.File]::WriteAllText(
    $manifestPath,
    (([ordered]@{ sistema = 'KRISTAL LABORATORIAL'; modo = 'RELEASE_PRODUCAO'; gerado_em = (Get-Date).ToString('o'); executaveis = @($hashes) }) | ConvertTo-Json -Depth 5),
    [Text.UTF8Encoding]::new($false)
  )
  Write-Host "Compilacao de producao concluida: $output" -ForegroundColor Green
  Write-Host "Manifesto: $manifestPath" -ForegroundColor Green
} finally {
  $env:PYTHONPATH = $previousPythonPath
  Pop-Location
}
