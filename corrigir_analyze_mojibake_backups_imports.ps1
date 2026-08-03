
$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\kristal_laboratorial"
$ExternalBackupRoot = "C:\KRISTAL_BACKUPS_FORA_DO_ANALYZE"
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$FixBackup = Join-Path $ProjectRoot "BACKUP_FIX_MOJIBAKE_$Stamp"
$LogDir = Join-Path $ProjectRoot "CORRECAO_ANALYZE_FINAL"
$LogPath = Join-Path $LogDir "corrige_mojibake_backups_imports.log"

New-Item -ItemType Directory -Force -Path $ExternalBackupRoot | Out-Null
New-Item -ItemType Directory -Force -Path $FixBackup | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Set-Location $ProjectRoot

function Write-Log {
  param([string]$Message)
  $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
  Write-Host $Line
  Add-Content -Path $LogPath -Value $Line -Encoding UTF8
}

function Backup-File {
  param([string]$Path)
  if (Test-Path $Path) {
    $Rel = $Path.Replace($ProjectRoot + "\", "")
    $Dest = Join-Path $FixBackup $Rel
    New-Item -ItemType Directory -Force -Path (Split-Path $Dest -Parent) | Out-Null
    Copy-Item $Path $Dest -Force
  }
}

function Patch-File {
  param(
    [string]$Path,
    [scriptblock]$Patch
  )

  if (!(Test-Path $Path)) {
    Write-Log "IGNORADO: arquivo nao encontrado: $Path"
    return
  }

  Backup-File $Path
  $Old = Get-Content -Path $Path -Raw -Encoding UTF8
  $New = & $Patch $Old

  if ($New -ne $Old) {
    Set-Content -Path $Path -Value $New -Encoding UTF8
    Write-Log "CORRIGIDO: $($Path.Replace($ProjectRoot + '\', ''))"
  } else {
    Write-Log "SEM ALTERACAO: $($Path.Replace($ProjectRoot + '\', ''))"
  }
}

Write-Log "Iniciando correção de backups, imports e nomes corrompidos."

# 1. Mover backups e auditorias para fora do projeto.
# O flutter analyze analisa qualquer .dart dentro da raiz do projeto.
$FoldersToMove = Get-ChildItem -Path $ProjectRoot -Directory | Where-Object {
  $_.Name -like "BACKUP_*" -or
  $_.Name -like "AUDITORIA_KRISTAL_OPERACIONAL" -or
  $_.Name -like "CORRECAO_REGRAS_OPERACIONAIS"
}

foreach ($Folder in $FoldersToMove) {
  $Dest = Join-Path $ExternalBackupRoot $Folder.Name
  if (Test-Path $Dest) {
    $Dest = Join-Path $ExternalBackupRoot ($Folder.Name + "_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
  }
  Move-Item -Path $Folder.FullName -Destination $Dest
  Write-Log "Movido para fora do projeto: $($Folder.Name) -> $Dest"
}

# 2. Corrigir nomes corrompidos por troca indevida de "Placeholder" por "pendência".
$PdfPath = Join-Path $ProjectRoot "lib\services\kristal_pdf_laudo_hmr_service.dart"
Patch-File $PdfPath {
  param($Text)

  $Text = $Text.Replace("_imageOrpendÃªncia", "_imageOrPlaceholder")
  $Text = $Text.Replace("_imageOrpendência", "_imageOrPlaceholder")
  $Text = $Text.Replace("imageOrpendÃªncia", "imageOrPlaceholder")
  $Text = $Text.Replace("imageOrpendência", "imageOrPlaceholder")

  # Corrige qualquer sobra mojibake no nome do método.
  $Text = $Text -replace "_imageOrpend.{0,12}ncia", "_imageOrPlaceholder"

  return $Text
}

$CrudPath = Join-Path $ProjectRoot "lib\widgets\simple_crud_screen.dart"
Patch-File $CrudPath {
  param($Text)

  # Corrige classe/uso quebrados:
  # _PlaceholderOperationalTab virou _pendÃªncia operacionalTab
  $Text = $Text.Replace("_pendÃªncia operacionalTab", "_PlaceholderOperationalTab")
  $Text = $Text.Replace("_pendência operacionalTab", "_PlaceholderOperationalTab")
  $Text = $Text.Replace("_pendÃªnciaoperacionalTab", "_PlaceholderOperationalTab")
  $Text = $Text.Replace("_pendênciaoperacionalTab", "_PlaceholderOperationalTab")
  $Text = $Text.Replace("_pendÃªnciaOperationalTab", "_PlaceholderOperationalTab")
  $Text = $Text.Replace("_pendênciaOperationalTab", "_PlaceholderOperationalTab")

  # Regex para variações com caracteres ilegais entre pend e operacionalTab.
  $Text = $Text -replace "_pend.{0,20}operacionalTab", "_PlaceholderOperationalTab"

  # Remove imports que a auditoria colocou mas não foram usados.
  $Text = $Text -replace "import 'kristal_operational_footer\.dart';\r?\n", ""
  $Text = $Text -replace "import '../core/kristal_real_status\.dart';\r?\n", ""

  return $Text
}

# 3. Remover imports não usados gerados pelo patch em arquivos principais.
$UnusedImportMap = @{
  "lib\screens\desenvolvedor_sistema_screen.dart" = @("import '../widgets/kristal_operational_footer.dart';")
  "lib\screens\kristal_real_module_screen.dart" = @("import '../widgets/kristal_operational_footer.dart';")
  "lib\screens\lab_operational_module_screen.dart" = @("import '../widgets/kristal_operational_footer.dart';")
  "lib\screens\login_screen.dart" = @("import '../widgets/kristal_operational_footer.dart';")
  "lib\screens\professional_signature_screen.dart" = @("import '../widgets/kristal_operational_footer.dart';")
  "lib\screens\sobre_screen.dart" = @("import '../widgets/kristal_operational_footer.dart';")
  "lib\screens\technical_responsible_screen.dart" = @("import '../widgets/kristal_operational_footer.dart';")
  "lib\screens\usuarios_screen.dart" = @("import '../widgets/kristal_operational_footer.dart';")
  "lib\screens\home_screen.dart" = @("import 'hematology_driver_compatibility_screen.dart';")
}

foreach ($RelPath in $UnusedImportMap.Keys) {
  $FullPath = Join-Path $ProjectRoot $RelPath
  Patch-File $FullPath {
    param($Text)
    foreach ($ImportLine in $UnusedImportMap[$RelPath]) {
      $Escaped = [regex]::Escape($ImportLine)
      $Text = $Text -replace "$Escaped\r?\n", ""
    }
    return $Text
  }
}

# 4. Corrigir casos de Widget em lista const que viraram não const.
# Se restar "const _PlaceholderOperationalTab" quebrado por constructor, manter classe com construtor const.
Patch-File $CrudPath {
  param($Text)

  # Garante classe válida caso esteja presente e incompleta.
  $Text = $Text.Replace("class _PlaceholderOperationalTab {", "class _PlaceholderOperationalTab extends StatelessWidget {")

  if ($Text -match "class _PlaceholderOperationalTab extends StatelessWidget" -and $Text -notmatch "Widget build\(BuildContext context\)") {
    # Não tenta reconstruir arquivo inteiro; só evita deixar classe sem corpo se ela estiver totalmente quebrada.
    # Os erros atuais são de nome corrompido; em geral este bloco não será necessário.
  }

  return $Text
}

# 5. Relatório rápido.
$AnalyzeHint = Join-Path $LogDir "LEIA_ME_APOS_CORRECAO.txt"
@"
CORREÇÃO APLICADA

1. Pastas BACKUP_* foram movidas para:
$ExternalBackupRoot

2. Corrigidos nomes corrompidos:
- _imageOrpendÃªncia -> _imageOrPlaceholder
- _pendÃªncia operacionalTab -> _PlaceholderOperationalTab

3. Removidos imports não usados adicionados anteriormente.

Rode agora:
flutter clean
flutter pub get
flutter analyze

Se ainda aparecer erro, envie o novo bloco completo do flutter analyze.
"@ | Set-Content -Path $AnalyzeHint -Encoding UTF8

Write-Log "Correção finalizada."
Write-Host ""
Write-Host "Agora rode:"
Write-Host "flutter clean"
Write-Host "flutter pub get"
Write-Host "flutter analyze"
Write-Host ""
