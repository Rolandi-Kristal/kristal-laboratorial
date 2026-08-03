import 'package:flutter/material.dart';

import '../widgets/simple_crud_screen.dart';

class EquipmentProfilesScreen extends StatelessWidget {
  const EquipmentProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleCrudScreen(
      title: 'Perfis de Equipamentos Laboratoriais',
      table: 'equipamentos',
      fields: <String>[
        'id',
        'nome',
        'fabricante',
        'modelo',
        'protocolo',
        'conexao',
        'porta',
        'ip',
        'baudRate',
        'ativo',
        'criadoEm',
      ],
      visibleFields: <String>[
        'nome',
        'modelo',
        'protocolo',
        'conexao',
      ],
    );
  }
}
