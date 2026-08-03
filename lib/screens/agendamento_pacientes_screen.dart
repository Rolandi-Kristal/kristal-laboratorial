import 'package:flutter/material.dart';

import 'pre_agendamento_screen.dart';

class AgendamentoPacientesScreen extends StatelessWidget {
  const AgendamentoPacientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgendaFormScreen(
      titulo: 'Agendamento de Pacientes',
      subtitulo: 'CalendÃ¡rio, horÃ¡rios, exames e histÃ³rico permanente',
      icone: Icons.calendar_month_rounded,
      botaoSalvar: 'Salvar agendamento',
      mensagemSalvo: 'Agendamento registrado com retenÃ§Ã£o permanente.',
    );
  }
}
