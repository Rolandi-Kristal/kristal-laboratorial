import 'package:flutter/material.dart';
import '../widgets/simple_crud_screen.dart';

class QualidadeScreen extends StatelessWidget {
  const QualidadeScreen({super.key});
  @override
  Widget build(BuildContext context) => const SimpleCrudScreen(
          title: 'Controle de Qualidade',
          table: 'qualidade',
          fields: [
            'id',
            'setor',
            'controle',
            'nivel',
            'resultado',
            'esperado',
            'status',
            'responsavel',
            'criadoEm'
          ],
          visibleFields: [
            'setor',
            'controle',
            'status'
          ]);
}
