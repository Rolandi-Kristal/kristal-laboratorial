import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class ReagentesLotesScreen extends StatelessWidget {
  const ReagentesLotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Reagentes e Lotes',
      subtitle: 'Validade, rastreabilidade e consumo',
      icon: Icons.science_rounded,
      module: 'reagentes_lotes',
      fields: <KristalModuleField>[
    KristalModuleField(key: 'reagente', label: 'Reagente', icon: Icons.science_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'lote', label: 'Lote', icon: Icons.tag_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'fabricante', label: 'Fabricante', icon: Icons.factory_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'validade', label: 'Validade', icon: Icons.event_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'equipamento', label: 'Equipamento vinculado', icon: Icons.precision_manufacturing_rounded, maxLines: 1, required: true),
      ],
      primaryColumns: <String>['reagente', 'lote', 'fabricante', 'validade', 'equipamento'],
    );
  }
}
