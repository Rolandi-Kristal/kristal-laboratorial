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
