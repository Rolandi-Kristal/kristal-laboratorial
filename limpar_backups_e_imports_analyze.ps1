
$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\kristal_laboratorial"
$HomeScreenPath = Join-Path $ProjectRoot "lib\screens\home_screen.dart"
$OutsideBackupRoot = "C:\KRISTAL_BACKUPS_FORA_DO_ANALYZE"

Set-Location $ProjectRoot

Write-Host ""
Write-Host "====================================================="
Write-Host " KRISTAL - LIMPEZA DO ANALYZE E IMPORTS"
Write-Host "====================================================="
Write-Host ""

# 1. Mover pastas de backup para fora do projeto.
# O flutter analyze está analisando BACKUP_CORRECAO_OPERACIONAL_...\lib\...
# porque essas pastas ficaram dentro de C:\kristal_laboratorial.
New-Item -ItemType Directory -Force -Path $OutsideBackupRoot | Out-Null

$BackupFolders = Get-ChildItem -Path $ProjectRoot -Directory |
    Where-Object {
        $_.Name -like "BACKUP_CORRECAO_OPERACIONAL_*" -or
        $_.Name -like "BACKUP_*" -or
        $_.Name -like "AUDITORIA_KRISTAL_OPERACIONAL"
    }

foreach ($Folder in $BackupFolders) {
    $Destination = Join-Path $OutsideBackupRoot $Folder.Name

    if (Test-Path $Destination) {
        $Destination = Join-Path $OutsideBackupRoot ($Folder.Name + "_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    }

    Move-Item -Path $Folder.FullName -Destination $Destination
    Write-Host "Movido para fora do projeto: $($Folder.Name) -> $Destination"
}

# 2. Corrigir imports não usados do home_screen.dart conforme analyzer atual.
if (Test-Path $HomeScreenPath) {
    $Text = Get-Content -Path $HomeScreenPath -Raw -Encoding UTF8

    # Remove imports de agenda somente se as classes não aparecem no corpo do arquivo.
    $BodyWithoutImports = ($Text -split "`r?`n" | Where-Object {
        $_ -notmatch "import 'pre_agendamento_screen\.dart';" -and
        $_ -notmatch "import 'agendamento_pacientes_screen\.dart';"
    }) -join "`n"

    if ($BodyWithoutImports -notmatch "\bPreAgendamentoScreen\b") {
        $Text = $Text -replace "import 'pre_agendamento_screen\.dart';\r?\n", ""
        Write-Host "Removido import não usado: pre_agendamento_screen.dart"
    }
    else {
        Write-Host "Mantido import: pre_agendamento_screen.dart"
    }

    if ($BodyWithoutImports -notmatch "\bAgendamentoPacientesScreen\b") {
        $Text = $Text -replace "import 'agendamento_pacientes_screen\.dart';\r?\n", ""
        Write-Host "Removido import não usado: agendamento_pacientes_screen.dart"
    }
    else {
        Write-Host "Mantido import: agendamento_pacientes_screen.dart"
    }

    Set-Content -Path $HomeScreenPath -Value $Text -Encoding UTF8
}
else {
    Write-Host "home_screen.dart não encontrado."
}

Write-Host ""
Write-Host "Concluído."
Write-Host ""
Write-Host "Agora rode:"
Write-Host "flutter clean"
Write-Host "flutter pub get"
Write-Host "flutter analyze"
Write-Host ""
