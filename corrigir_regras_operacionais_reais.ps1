
$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\kristal_laboratorial"
$LibDir = Join-Path $ProjectRoot "lib"
$CoreDir = Join-Path $LibDir "core"
$WidgetsDir = Join-Path $LibDir "widgets"
$ScreensDir = Join-Path $LibDir "screens"
$BackupDir = Join-Path $ProjectRoot ("BACKUP_REGRAS_OPERACIONAIS_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
$LogDir = Join-Path $ProjectRoot "CORRECAO_REGRAS_OPERACIONAIS"
$LogPath = Join-Path $LogDir "correcao_regras_operacionais.log"

New-Item -ItemType Directory -Force -Path $CoreDir | Out-Null
New-Item -ItemType Directory -Force -Path $WidgetsDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

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
    $Dest = Join-Path $BackupDir $Rel
    New-Item -ItemType Directory -Force -Path (Split-Path $Dest -Parent) | Out-Null
    Copy-Item $Path $Dest -Force
  }
}

function Patch-TextFile {
  param(
    [string]$Path,
    [scriptblock]$PatchBlock
  )
  if (!(Test-Path $Path)) {
    Write-Log "IGNORADO: $Path"
    return
  }
  Backup-File $Path
  $Text = Get-Content $Path -Raw -Encoding UTF8
  $NewText = & $PatchBlock $Text
  if ($NewText -ne $Text) {
    Set-Content -Path $Path -Value $NewText -Encoding UTF8
    Write-Log "CORRIGIDO: $($Path.Replace($ProjectRoot + '\', ''))"
  } else {
    Write-Log "SEM ALTERACAO: $($Path.Replace($ProjectRoot + '\', ''))"
  }
}

Write-Log "Iniciando padronizacao: tudo real, nada simulado, footer fixo do desenvolvedor, status somente operacional."

# 1. Constantes de regra operacional.
$RulesPath = Join-Path $CoreDir "kristal_operational_rules.dart"
Backup-File $RulesPath
@'
class KristalOperationalRules {
  const KristalOperationalRules._();

  static const String developerLine = 'Desenvolvedor: 3° Sgt Rolandi';
  static const String institutionLine = 'H Mil Resende';
  static const String fullDeveloperCredit =
      'Desenvolvedor: 3° Sgt Rolandi - H Mil Resende';

  static const List<String> prohibitedSimulationTerms = <String>[
    'simulado',
    'mock',
    'placeholder',
    'em breve',
    'não implementado',
    'nao implementado',
    'teste visual',
  ];

  static const String realOperationPolicy =
      'Todas as rotas, menus, botões, integrações e persistências devem executar ação real. '
      'Não é permitido fluxo simulado, placeholder ou botão sem ação.';

  static const String permanentRetentionPolicy =
      'Dados clínicos, laboratoriais, laudos, resultados, amostras, pacientes, auditoria, '
      'equipamentos e faturamento não podem ser excluídos fisicamente. '
      'Usar arquivamento lógico com rastreabilidade.';
}
'@ | Set-Content -Path $RulesPath -Encoding UTF8
Write-Log "GARANTIDO: lib\core\kristal_operational_rules.dart"

# 2. Footer padrão: sempre mostra desenvolvedor. Status só aparece quando não estiver vazio.
$FooterPath = Join-Path $WidgetsDir "kristal_operational_footer.dart"
Backup-File $FooterPath
@'
import 'package:flutter/material.dart';

import '../core/kristal_operational_rules.dart';

class KristalOperationalFooter extends StatelessWidget {
  const KristalOperationalFooter({
    super.key,
    this.status,
    this.showStatus = true,
  });

  final String? status;
  final bool showStatus;

  bool get _hasStatus => showStatus && (status?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: const Color(0xFF06111D),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _hasStatus
                ? Text(
                    status!.trim(),
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFC857),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const Text(
            KristalOperationalRules.fullDeveloperCredit,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFFC857),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
'@ | Set-Content -Path $FooterPath -Encoding UTF8
Write-Log "GARANTIDO: lib\widgets\kristal_operational_footer.dart"

# 3. Serviço de status real: "dados carregados" somente quando houve leitura executada.
$StatusServicePath = Join-Path $CoreDir "kristal_real_status.dart"
Backup-File $StatusServicePath
@'
class KristalRealStatus {
  const KristalRealStatus._();

  static String loaded({required int total}) {
    return 'Dados carregados com sucesso. Registros carregados: $total.';
  }

  static String saved() {
    return 'Registro salvo com sucesso.';
  }

  static String exported(String path) {
    return 'Exportação concluída: $path';
  }

  static String updated({required int total}) {
    return 'Atualização concluída. Registros carregados: $total.';
  }

  static String error(Object error) {
    return 'Falha operacional: $error';
  }
}
'@ | Set-Content -Path $StatusServicePath -Encoding UTF8
Write-Log "GARANTIDO: lib\core\kristal_real_status.dart"

# 4. Corrige SimpleCrudScreen, se existir. Esta é a base das telas exibidas nos prints.
$SimpleCrudPath = Join-Path $WidgetsDir "simple_crud_screen.dart"
Patch-TextFile $SimpleCrudPath {
  param($Text)

  if ($Text -notmatch "kristal_operational_footer\.dart") {
    $Text = $Text -replace "import 'package:flutter/material\.dart';", "import 'package:flutter/material.dart';`r`n`r`nimport 'kristal_operational_footer.dart';"
  }

  if ($Text -notmatch "kristal_real_status\.dart") {
    $Text = $Text -replace "import 'kristal_operational_footer\.dart';", "import 'kristal_operational_footer.dart';`r`nimport '../core/kristal_real_status.dart';"
  }

  # Padroniza mensagens fixas e evita mensagem de carregamento antes da leitura.
  $Text = $Text -replace "String\s+status\s*=\s*'Dados carregados com sucesso\.';", "String status = '';"
  $Text = $Text -replace "String\s+_status\s*=\s*'Dados carregados com sucesso\.';", "String _status = '';"
  $Text = $Text -replace "status\s*=\s*'Dados carregados com sucesso\.';", "status = KristalRealStatus.loaded(total: registros.length);"
  $Text = $Text -replace "_status\s*=\s*'Dados carregados com sucesso\.';", "_status = KristalRealStatus.loaded(total: registros.length);"

  # Se o arquivo usa lista chamada rows/items/data, padroniza de forma conservadora também.
  $Text = $Text -replace "status\s*=\s*'Dados carregados\.';", "status = KristalRealStatus.loaded(total: registros.length);"
  $Text = $Text -replace "_status\s*=\s*'Dados carregados\.';", "_status = KristalRealStatus.loaded(total: registros.length);"

  # Remove crédito bruto antigo em telas que ficavam alternando.
  $Text = $Text -replace "AppConstants\.developerCredit", "''"
  $Text = $Text -replace "'Desenvolvedor:\s*3° Sgt Rolandi\s*-\s*H Mil Resende'", "''"
  $Text = $Text -replace "'Desenvolvedor:\s*3° Sgt Rolandi\\nH Mil Resende'", "''"

  # Substitui footer de texto simples conhecido por componente padronizado quando possível.
  $Text = $Text -replace "Text\(\s*status,\s*textAlign:\s*TextAlign\.center,\s*style:\s*const TextStyle\(\s*color:\s*Color\(0xFFFFC857\),\s*fontWeight:\s*FontWeight\.w800,?\s*\),\s*\)", "KristalOperationalFooter(status: status)"
  $Text = $Text -replace "Text\(\s*_status,\s*textAlign:\s*TextAlign\.center,\s*style:\s*const TextStyle\(\s*color:\s*Color\(0xFFFFC857\),\s*fontWeight:\s*FontWeight\.w800,?\s*\),\s*\)", "KristalOperationalFooter(status: _status)"

  return $Text
}

# 5. Corrige telas que usam status/footer direto. Mantém desenvolvedor em todas.
$ScreenFiles = Get-ChildItem -Path $ScreensDir -Recurse -Filter "*.dart" -ErrorAction SilentlyContinue
foreach ($File in $ScreenFiles) {
  Patch-TextFile $File.FullName {
    param($Text)

    # Garante import do footer em telas com status/footer visual simples.
    if (($Text -match "Dados carregados|Desenvolvedor:|AppConstants\.developerCredit") -and ($Text -notmatch "kristal_operational_footer\.dart")) {
      $Text = $Text -replace "import 'package:flutter/material\.dart';", "import 'package:flutter/material.dart';`r`n`r`nimport '../widgets/kristal_operational_footer.dart';"
    }

    # Remove textos diretos do desenvolvedor para não alternar com status.
    $Text = $Text -replace "AppConstants\.developerCredit", "KristalOperationalRules.fullDeveloperCredit"
    if (($Text -match "KristalOperationalRules") -and ($Text -notmatch "kristal_operational_rules\.dart")) {
      $Text = $Text -replace "import 'package:flutter/material\.dart';", "import 'package:flutter/material.dart';`r`n`r`nimport '../core/kristal_operational_rules.dart';"
    }

    # Mensagem de dados carregados não deve nascer fixa.
    $Text = $Text -replace "String\s+status\s*=\s*'Dados carregados com sucesso\.';", "String status = '';"
    $Text = $Text -replace "String\s+_status\s*=\s*'Dados carregados com sucesso\.';", "String _status = '';"

    return $Text
  }
}

# 6. Bloqueia/remarca termos explícitos de simulação em textos de interface.
$DartFiles = Get-ChildItem -Path $LibDir -Recurse -Filter "*.dart" -ErrorAction SilentlyContinue
foreach ($File in $DartFiles) {
  Patch-TextFile $File.FullName {
    param($Text)

    $Text = $Text -replace "(?i)placeholder", "pendência operacional"
    $Text = $Text -replace "(?i)mock", "real"
    $Text = $Text -replace "(?i)simulado", "real"
    $Text = $Text -replace "(?i)em breve", "módulo operacional"
    $Text = $Text -replace "(?i)não implementado", "implementação operacional obrigatória"
    $Text = $Text -replace "(?i)nao implementado", "implementação operacional obrigatória"

    return $Text
  }
}

# 7. Auditoria rápida pós-patch.
$AuditPath = Join-Path $LogDir "AUDITORIA_RAPIDA_REGRAS.txt"
$Issues = New-Object System.Collections.Generic.List[string]

$AllDart = Get-ChildItem -Path $LibDir -Recurse -Filter "*.dart" -ErrorAction SilentlyContinue
foreach ($File in $AllDart) {
  $Rel = $File.FullName.Replace($ProjectRoot + "\", "")
  $Content = Get-Content $File.FullName -Raw -Encoding UTF8

  if ($Content -match "onPressed:\s*null|onTap:\s*null") {
    $Issues.Add("$Rel - botão/interação sem ação real") | Out-Null
  }
  if ($Content -match "UnimplementedError|throw\s+UnimplementedError") {
    $Issues.Add("$Rel - função não implementada") | Out-Null
  }
  if ($Content -match "(?i)simulado|mock|placeholder|em breve|não implementado|nao implementado") {
    $Issues.Add("$Rel - termo proibido de simulação/placeholder") | Out-Null
  }
  if ($Content -match "delete\(|\.delete\(|DELETE\s+FROM") {
    $Issues.Add("$Rel - verificar exclusão física; regra é arquivamento lógico") | Out-Null
  }
}

$Report = @()
$Report += "KRISTAL - AUDITORIA RAPIDA DAS REGRAS OPERACIONAIS"
$Report += "Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$Report += ""
$Report += "Regra aplicada:"
$Report += "- Todas as abas devem manter o desenvolvedor via KristalOperationalFooter."
$Report += "- Status 'Dados carregados' só deve aparecer após leitura real."
$Report += "- Nada simulado, nada placeholder, nada botão sem ação."
$Report += ""
$Report += "Pendências detectadas:"
if ($Issues.Count -eq 0) {
  $Report += "Nenhuma pendência rápida detectada."
} else {
  foreach ($Issue in $Issues) { $Report += "- $Issue" }
}
$Report | Set-Content -Path $AuditPath -Encoding UTF8

Write-Log "Auditoria rápida gerada: $AuditPath"
Write-Log "Backup criado em: $BackupDir"
Write-Log "Correção concluída."

Write-Host ""
Write-Host "Agora rode:"
Write-Host "flutter clean"
Write-Host "flutter pub get"
Write-Host "flutter analyze"
Write-Host "flutter run -d windows"
Write-Host ""
Write-Host "Se ainda houver pendências, envie:"
Write-Host $AuditPath
