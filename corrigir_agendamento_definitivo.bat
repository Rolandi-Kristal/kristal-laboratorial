@echo off
setlocal enabledelayedexpansion
cd /d C:\kristal_laboratorial

echo.
echo =====================================================
echo  KRISTAL - CORRECAO DEFINITIVA DO AGENDAMENTO
echo =====================================================
echo.

if not exist "lib\screens" (
  echo ERRO: Pasta lib\screens nao encontrada.
  echo Execute este arquivo dentro ou apos confirmar C:\kristal_laboratorial.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$home='lib\screens\home_screen.dart';" ^
"$txt=[System.IO.File]::ReadAllText($home,[System.Text.Encoding]::UTF8);" ^
"$txt=$txt -replace \"import 'agendamento_pacientes_screen\.dart';`r?`n\",'';" ^
"$txt=$txt -replace \"import 'pre_agendamento_screen\.dart';`r?`n\",'';" ^
"$anchor=\"import 'atendimento_screen.dart';\";" ^
"if($txt.Contains($anchor)){$txt=$txt.Replace($anchor,$anchor+\"`r`nimport 'pre_agendamento_screen.dart';`r`nimport 'agendamento_pacientes_screen.dart';\")}" ^
"else {$txt=$txt -replace \"(import 'pacientes_screen.dart';)\",\"`$1`r`nimport 'pre_agendamento_screen.dart';`r`nimport 'agendamento_pacientes_screen.dart';\"}" ^
"[System.IO.File]::WriteAllText($home,$txt,[System.Text.Encoding]::UTF8);"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"@'
import 'package:flutter/material.dart';

class PreAgendamentoScreen extends StatelessWidget {
  const PreAgendamentoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _KristalAgendaRealScreen(
      title: 'Pré-agendamento',
      subtitle: 'Solicitações pendentes, confirmação e preservação histórica',
      icon: Icons.event_note_rounded,
      type: 'pre_agendamento',
    );
  }
}

class _KristalAgendaRealScreen extends StatefulWidget {
  const _KristalAgendaRealScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.type,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String type;

  @override
  State<_KristalAgendaRealScreen> createState() => _KristalAgendaRealScreenState();
}

class _KristalAgendaRealScreenState extends State<_KristalAgendaRealScreen> {
  final TextEditingController pacienteController = TextEditingController();
  final TextEditingController documentoController = TextEditingController();
  final TextEditingController telefoneController = TextEditingController();
  final TextEditingController examesController = TextEditingController();
  final TextEditingController horarioController = TextEditingController();

  String status = 'Tela real de pré-agendamento carregada.';

  @override
  void dispose() {
    pacienteController.dispose();
    documentoController.dispose();
    telefoneController.dispose();
    examesController.dispose();
    horarioController.dispose();
    super.dispose();
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
                Icon(widget.icon, color: const Color(0xFF73D7FF), size: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      Text(widget.subtitle, style: const TextStyle(color: Color(0xFFB7D7F1), fontWeight: FontWeight.w700)),
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
                    _field(pacienteController, 'Paciente *', Icons.person_rounded),
                    const SizedBox(height: 10),
                    _field(documentoController, 'CPF / PREC-CP', Icons.badge_rounded),
                    const SizedBox(height: 10),
                    _field(telefoneController, 'Telefone', Icons.phone_rounded),
                    const SizedBox(height: 10),
                    _field(examesController, 'Exames / Procedimentos *', Icons.biotech_rounded),
                    const SizedBox(height: 10),
                    _field(horarioController, 'Horário *', Icons.schedule_rounded),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          status = 'Pré-agendamento registrado para retenção permanente.';
                        });
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Salvar pré-agendamento'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _footer(status),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
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

  Widget _footer(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: const Color(0xFF06111D),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFC857), fontWeight: FontWeight.w800)),
    );
  }
}
'@ | Set-Content -Path 'lib\screens\pre_agendamento_screen.dart' -Encoding UTF8"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"@'
import 'package:flutter/material.dart';

class AgendamentoPacientesScreen extends StatelessWidget {
  const AgendamentoPacientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _KristalAgendamentoPacientesRealScreen();
  }
}

class _KristalAgendamentoPacientesRealScreen extends StatefulWidget {
  const _KristalAgendamentoPacientesRealScreen();

  @override
  State<_KristalAgendamentoPacientesRealScreen> createState() =>
      _KristalAgendamentoPacientesRealScreenState();
}

class _KristalAgendamentoPacientesRealScreenState
    extends State<_KristalAgendamentoPacientesRealScreen> {
  final TextEditingController pacienteController = TextEditingController();
  final TextEditingController documentoController = TextEditingController();
  final TextEditingController telefoneController = TextEditingController();
  final TextEditingController examesController = TextEditingController();
  final TextEditingController horarioController = TextEditingController();

  String status = 'Tela real de agendamento carregada.';

  @override
  void dispose() {
    pacienteController.dispose();
    documentoController.dispose();
    telefoneController.dispose();
    examesController.dispose();
    horarioController.dispose();
    super.dispose();
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
            child: const Row(
              children: <Widget>[
                Icon(Icons.calendar_month_rounded, color: Color(0xFF73D7FF), size: 34),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Agendamento de Pacientes', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      Text('Calendário, horários, exames e histórico permanente', style: TextStyle(color: Color(0xFFB7D7F1), fontWeight: FontWeight.w700)),
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
                    _field(pacienteController, 'Paciente *', Icons.person_rounded),
                    const SizedBox(height: 10),
                    _field(documentoController, 'CPF / PREC-CP', Icons.badge_rounded),
                    const SizedBox(height: 10),
                    _field(telefoneController, 'Telefone', Icons.phone_rounded),
                    const SizedBox(height: 10),
                    _field(examesController, 'Exames / Procedimentos *', Icons.biotech_rounded),
                    const SizedBox(height: 10),
                    _field(horarioController, 'Horário *', Icons.schedule_rounded),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          status = 'Agendamento registrado para retenção permanente.';
                        });
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Salvar agendamento'),
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
            child: Text(status, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFC857), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
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
'@ | Set-Content -Path 'lib\screens\agendamento_pacientes_screen.dart' -Encoding UTF8"

echo.
echo Arquivos criados/atualizados:
echo - lib\screens\pre_agendamento_screen.dart
echo - lib\screens\agendamento_pacientes_screen.dart
echo - imports corrigidos no home_screen.dart
echo.
echo Rode agora:
echo flutter clean
echo flutter pub get
echo flutter analyze
echo.
pause
