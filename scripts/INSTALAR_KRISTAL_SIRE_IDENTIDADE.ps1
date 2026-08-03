$ErrorActionPreference = "Stop"

$Root = "C:\kristal_laboratorial"
$SourceRoot = Split-Path -Parent $PSScriptRoot
$KristalSire = Join-Path $Root "integracoes\kristal_sire"
$Nucleo = Join-Path $KristalSire "nucleo"
$Exports = Join-Path $Root "exports\sire"

New-Item -ItemType Directory -Force -Path $KristalSire | Out-Null
New-Item -ItemType Directory -Force -Path $Nucleo | Out-Null
New-Item -ItemType Directory -Force -Path $Exports | Out-Null

$SourceNucleo = Join-Path $SourceRoot "assets\external\kristal_sire\nucleo"
$IconSource = Join-Path $SourceRoot "assets\icons\kristal_sire.ico"
$IconTarget = Join-Path $KristalSire "kristal_sire.ico"

Copy-Item -Force -Path (Join-Path $SourceNucleo "KRISTAL_SIRE_CORE.exe") -Destination (Join-Path $Nucleo "KRISTAL_SIRE_CORE.exe")
Copy-Item -Force -Path (Join-Path $SourceNucleo "KRISTAL_SIRE_EXTERNOS_CORE.exe") -Destination (Join-Path $Nucleo "KRISTAL_SIRE_EXTERNOS_CORE.exe")
Copy-Item -Force -Path $IconSource -Destination $IconTarget

$Shell = New-Object -ComObject WScript.Shell

$Shortcut = $Shell.CreateShortcut((Join-Path $KristalSire "KRISTAL_SIRE.lnk"))
$Shortcut.TargetPath = Join-Path $Nucleo "KRISTAL_SIRE_CORE.exe"
$Shortcut.WorkingDirectory = $Nucleo
$Shortcut.IconLocation = "$IconTarget,0"
$Shortcut.Description = "KRISTAL SIRE - Integração financeira laboratorial"
$Shortcut.Save()

$ShortcutExternal = $Shell.CreateShortcut((Join-Path $KristalSire "KRISTAL_SIRE_EXTERNOS.lnk"))
$ShortcutExternal.TargetPath = Join-Path $Nucleo "KRISTAL_SIRE_EXTERNOS_CORE.exe"
$ShortcutExternal.WorkingDirectory = $Nucleo
$ShortcutExternal.IconLocation = "$IconTarget,0"
$ShortcutExternal.Description = "KRISTAL SIRE EXTERNOS - Integração financeira laboratorial"
$ShortcutExternal.Save()

Write-Host "KRISTAL SIRE instalado com identidade visual KRISTAL em: $KristalSire"
Write-Host "Use os atalhos KRISTAL_SIRE.lnk e KRISTAL_SIRE_EXTERNOS.lnk."
