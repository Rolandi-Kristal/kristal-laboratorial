import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class WorklistAstmHl7Screen extends StatelessWidget {
  const WorklistAstmHl7Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Worklist ASTM/HL7',
      subtitle: 'Fila de comunicação para equipamentos via servidor',
      icon: Icons.sync_alt_rounded,
      module: 'worklist_astm_hl7',
      fields: <KristalModuleField>[
    KristalModuleField(key: 'equipamento', label: 'Equipamento', icon: Icons.precision_manufacturing_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'ip', label: 'IP do equipamento/servidor', icon: Icons.router_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'porta', label: 'Porta', icon: Icons.settings_ethernet_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'protocolo', label: 'Protocolo', icon: Icons.hub_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'mensagem', label: 'Mensagem ASTM/HL7', icon: Icons.code_rounded, maxLines: 4, required: true),
      ],
      primaryColumns: <String>['equipamento', 'ip', 'porta', 'protocolo'],
    );
  }
}
