import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class EstoqueScreen extends StatelessWidget {
  const EstoqueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Estoque',
      subtitle: 'Itens, consumo, validade e rastreabilidade',
      icon: Icons.inventory_2_rounded,
      module: 'estoque',
      fields: <KristalModuleField>[
        KristalModuleField(
            key: 'item',
            label: 'Item',
            icon: Icons.inventory_2_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'lote',
            label: 'Lote',
            icon: Icons.tag_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'validade',
            label: 'Validade',
            icon: Icons.event_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'quantidade',
            label: 'Quantidade',
            icon: Icons.format_list_numbered_rounded,
            maxLines: 1,
            required: true),
        KristalModuleField(
            key: 'fornecedor',
            label: 'Fornecedor',
            icon: Icons.local_shipping_rounded,
            maxLines: 1,
            required: true),
      ],
      primaryColumns: <String>[
        'item',
        'lote',
        'validade',
        'quantidade',
        'fornecedor'
      ],
    );
  }
}
