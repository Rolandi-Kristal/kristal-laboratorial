import 'package:flutter/material.dart';

import '../services/etiqueta_pdf_service.dart';
import '../services/sample_code_service.dart';

class EtiquetaPrintScreen extends StatefulWidget {
  const EtiquetaPrintScreen({super.key});

  @override
  State<EtiquetaPrintScreen> createState() => _EtiquetaPrintScreenState();
}

class _EtiquetaPrintScreenState extends State<EtiquetaPrintScreen> {
  final TextEditingController codigo = TextEditingController();
  final TextEditingController pacienteId = TextEditingController();
  final TextEditingController pedidoId = TextEditingController();
  final TextEditingController exameId = TextEditingController();
  final TextEditingController material = TextEditingController();

  @override
  void dispose() {
    codigo.dispose();
    pacienteId.dispose();
    pedidoId.dispose();
    exameId.dispose();
    material.dispose();
    super.dispose();
  }

  void _gerarCodigo() {
    if (pacienteId.text.trim().isEmpty ||
        pedidoId.text.trim().isEmpty ||
        exameId.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe paciente, pedido e exame.')),
      );
      return;
    }

    setState(() {
      codigo.text = SampleCodeService.gerarCodigoAmostra(
        pacienteId: pacienteId.text.trim(),
        pedidoId: pedidoId.text.trim(),
        exameId: exameId.text.trim(),
      );
    });
  }

  Future<void> _imprimir() {
    return EtiquetaPdfService.instance.imprimirEtiqueta(
      codigo: codigo.text.trim(),
      pacienteId: pacienteId.text.trim(),
      pedidoId: pedidoId.text.trim(),
      exameId: exameId.text.trim(),
      material: material.text.trim(),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impressão de Etiquetas'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          _field(pacienteId, 'Paciente ID', Icons.person),
          _field(pedidoId, 'Pedido ID', Icons.assignment),
          _field(exameId, 'Exame ID', Icons.biotech),
          _field(material, 'Material', Icons.science),
          _field(codigo, 'Código da etiqueta', Icons.qr_code),
          Wrap(
            spacing: 12,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: _gerarCodigo,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Gerar código'),
              ),
              ElevatedButton.icon(
                onPressed: codigo.text.trim().isEmpty ? null : _imprimir,
                icon: const Icon(Icons.print),
                label: const Text('Imprimir etiqueta'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
