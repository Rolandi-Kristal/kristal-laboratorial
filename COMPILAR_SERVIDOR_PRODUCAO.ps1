param(
  [string]$ProjectRoot = 'C:\kristal_laboratorial',
  [string]$OutputRoot = 'D:\KRISTAL LABORATORIAL SISTEMA\COMPILADOS'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$project = [IO.Path]::GetFullPath($ProjectRoot)
$output = [IO.Path]::GetFullPath($OutputRoot)
$portal = Join-Path $project 'portal_web'
$main = Join-Path $portal 'main.py'
$static = Join-Path $portal 'static'
$dist = Join-Path $output 'server_dist'
$work = Join-Path $output 'server_build_work'
$final = Join-Path $output 'server_windows'

if (-not (Test-Path -LiteralPath $main -PathType Leaf)) {
  throw "Entrada do servidor nao encontrada: $main"
}
if (-not (Test-Path -LiteralPath $static -PathType Container)) {
  throw "Recursos web nao encontrados: $static"
}
$pyinstaller = Get-Command pyinstaller -ErrorAction SilentlyContinue
if ($null -eq $pyinstaller) {
  throw 'PyInstaller nao encontrado. Instale as versoes registradas em requirements-build.txt.'
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
foreach ($generated in @($dist, $work, $final)) {
  $resolved = [IO.Path]::GetFullPath($generated)
  if (-not $resolved.StartsWith($output, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Destino de compilacao fora da raiz autorizada: $resolved"
  }
  if (Test-Path -LiteralPath $resolved) {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}

$arguments = @(
  '--noconfirm',
  '--clean',
  '--onedir',
  '--name', 'KRISTAL_SERVIDOR',
  '--paths', $portal,
  '--distpath', $dist,
  '--workpath', $work,
  '--specpath', $work,
  '--add-data', ($static + ';static'),
  $main
)
& $pyinstaller.Source @arguments
if ($LASTEXITCODE -ne 0) {
  throw "Compilacao do servidor falhou. Codigo: $LASTEXITCODE"
}

$compiled = Join-Path $dist 'KRISTAL_SERVIDOR'
$serverExe = Join-Path $compiled 'KRISTAL_SERVIDOR.exe'
if (-not (Test-Path -LiteralPath $serverExe -PathType Leaf)) {
  throw "EXE do servidor nao foi gerado: $serverExe"
}
& robocopy $compiled $final /E /COPY:DAT /DCOPY:DA /R:2 /W:2 | Out-Host
if ($LASTEXITCODE -gt 7) {
  throw "Falha ao consolidar o servidor em $final. Codigo: $LASTEXITCODE"
}
$finalExe = Join-Path $final 'KRISTAL_SERVIDOR.exe'
if (-not (Test-Path -LiteralPath $finalExe -PathType Leaf)) {
  throw "Servidor final ausente: $finalExe"
}
Write-Host "Servidor compilado no HD secundario: $finalExe" -ForegroundColor Green
