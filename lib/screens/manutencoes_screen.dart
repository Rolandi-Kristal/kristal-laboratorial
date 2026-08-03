import 'package:flutter/material.dart';

import '../widgets/simple_crud_screen.dart';

class ManutencoesScreen extends StatelessWidget {
  const ManutencoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleCrudScreen(
      title: 'Manutenções de Equipamentos',
      table: 'manutencoes',
      fields: <String>[
        'id',
        'equipamentoId',
        'tipo',
        'realizadaEm',
        'proximaEm',
        'responsavel',
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
