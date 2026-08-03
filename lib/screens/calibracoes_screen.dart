import 'package:flutter/material.dart';

import '../widgets/simple_crud_screen.dart';

class CalibracoesScreen extends StatelessWidget {
  const CalibracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleCrudScreen(
      title: 'Calibrações',
      table: 'calibracoes',
      fields: <String>[
        'id',
        'equipamentoId',
        'tipo',
        'realizadaEm',
        'proximaEm',
        'responsavel',
        'resultado',
        'status',
        'observacao',
      ],
      visibleFields: <String>[
        'equipamentoId',
        'tipo',
        'status',
      ],
    );
  }
}
