import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class RelatoriosGerenciaisScreen extends StatelessWidget {
  const RelatoriosGerenciaisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Relatórios Gerenciais',
      subtitle: 'Indicadores, estatística e exportações',
      icon: Icons.bar_chart_rounded,
      module: 'relatorios_gerenciais',
      fields: <KristalModuleField>[
    KristalModuleField(key: 'indicador', label: 'Indicador', icon: Icons.bar_chart_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'periodo', label: 'Período', icon: Icons.date_range_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'valor', label: 'Valor', icon: Icons.calculate_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'setor', label: 'Setor', icon: Icons.domain_rounded, maxLines: 1, required: true),
    KristalModuleField(key: 'observacao', label: 'Observação', icon: Icons.notes_rounded, maxLines: 3, required: false),
      ],
      primaryColumns: <String>['indicador', 'periodo', 'valor', 'setor'],
    );
  }
}
