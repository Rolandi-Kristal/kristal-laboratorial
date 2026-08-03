import 'package:flutter/material.dart';

import '../widgets/simple_crud_screen.dart';

class ExamesScreen extends StatelessWidget {
  const ExamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleCrudScreen(
      title: 'Central de Exames',
      table: 'exames',
      fields: <String>[
        'id',
        'codigo',
        'nome',
        'setor',
        'material',
        'metodo',
        'referencia',
        'valorCheio',
        'valorIndenizar20',
        'codigoCadebens',
        'ativo',
        'criadoEm',
      ],
      visibleFields: <String>['codigo', 'nome', 'setor'],
    );
  }
}
