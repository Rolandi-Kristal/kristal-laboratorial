
$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\kristal_laboratorial"
$FilePath = Join-Path $ProjectRoot "lib\services\kristal_pdf_laudo_hmr_service.dart"
$ExternalRoot = "C:\KRISTAL_BACKUPS_FORA_DO_ANALYZE"
$BackupDir = Join-Path $ExternalRoot ("BACKUP_PDF_LINHAS_EXATAS_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

if (!(Test-Path $FilePath)) {
  throw "Arquivo não encontrado: $FilePath"
}

Copy-Item $FilePath (Join-Path $BackupDir "kristal_pdf_laudo_hmr_service.dart") -Force

$Text = Get-Content -Path $FilePath -Raw -Encoding UTF8

# Garantir import necessário.
if ($Text -notmatch "import\s+'dart:typed_data';") {
  $Text = "import 'dart:typed_data';`r`n" + $Text
}

# Normalizar nomes corrompidos.
$Text = $Text.Replace("_imageOrpendÃªncia", "_imageOrPlaceholder")
$Text = $Text.Replace("_imageOrpendência", "_imageOrPlaceholder")
$Text = $Text.Replace("imageOrpendÃªncia", "imageOrPlaceholder")
$Text = $Text.Replace("imageOrpendência", "imageOrPlaceholder")

# Corrigir chamadas quebradas nas linhas 148 e 189:
# Ex.: _imageOrPlaceholder(hmrLogo width: 54) -> _imageOrPlaceholder(hmrLogo, width: 54)
$Text = $Text -replace "_imageOrPlaceholder\(\s*([A-Za-z0-9_]+)\s+(width|height)\s*:", "_imageOrPlaceholder(`$1, `$2:"

# Trabalhar linha a linha para remover campo inválido e métodos duplicados.
$Lines = $Text -split "`r?`n"
$Out = New-Object System.Collections.Generic.List[string]
$i = 0
$Inserted = $false

while ($i -lt $Lines.Count) {
  $Line = $Lines[$i]

  # Remove campo inválido na linha 62:
  # pw.Widget _imageOrPlaceholder;
  # final pw.Widget _imageOrPlaceholder;
  # late pw.Widget _imageOrPlaceholder;
  # dynamic _imageOrPlaceholder;
  if ($Line -match "^\s*(late\s+)?(final\s+)?(pw\.)?(Widget|dynamic|Function)\s+_imageOrPlaceholder\s*;?\s*$") {
    $i++
    continue
  }

  # Remove qualquer método/função existente _imageOrPlaceholder.
  if ($Line -match "^\s*(pw\.)?Widget\s+_imageOrPlaceholder\s*\(" -or
      $Line -match "^\s*_imageOrPlaceholder\s*\(") {

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

      # Segurança: se for uma declaração quebrada sem corpo, pula até linha com ; ou próxima linha em branco.
      if (!$Started -and ($Current -match ";\s*$" -or $Current.Trim() -eq "")) {
        break
      }
    }

    continue
  }

  # Antes da última chave da classe principal, inserir método único.
  # Estratégia: detectar última linha do arquivo que é somente "}" e inserir antes dela depois.
  $Out.Add($Line) | Out-Null
  $i++
}

$Text = ($Out -join "`r`n")

# Após remoção, inserir método antes da última chave do arquivo.
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

# Validações objetivas antes de salvar.
$DefinitionCount = ([regex]::Matches($Text, "(?m)^\s*(?:pw\.)?Widget\s+_imageOrPlaceholder\s*\(")).Count
if ($DefinitionCount -ne 1) {
  throw "Ainda existem $DefinitionCount definições de _imageOrPlaceholder. Esperado: 1."
}

$InvalidFieldCount = ([regex]::Matches($Text, "(?m)^\s*(late\s+)?(final\s+)?(pw\.)?(Widget|dynamic|Function)\s+_imageOrPlaceholder\s*;?\s*$")).Count
if ($InvalidFieldCount -ne 0) {
  throw "Ainda existe campo inválido _imageOrPlaceholder."
}

# Não permitir chamada sem vírgula.
if ($Text -match "_imageOrPlaceholder\(\s*[A-Za-z0-9_]+\s+(width|height)\s*:") {
  throw "Ainda existe chamada _imageOrPlaceholder sem vírgula."
}

Set-Content -Path $FilePath -Value $Text -Encoding UTF8

Write-Host ""
Write-Host "Corrigido com sucesso: lib\services\kristal_pdf_laudo_hmr_service.dart"
Write-Host "Backup externo em: $BackupDir"
Write-Host ""
Write-Host "Agora rode:"
Write-Host "flutter clean"
Write-Host "flutter pub get"
Write-Host "flutter analyze"
Write-Host ""
