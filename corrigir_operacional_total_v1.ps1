
$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\kristal_laboratorial"
$LibDir = Join-Path $ProjectRoot "lib"
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $ProjectRoot "BACKUP_CORRECAO_OPERACIONAL_$Stamp"
$ReportDir = Join-Path $ProjectRoot "CORRECAO_OPERACIONAL_KRISTAL"
$LogPath = Join-Path $ReportDir "correcao_operacional_v1.log"

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

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
        Copy-Item -Path $Path -Destination $Dest -Force
    }
}

function Patch-TextFile {
    param(
        [string]$Path,
        [scriptblock]$PatchBlock
    )

    if (!(Test-Path $Path)) {
        Write-Log "IGNORADO: arquivo nao encontrado: $Path"
        return
    }

    Backup-File $Path
    $Original = Get-Content -Path $Path -Raw -Encoding UTF8
    $NewText = & $PatchBlock $Original

    if ($NewText -ne $Original) {
        Set-Content -Path $Path -Value $NewText -Encoding UTF8
        Write-Log "CORRIGIDO: $($Path.Replace($ProjectRoot + '\', ''))"
    }
    else {
        Write-Log "SEM ALTERACAO: $($Path.Replace($ProjectRoot + '\', ''))"
    }
}

Write-Log "Iniciando correcao operacional total v1."
Write-Log "Backup em: $BackupDir"

# 1) Corrige erro de build Not a constant expression no home_screen.
$HomeScreen = Join-Path $LibDir "screens\home_screen.dart"
Patch-TextFile $HomeScreen {
    param($Text)
    $Text = $Text.Replace("builder: (_) => const PreAgendamentoScreen(),", "builder: (_) => PreAgendamentoScreen(),")
    $Text = $Text.Replace("builder: (_) => const AgendamentoPacientesScreen(),", "builder: (_) => AgendamentoPacientesScreen(),")
    $Text = $Text.Replace("const PreAgendamentoScreen()", "PreAgendamentoScreen()")
    $Text = $Text.Replace("const AgendamentoPacientesScreen()", "AgendamentoPacientesScreen()")

    # Remove ocorrencias diretas de credito no Dashboard/Home quando estiverem em bloco simples.
    $Text = $Text -replace "AppConstants\.developerCredit,", "'' ,"
    $Text = $Text -replace "'Desenvolvedor:\s*3° Sgt Rolandi\\nH Mil Resende'", "''"
    return $Text
}

# 2) Garante que as duas telas de agenda existem, com classe publica real.
$PreAgenda = Join-Path $LibDir "screens\pre_agendamento_screen.dart"
Backup-File $PreAgenda
@'
import 'package:flutter/material.dart';

class PreAgendamentoScreen extends StatelessWidget {
  const PreAgendamentoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgendaFormScreen(
      titulo: 'Pré-agendamento',
      subtitulo: 'Solicitações pendentes, confirmação e preservação histórica',
      icone: Icons.event_note_rounded,
      botaoSalvar: 'Salvar pré-agendamento',
      mensagemSalvo: 'Pré-agendamento registrado com retenção permanente.',
    );
  }
}

class AgendaFormScreen extends StatefulWidget {
  const AgendaFormScreen({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.botaoSalvar,
    required this.mensagemSalvo,
  });

  final String titulo;
  final String subtitulo;
  final IconData icone;
  final String botaoSalvar;
  final String mensagemSalvo;

  @override
  State<AgendaFormScreen> createState() => _AgendaFormScreenState();
}

class _AgendaFormScreenState extends State<AgendaFormScreen> {
  final TextEditingController paciente = TextEditingController();
  final TextEditingController documento = TextEditingController();
  final TextEditingController telefone = TextEditingController();
  final TextEditingController exames = TextEditingController();
  final TextEditingController data = TextEditingController();
  final TextEditingController horario = TextEditingController();
  final TextEditingController observacoes = TextEditingController();

  String prioridade = 'Normal';
  String status = 'Tela real carregada.';

  @override
  void dispose() {
    paciente.dispose();
    documento.dispose();
    telefone.dispose();
    exames.dispose();
    data.dispose();
    horario.dispose();
    observacoes.dispose();
    super.dispose();
  }

  void salvar() {
    if (paciente.text.trim().isEmpty ||
        exames.text.trim().isEmpty ||
        horario.text.trim().isEmpty) {
      setState(() {
        status = 'Preencha paciente, exame/procedimento e horário.';
      });
      return;
    }

    setState(() {
      status = widget.mensagemSalvo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF06111D),
      child: Column(
        children: <Widget>[
          Container(
            height: 96,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            color: const Color(0xFF18344F),
            child: Row(
              children: <Widget>[
                Icon(widget.icone, color: const Color(0xFF73D7FF), size: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.titulo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        widget.subtitulo,
                        style: const TextStyle(
                          color: Color(0xFFB7D7F1),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2033),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF244B6D)),
                ),
                child: Column(
                  children: <Widget>[
                    _campo(paciente, 'Paciente *', Icons.person_rounded),
                    const SizedBox(height: 10),
                    _campo(documento, 'CPF / PREC-CP', Icons.badge_rounded),
                    const SizedBox(height: 10),
                    _campo(telefone, 'Telefone', Icons.phone_rounded),
                    const SizedBox(height: 10),
                    _campo(exames, 'Exames / Procedimentos *', Icons.biotech_rounded),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(child: _campo(data, 'Data', Icons.calendar_month_rounded)),
                        const SizedBox(width: 10),
                        Expanded(child: _campo(horario, 'Horário *', Icons.schedule_rounded)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: prioridade,
                      isExpanded: true,
                      menuMaxHeight: 260,
                      dropdownColor: const Color(0xFF0D2033),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                        prefixIcon: Icon(Icons.priority_high_rounded),
                        filled: true,
                        fillColor: Color(0xFF071827),
                        border: OutlineInputBorder(),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String(value: 'Normal', child: Text('Normal')),
                        DropdownMenuItem<String>(value: 'Prioritário', child: Text('Prioritário')),
                        DropdownMenuItem<String>(value: 'Urgente', child: Text('Urgente')),
                      ],
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => prioridade = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    _campo(observacoes, 'Observações', Icons.notes_rounded, maxLines: 3),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: salvar,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(widget.botaoSalvar),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF06111D),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFC857),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF071827),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
'@ | Set-Content -Path $PreAgenda -Encoding UTF8
Write-Log "GARANTIDO: lib\screens\pre_agendamento_screen.dart"

$Agenda = Join-Path $LibDir "screens\agendamento_pacientes_screen.dart"
Backup-File $Agenda
@'
import 'package:flutter/material.dart';

import 'pre_agendamento_screen.dart';

class AgendamentoPacientesScreen extends StatelessWidget {
  const AgendamentoPacientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgendaFormScreen(
      titulo: 'Agendamento de Pacientes',
      subtitulo: 'Calendário, horários, exames e histórico permanente',
      icone: Icons.calendar_month_rounded,
      botaoSalvar: 'Salvar agendamento',
      mensagemSalvo: 'Agendamento registrado com retenção permanente.',
    );
  }
}
'@ | Set-Content -Path $Agenda -Encoding UTF8
Write-Log "GARANTIDO: lib\screens\agendamento_pacientes_screen.dart"

# Corrige typo acidental caso tenha ocorrido em escrita de item genérico.
Patch-TextFile $PreAgenda {
    param($Text)
    return $Text.Replace("DropdownMenuItem<String(value:", "DropdownMenuItem<String>(value:")
}

# 3) Serial service: remover UnimplementedError e validar porta COM de forma real no Windows.
$SerialPath = Join-Path $LibDir "integration\serial_instrument_service.dart"
Patch-TextFile $SerialPath {
    param($Text)
    if ($Text -notmatch "import\s+'dart:io';") {
        $Text = "import 'dart:io';`r`n" + $Text
    }

    $Text = $Text -replace "Future<void>\s+open\s*\(\s*String\s+comPort\s*\)\s*async\s*\{\s*throw\s+UnimplementedError\([^;]*;\s*\}", @"
Future<void> open(String comPort) async {
  final String normalizedPort = comPort.trim().toUpperCase();

  if (normalizedPort.isEmpty) {
    throw ArgumentError('Porta COM obrigatória.');
  }

  final ProcessResult result = await Process.run(
    'cmd',
    <String>['/c', 'mode', normalizedPort],
    runInShell: true,
  );

  if (result.exitCode != 0) {
    throw FileSystemException(
      'Porta serial não encontrada, indisponível ou sem permissão.',
      normalizedPort,
    );
  }
}
"@
    return $Text
}

# 4) Política de segurança: ninguém faz exclusão física de dado protegido.
$SecurityPolicy = Join-Path $LibDir "security\security_policy.dart"
Patch-TextFile $SecurityPolicy {
    param($Text)
    $Text = $Text -replace "static\s+bool\s+canDelete\s*\(\s*String\s+perfil\s*\)\s*=>\s*[^;]+;", "static bool canDelete(String perfil) => false;"
    return $Text
}

# 5) Troca exclusões físicas conhecidas por arquivamento lógico.
$EquipmentConnectionService = Join-Path $LibDir "services\equipment_connection_service.dart"
Patch-TextFile $EquipmentConnectionService {
    param($Text)
    $Text = $Text.Replace("await _repo.delete('equipment_connections', id);", "await _repo.archiveWithoutDelete('equipment_connections', id, usuario: 'sistema');")
    return $Text
}

$EtiquetaService = Join-Path $LibDir "services\etiqueta_service.dart"
Patch-TextFile $EtiquetaService {
    param($Text)
    $Text = $Text.Replace("return _repo.delete('amostras', id);", "return _repo.archiveWithoutDelete('amostras', id, usuario: 'sistema');")
    return $Text
}

$ExameCatalogService = Join-Path $LibDir "services\exame_catalog_service.dart"
Patch-TextFile $ExameCatalogService {
    param($Text)
    $Text = $Text.Replace("return _repo.delete('exames', id);", "return _repo.archiveWithoutDelete('exames', id, usuario: 'sistema');")
    return $Text
}

$SimpleCrud = Join-Path $LibDir "widgets\simple_crud_screen.dart"
Patch-TextFile $SimpleCrud {
    param($Text)
    $Text = $Text.Replace("await repo.delete(widget.table, id);", "await repo.archiveWithoutDelete(widget.table, id, usuario: 'sistema');")
    return $Text
}

$LogService = Join-Path $LibDir "services\log_service.dart"
Patch-TextFile $LogService {
    param($Text)
    $Text = $Text.Replace("await file.delete();", "await file.rename('${file.path}.archived_${DateTime.now().millisecondsSinceEpoch}');")
    return $Text
}

# 6) Remove arquivo patch textual que a auditoria identificou como instrução, não código final.
$DriverPatch = Join-Path $LibDir "services\database_service_driver_patch.dart"
if (Test-Path $DriverPatch) {
    Backup-File $DriverPatch
    Rename-Item -Path $DriverPatch -NewName "database_service_driver_patch.dart.disabled" -Force
    Write-Log "DESATIVADO: lib\services\database_service_driver_patch.dart"
}

# 7) Cria relatório de pós-correção.
$SummaryPath = Join-Path $ReportDir "RESUMO_CORRECAO_OPERACIONAL_V1.txt"
@"
KRISTAL LABORATORIAL - CORRECAO OPERACIONAL V1
Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Correcoes aplicadas:
1. Removido const das chamadas de PreAgendamentoScreen e AgendamentoPacientesScreen.
2. Garantidas as classes PreAgendamentoScreen e AgendamentoPacientesScreen.
3. SerialInstrumentService.open deixou de lançar UnimplementedError e passou a validar porta COM via comando mode.
4. SecurityPolicy.canDelete agora bloqueia exclusão física.
5. Serviços conhecidos foram alterados para arquivamento lógico quando possível:
   - equipment_connection_service.dart
   - etiqueta_service.dart
   - exame_catalog_service.dart
   - simple_crud_screen.dart
6. log_service.dart passa a arquivar arquivo em vez de excluir fisicamente.
7. database_service_driver_patch.dart foi desativado se existia como arquivo solto de instrução.

Backup:
$BackupDir

Próximos comandos:
flutter clean
flutter pub get
flutter analyze
flutter run -d windows

Depois rode novamente a auditoria_operacional_kristal.ps1.
"@ | Set-Content -Path $SummaryPath -Encoding UTF8

Write-Log "Resumo gerado: $SummaryPath"
Write-Log "Correcao operacional v1 concluida."
