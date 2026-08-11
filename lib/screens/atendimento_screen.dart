import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class AtendimentoScreen extends StatelessWidget {
  const AtendimentoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Atendimento',
      subtitle: 'Pedidos, guias, convênio e prioridade',
      icon: Icons.assignment_rounded,
      module: 'atendimento',
      fields: <KristalModuleField>[
        KristalModuleField(
            key: 'paciente',
            label: 'Paciente',
            icon: Icons.person_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'pedido',
            label: 'Pedido / Atendimento',
            icon: Icons.numbers_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'convenio',
            label: 'Convênio',
            icon: Icons.apartment_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'prioridade',
            label: 'Prioridade',
            icon: Icons.priority_high_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'exames',
            label: 'Exames solicitados',
            icon: Icons.biotech_rounded,
            maxLines: 3,
            required: true),
      ],
      primaryColumns: <String>['paciente', 'pedido', 'convenio', 'prioridade'],
    );
  }
}
