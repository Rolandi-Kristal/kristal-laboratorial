import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class PbilBenchmarkingScreen extends StatelessWidget {
  const PbilBenchmarkingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'PBIL Benchmarking',
      subtitle: 'Indicadores laboratoriais SBPC/ML, Controllab e mercado',
      icon: Icons.leaderboard_rounded,
      module: 'pbil_benchmarking',
      actionLabel: 'Registrar indicador PBIL',
      fields: <KristalModuleField>[
        KristalModuleField(
          key: 'periodo',
          label: 'Período',
          icon: Icons.date_range_rounded,
        ),
        KristalModuleField(
          key: 'indicador',
          label: 'Indicador',
          icon: Icons.bar_chart_rounded,
        ),
        KristalModuleField(
          key: 'valorLaboratorio',
          label: 'Valor do laboratório',
          icon: Icons.speed_rounded,
        ),
        KristalModuleField(
          key: 'unidade',
          label: 'Unidade',
          icon: Icons.straighten_rounded,
        ),
        KristalModuleField(
          key: 'p50Mercado',
          label: 'PBIL P50 / mediana',
          icon: Icons.compare_arrows_rounded,
        ),
        KristalModuleField(
          key: 'p75Mercado',
          label: 'PBIL P75',
          icon: Icons.trending_up_rounded,
          required: false,
        ),
        KristalModuleField(
          key: 'p90Mercado',
          label: 'PBIL P90',
          icon: Icons.show_chart_rounded,
          required: false,
        ),
        KristalModuleField(
          key: 'fonte',
          label: 'Fonte (PBIL/SBPC-ML/Controllab)',
          icon: Icons.source_rounded,
        ),
        KristalModuleField(
          key: 'statusComparacao',
          label: 'Status comparativo',
          icon: Icons.verified_rounded,
        ),
        KristalModuleField(
          key: 'acaoGestao',
          label: 'Ação de gestão',
          icon: Icons.task_alt_rounded,
          maxLines: 3,
          required: false,
        ),
      ],
      primaryColumns: <String>[
        'periodo',
        'indicador',
        'valorLaboratorio',
        'statusComparacao',
      ],
    );
  }
}
