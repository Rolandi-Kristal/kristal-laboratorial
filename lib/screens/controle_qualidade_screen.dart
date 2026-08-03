import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class ControleQualidadeScreen extends StatelessWidget {
  const ControleQualidadeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Controle de Qualidade',
      subtitle: 'CQ, regras, lotes e rastreabilidade',
      icon: Icons.verified_rounded,
      module: 'controle_qualidade',
      fields: <KristalModuleField>[
    KristalModuleField(key: 'exame', label: 'Exame', icon: Icons.biotech_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'lote', label: 'Lote CQ', icon: Icons.inventory_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'nivel', label: 'Nível', icon: Icons.layers_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'resultado', label: 'Resultado CQ', icon: Icons.fact_check_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'status', label: 'Status', icon: Icons.verified_rounded, maxLines: 1, required: true),
      ],
      primaryColumns: <String>['exame', 'lote', 'nivel', 'resultado', 'status'],
    );
  }
}
