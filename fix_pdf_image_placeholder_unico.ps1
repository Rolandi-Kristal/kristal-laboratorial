
$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\kristal_laboratorial"
$FilePath = Join-Path $ProjectRoot "lib\services\kristal_pdf_laudo_hmr_service.dart"
$ExternalRoot = "C:\KRISTAL_BACKUPS_FORA_DO_ANALYZE"
$BackupDir = Join-Path $ExternalRoot ("BACKUP_PDF_PLACEHOLDER_UNICO_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

if (!(Test-Path $FilePath)) {
  throw "Arquivo não encontrado: $FilePath"
}

Copy-Item $FilePath (Join-Path $BackupDir "kristal_pdf_laudo_hmr_service.dart") -Force

$Text = Get-Content -Path $FilePath -Raw -Encoding UTF8

if ($Text -notmatch "import\s+'dart:typed_data';") {
  $Text = "import 'dart:typed_data';`r`n" + $Text
}

$Text = $Text.Replace("_imageOrpendÃªncia", "_imageOrPlaceholder")
$Text = $Text.Replace("_imageOrpendência", "_imageOrPlaceholder")
$Text = $Text.Replace("imageOrpendÃªncia", "imageOrPlaceholder")
$Text = $Text.Replace("imageOrpendência", "imageOrPlaceholder")
$Text = $Text -replace "_imageOrpend.{0,25}ncia", "_imageOrPlaceholder"

$Text = $Text -replace "_imageOrPlaceholder\(\s*([A-Za-z0-9_]+)\s+width\s*:", "_imageOrPlaceholder(`$1, width:"
$Text = $Text -replace "_imageOrPlaceholder\(\s*([A-Za-z0-9_]+)\s+height\s*:", "_imageOrPlaceholder(`$1, height:"

$Text = $Text -replace "(?m)^\s*(?:late\s+)?(?:final\s+)?(?:pw\.)?Widget\s+_imageOrPlaceholder\s*;?\s*$", ""
$Text = $Text -replace "(?m)^\s*(?:late\s+)?(?:final\s+)?dynamic\s+_imageOrPlaceholder\s*;?\s*$", ""

$Lines = $Text -split "`r?`n"
$Out = New-Object System.Collections.Generic.List[string]
$i = 0

while ($i -lt $Lines.Count) {
  $Line = $Lines[$i]

  if ($Line -match "^\s*(?:pw\.)?Widget\s+_imageOrPlaceholder\s*\(") {
    $Depth = 0
    $Started = $false

    while ($i -lt $Lines.Count) {
      $Current = $Lines[$i]

      foreach ($Char in $Current.ToCharArray()) {
        if ($Char -eq "{") {
          $Depth++
          $Started = $true
        }
        elseif ($Char -eq "}") {
          $Depth--
        }
      }

      $i++

      if ($Started -and $Depth -le 0) {
        break
      }
    }

    continue
  }

  $Out.Add($Line) | Out-Null
  $i++
}

$Text = ($Out -join "`r`n")

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

$LastBrace = $Text.LastIndexOf("}")
if ($LastBrace -lt 0) {
  throw "Não foi possível localizar a chave final do arquivo."
}

$Text = $Text.Insert($LastBrace, $Method)

$DefinitionCount = ([regex]::Matches($Text, "(?:pw\.)?Widget\s+_imageOrPlaceholder\s*\(")).Count
if ($DefinitionCount -ne 1) {
  throw "Correção interrompida: número de definições _imageOrPlaceholder = $DefinitionCount. Esperado: 1."
}

Set-Content -Path $FilePath -Value $Text -Encoding UTF8

Write-Host ""
Write-Host "Corrigido: kristal_pdf_laudo_hmr_service.dart"
Write-Host "Backup externo em: $BackupDir"
Write-Host ""
Write-Host "Agora rode:"
Write-Host "flutter clean"
Write-Host "flutter pub get"
Write-Host "flutter analyze"
Write-Host ""
