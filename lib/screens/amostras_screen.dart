import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class AmostrasScreen extends StatelessWidget {
  const AmostrasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Amostras',
      subtitle: 'Coleta, tubo, etiquetas, remessa e recebimento',
      icon: Icons.qr_code_2_rounded,
      module: 'amostras',
      fields: <KristalModuleField>[
    KristalModuleField(key: 'etiqueta', label: 'Etiqueta', icon: Icons.qr_code_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'paciente', label: 'Paciente', icon: Icons.person_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'material', label: 'Material', icon: Icons.science_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'tubo', label: 'Tubo', icon: Icons.bloodtype_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'status', label: 'Status da amostra', icon: Icons.fact_check_rounded, maxLines: 1, required: true),
      ],
      primaryColumns: <String>['etiqueta', 'paciente', 'material', 'tubo', 'status'],
    );
  }
}
