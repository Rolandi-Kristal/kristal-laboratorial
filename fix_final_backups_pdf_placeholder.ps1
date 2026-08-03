
$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\kristal_laboratorial"
$ExternalRoot = "C:\KRISTAL_BACKUPS_FORA_DO_ANALYZE"
$ExternalBackup = Join-Path $ExternalRoot ("BACKUP_FIX_FINAL_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
$LogDir = Join-Path $ProjectRoot "CORRECAO_ANALYZE_FINAL"
$LogPath = Join-Path $ExternalBackup "fix_final_backups_pdf_placeholder.log"

New-Item -ItemType Directory -Force -Path $ExternalRoot | Out-Null
New-Item -ItemType Directory -Force -Path $ExternalBackup | Out-Null

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
    $Dest = Join-Path $ExternalBackup $Rel
    New-Item -ItemType Directory -Force -Path (Split-Path $Dest -Parent) | Out-Null
    Copy-Item -Path $Path -Destination $Dest -Force
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

Write-Log "Iniciando correção final: backups fora do analyze + PDF Placeholder."

# 1. Mover TODOS os backups/correções/auditorias com .dart para fora do projeto.
# Não criamos backup dentro do projeto para não voltar ao mesmo erro.
$DirsToMove = Get-ChildItem -Path $ProjectRoot -Directory | Where-Object {
  $_.Name -like "BACKUP_*" -or
  $_.Name -like "AUDITORIA_*" -or
  $_.Name -like "CORRECAO_*"
}

foreach ($Dir in $DirsToMove) {
  $Dest = Join-Path $ExternalRoot $Dir.Name
  if (Test-Path $Dest) {
    $Dest = Join-Path $ExternalRoot ($Dir.Name + "_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
  }

  Move-Item -Path $Dir.FullName -Destination $Dest -Force
  Write-Log "Movido para fora do projeto: $($Dir.Name) -> $Dest"
}

# 2. Corrigir arquivo PDF que quebrou com _imageOrpendência/_imageOrPlaceholder.
$PdfPath = Join-Path $ProjectRoot "lib\services\kristal_pdf_laudo_hmr_service.dart"

Patch-File $PdfPath {
  param($Text)

  if ($Text -notmatch "import\s+'dart:typed_data';") {
    $Text = "import 'dart:typed_data';`r`n" + $Text
  }

  $Text = $Text.Replace("_imageOrpendÃªncia", "_imageOrPlaceholder")
  $Text = $Text.Replace("_imageOrpendência", "_imageOrPlaceholder")
  $Text = $Text.Replace("imageOrpendÃªncia", "imageOrPlaceholder")
  $Text = $Text.Replace("imageOrpendência", "imageOrPlaceholder")
  $Text = $Text -replace "_imageOrpend.{0,20}ncia", "_imageOrPlaceholder"

  $Text = $Text -replace "_imageOrPlaceholder\(([A-Za-z0-9_]+)\s+width:", "_imageOrPlaceholder(`$1, width:"
  $Text = $Text -replace "_imageOrPlaceholder\(([A-Za-z0-9_]+)\s+height:", "_imageOrPlaceholder(`$1, height:"
  $Text = $Text -replace "(?m)^\s*(?:late\s+)?(?:final\s+)?(?:pw\.)?Widget\s+_imageOrPlaceholder\s*;?\s*$", ""

  $Method = @'
  pw.Widget _imageOrPlaceholder(
    Uint8List? imageBytes, {
    double width = 54,
    double height = 54,
  }) {
    if (imageBytes == null || imageBytes.isEmpty) {
      return pw.Container(
        width: width,
        height: height,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.5),
        ),
        child: pw.Center(
          child: pw.Text(
            'HMR',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return pw.Image(
      pw.MemoryImage(imageBytes),
      width: width,
      height: height,
      fit: pw.BoxFit.contain,
    );
  }
'@

  $Pattern = "(?s)\n\s*pw\.Widget\s+_imageOrPlaceholder\s*\(\s*Uint8List\?\s+[A-Za-z0-9_]+,\s*\{.*?\n\s*\}\s*"
  if ($Text -match $Pattern) {
    $Text = [regex]::Replace($Text, $Pattern, "`r`n$Method`r`n", 1)
  }
  elseif ($Text -notmatch "pw\.Widget\s+_imageOrPlaceholder\s*\(") {
    $LastBrace = $Text.LastIndexOf("}")
    if ($LastBrace -gt 0) {
      $Text = $Text.Insert($LastBrace, "`r`n$Method`r`n")
    }
  }

  return $Text
}

# 3. Corrigir simple_crud_screen se ainda existir termo corrompido.
$CrudPath = Join-Path $ProjectRoot "lib\widgets\simple_crud_screen.dart"
Patch-File $CrudPath {
  param($Text)

  $Text = $Text.Replace("_pendÃªncia operacionalTab", "_PlaceholderOperationalTab")
  $Text = $Text.Replace("_pendência operacionalTab", "_PlaceholderOperationalTab")
  $Text = $Text.Replace("_pendÃªnciaoperacionalTab", "_PlaceholderOperationalTab")
  $Text = $Text.Replace("_pendênciaoperacionalTab", "_PlaceholderOperationalTab")
  $Text = $Text.Replace("_pendÃªnciaOperationalTab", "_PlaceholderOperationalTab")
  $Text = $Text.Replace("_pendênciaOperationalTab", "_PlaceholderOperationalTab")
  $Text = $Text -replace "_pend.{0,30}operacionalTab", "_PlaceholderOperationalTab"

  $Text = $Text -replace "import 'kristal_operational_footer\.dart';\r?\n", ""
  $Text = $Text -replace "import '../core/kristal_real_status\.dart';\r?\n", ""

  return $Text
}

# 4. Remover imports não usados conhecidos no lib principal.
$Unused = @{
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

foreach ($RelPath in $Unused.Keys) {
  $Full = Join-Path $ProjectRoot $RelPath

  Patch-File $Full {
    param($Text)
    foreach ($Line in $Unused[$RelPath]) {
      $Escaped = [regex]::Escape($Line)
      $Text = $Text -replace "$Escaped\r?\n", ""
    }
    return $Text
  }
}

$RemainingBackups = Get-ChildItem -Path $ProjectRoot -Directory | Where-Object {
  $_.Name -like "BACKUP_*" -or $_.Name -like "AUDITORIA_*" -or $_.Name -like "CORRECAO_*"
}

$ReportPath = Join-Path $ExternalBackup "RELATORIO_FIX_FINAL.txt"
$Lines = @()
$Lines += "KRISTAL - FIX FINAL BACKUPS + PDF PLACEHOLDER"
$Lines += "Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$Lines += "Backup externo das alterações: $ExternalBackup"
$Lines += ""
$Lines += "Pastas BACKUP/AUDITORIA/CORRECAO restantes dentro do projeto: $($RemainingBackups.Count)"
foreach ($Folder in $RemainingBackups) {
  $Lines += "- $($Folder.FullName)"
}
$Lines += ""
$Lines += "Execute agora:"
$Lines += "flutter clean"
$Lines += "flutter pub get"
$Lines += "flutter analyze"
$Lines | Set-Content -Path $ReportPath -Encoding UTF8

Write-Log "Relatório gerado: $ReportPath"
Write-Log "Correção final concluída."

Write-Host ""
Write-Host "Agora rode:"
Write-Host "flutter clean"
Write-Host "flutter pub get"
Write-Host "flutter analyze"
Write-Host ""
