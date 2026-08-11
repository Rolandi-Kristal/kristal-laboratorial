import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class LaudosPdfScreen extends StatelessWidget {
  const LaudosPdfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Laudos PDF',
      subtitle: 'Impressão, assinatura, hash e portal',
      icon: Icons.picture_as_pdf_rounded,
      module: 'laudos_pdf',
      fields: <KristalModuleField>[
        KristalModuleField(
            key: 'paciente',
            label: 'Paciente',
            icon: Icons.person_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'pedido',
            label: 'Pedido',
            icon: Icons.numbers_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'status',
            label: 'Status do laudo',
            icon: Icons.verified_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'hash',
            label: 'Hash de integridade',
            icon: Icons.tag_rounded,
            maxLines: 1,
            required: false),
        KristalModuleField(
            key: 'observacoes',
            label: 'Observações',
            icon: Icons.notes_rounded,
            maxLines: 3,
            required: false),
      ],
      primaryColumns: <String>['paciente', 'pedido', 'status', 'hash'],
    );
  }
}
