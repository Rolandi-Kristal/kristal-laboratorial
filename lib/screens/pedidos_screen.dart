import 'package:flutter/material.dart';

import '../widgets/simple_crud_screen.dart';

class PedidosScreen extends StatelessWidget {
  const PedidosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleCrudScreen(
      title: 'Pedidos',
      table: 'pedidos',
      fields: <String>[
        'id',
        'agendamentoId',
        'pacienteId',
        'medicoSolicitante',
        'prioridade',
        'status',
        'valorCheio',
        'valorIndenizar20',
        'cadebensNumero',
        'criadoEm',
        'observacao',
      ],
      visibleFields: <String>['pacienteId', 'prioridade', 'status'],
    );
  }
}
