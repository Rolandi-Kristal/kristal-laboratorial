import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class EquipamentosScreen extends StatelessWidget {
  const EquipamentosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Equipamentos',
      subtitle: 'Máquinas conectadas via servidor, IP e porta',
      icon: Icons.precision_manufacturing_rounded,
      module: 'equipamentos',
      fields: <KristalModuleField>[
        KristalModuleField(
            key: 'nome',
            label: 'Nome do equipamento',
            icon: Icons.precision_manufacturing_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'setor',
            label: 'Setor',
            icon: Icons.domain_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'ip',
            label: 'IP',
            icon: Icons.router_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'porta',
            label: 'Porta',
            icon: Icons.settings_ethernet_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'protocolo',
            label: 'Protocolo',
            icon: Icons.hub_rounded,
            maxLines: 1,
            required: true),
      ],
      primaryColumns: <String>['nome', 'setor', 'ip', 'porta', 'protocolo'],
    );
  }
}
