$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\kristal_laboratorial"
$HomePath = Join-Path $ProjectRoot "lib\screens\home_screen.dart"

if (!(Test-Path $HomePath)) {
  throw "home_screen.dart não encontrado."
}

$Text = Get-Content $HomePath -Raw -Encoding UTF8

if ($Text -notmatch "hematology_driver_compatibility_screen\.dart") {
  $Text = $Text -replace "import 'equipamentos_screen\.dart';", "import 'equipamentos_screen.dart';`r`nimport 'hematology_driver_compatibility_screen.dart';"
}

if ($Text -notmatch "HematologyDriverCompatibilityScreen") {
  $Menu = @"
    _ModuleItem(
      group: 'INTEGRAÇÕES',
      title: 'Drivers Hematologia',
      subtitle: '5100, 5180, 5300, 5380, ASTM, HL7, TCP/IP, COM e pasta monitorada',
      icon: Icons.bloodtype_rounded,
      builder: (_) => const HematologyDriverCompatibilityScreen(),
      moduleKey: 'drivers_hematologia',
    ),
"@

  $Text = $Text -replace "(_ModuleItem\(\s*group:\s*'INTEGRAÇÕES'[\s\S]*?\n\s*\),)", "`$1`r`n$Menu"
}

Set-Content $HomePath $Text -Encoding UTF8
Write-Host "Menu Drivers Hematologia aplicado ao home_screen.dart."
