import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class ResultadosScreen extends StatelessWidget {
  const ResultadosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Resultados',
      subtitle: 'Digitação, análise, crítica e liberação',
      icon: Icons.fact_check_rounded,
      module: 'resultados',
      fields: <KristalModuleField>[
        KristalModuleField(
            key: 'amostra',
            label: 'Amostra / Etiqueta',
            icon: Icons.qr_code_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'exame',
            label: 'Exame',
            icon: Icons.biotech_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'resultado',
            label: 'Resultado',
            icon: Icons.edit_note_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'unidade',
            label: 'Unidade',
            icon: Icons.straighten_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'referencia',
            label: 'Referência',
            icon: Icons.rule_rounded,
            maxLines: 1,
            required: true),
      ],
      primaryColumns: <String>[
        'amostra',
        'exame',
        'resultado',
        'unidade',
        'referencia'
      ],
    );
  }
}
