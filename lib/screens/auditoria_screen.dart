import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class AuditoriaScreen extends StatelessWidget {
  const AuditoriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Auditoria',
      subtitle: 'Logs, trilha LGPD e eventos',
      icon: Icons.manage_search_rounded,
      module: 'auditoria',
      fields: <KristalModuleField>[
        KristalModuleField(
            key: 'evento',
            label: 'Evento',
            icon: Icons.event_note_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'usuario',
            label: 'Usuário',
            icon: Icons.person_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'modulo',
            label: 'Módulo',
            icon: Icons.widgets_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'criticidade',
            label: 'Criticidade',
            icon: Icons.warning_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'detalhe',
            label: 'Detalhe',
            icon: Icons.notes_rounded,
            maxLines: 4,
            required: true),
      ],
      primaryColumns: <String>['evento', 'usuario', 'modulo', 'criticidade'],
    );
  }
}
