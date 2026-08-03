import 'package:flutter/material.dart';

import '../widgets/simple_crud_screen.dart';

class MateriaisScreen extends StatelessWidget {
  const MateriaisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleCrudScreen(
      title: 'Materiais, Reagentes e Insumos',
      table: 'materiais',
      fields: <String>[
        'id',
        'codigo',
        'nome',
        'tipo',
        'unidade',
        'estoqueMinimo',
        'ativo',
        'criadoEm',
      ],
      visibleFields: <String>[
        'codigo',
        'nome',
        'tipo',
      ],
    );
  }
}
