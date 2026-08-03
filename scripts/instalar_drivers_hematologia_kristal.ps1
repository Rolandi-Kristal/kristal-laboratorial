param(
  [string]$DriverPackPath = "C:\kristal_laboratorial\driver hemato.rar"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\kristal_laboratorial"
$DataRoot = Join-Path $ProjectRoot "data\drivers\hematologia"
$PackageDir = Join-Path $DataRoot "pacote"
$ProfilePath = Join-Path $DataRoot "hematologia_driver_profiles.json"

New-Item -ItemType Directory -Force -Path $DataRoot | Out-Null
New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null

Write-Host ""
Write-Host "======================================================"
Write-Host " KRISTAL - INSTALACAO DRIVERS HEMATOLOGIA"
Write-Host "======================================================"
Write-Host ""

$EmbeddedProfile = Join-Path $ProjectRoot "config\drivers\hematologia\hematologia_driver_profiles.json"
if (Test-Path $EmbeddedProfile) {
  Copy-Item $EmbeddedProfile $ProfilePath -Force
  Write-Host "Perfil copiado para: $ProfilePath"
}
else {
  Write-Host "Perfil embarcado não encontrado. O app criará perfil padrão pelo serviço."
}

if (Test-Path $DriverPackPath) {
  Copy-Item $DriverPackPath (Join-Path $DataRoot "driver hemato.rar") -Force
  Write-Host "Pacote copiado para: $(Join-Path $DataRoot 'driver hemato.rar')"

  $SevenZipCandidates = @(
    "C:\Program Files\7-Zip\7z.exe",
    "C:\Program Files (x86)\7-Zip\7z.exe",
    "C:\Program Files\WinRAR\WinRAR.exe",
    "C:\Program Files\WinRAR\UnRAR.exe"
  )

  $Extractor = $SevenZipCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

  if ($Extractor) {
    Write-Host "Extrator encontrado: $Extractor"

    if ($Extractor -like "*7z.exe") {
      & $Extractor x $DriverPackPath "-o$PackageDir" -y
    }
    elseif ($Extractor -like "*WinRAR.exe") {
      & $Extractor x -y $DriverPackPath "$PackageDir\"
    }
    else {
      & $Extractor x -y $DriverPackPath "$PackageDir\"
    }

    Write-Host "Pacote extraído em: $PackageDir"
  }
  else {
    Write-Host "7-Zip/WinRAR não encontrado. O pacote foi copiado, mas não extraído."
    Write-Host "Instale 7-Zip ou WinRAR e rode o script novamente, ou extraia manualmente para:"
    Write-Host $PackageDir
  }
}
else {
  Write-Host "Pacote RAR não encontrado em: $DriverPackPath"
  Write-Host "Copie o arquivo driver hemato.rar para C:\kristal_laboratorial ou informe -DriverPackPath."
}

Write-Host ""
Write-Host "Compatibilidade registrada para modelos:"
Write-Host "- 5100"
Write-Host "- 5180"
Write-Host "- 5300"
Write-Host "- 5380"
Write-Host ""
Write-Host "Protocolos suportados pelo KRISTAL:"
Write-Host "- ASTM"
Write-Host "- HL7"
Write-Host "- TXT/CSV"
Write-Host "- TCP/IP"
Write-Host "- Serial COM"
Write-Host "- Pasta monitorada"
Write-Host ""
