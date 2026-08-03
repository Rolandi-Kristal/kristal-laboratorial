import 'package:flutter/material.dart';

import '../models/lab_exam_definition.dart';
import '../services/barcode_exam_identification_service.dart';
import '../widgets/kristal_shell.dart';

class CodigoBarrasEtiquetasScreen extends StatefulWidget {
  const CodigoBarrasEtiquetasScreen({super.key});

  @override
  State<CodigoBarrasEtiquetasScreen> createState() =>
      _CodigoBarrasEtiquetasScreenState();
}

class _CodigoBarrasEtiquetasScreenState
    extends State<CodigoBarrasEtiquetasScreen> {
  final BarcodeExamIdentificationService _service =
      BarcodeExamIdentificationService();
  final TextEditingController _barcodeController = TextEditingController();

  BarcodeExamIdentification? _identification;

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _identify() async {
    final BarcodeExamIdentification identification =
        await _service.identify(_barcodeController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _identification = identification;
    });
  }

  @override
  Widget build(BuildContext context) {
    return KristalShell(
      title: 'Código de Barras / Etiquetas',
      subtitle: 'Identificação automática de amostra, etiqueta e tipo de exame',
      icon: Icons.qr_code_scanner,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 430,
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _barcodeController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _identify(),
                    decoration: const InputDecoration(
                      labelText: 'Leia ou digite o código de barras',
                      hintText: 'ETQ123|PAC456|PED789|EX=GLI,CRE,URE',
                      prefixIcon: Icon(Icons.qr_code),
                      filled: true,
                      fillColor: Color(0xFF071827),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _identify,
                    icon: const Icon(Icons.search),
                    label: const Text('Identificar automaticamente'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Compatível com leitor USB tipo teclado. Configure o leitor para enviar ENTER após a leitura.',
                    style: TextStyle(color: Color(0xFFB7D7F1)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(child: _resultPanel()),
          ],
        ),
      ),
    );
  }

  Widget _resultPanel() {
    final BarcodeExamIdentification? identification = _identification;

    if (identification == null) {
      return const Center(
        child: Text(
          'Aguardando leitura da etiqueta.',
          style: TextStyle(color: Color(0xFFB7D7F1), fontSize: 18),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2033),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF244B6D)),
      ),
      child: ListView(
        children: <Widget>[
          _info('Tipo de etiqueta', identification.labelType),
          _info('Código bruto', identification.rawBarcode),
          _info('Amostra', identification.sampleCode),
          _info('Paciente', identification.patientCode),
          _info('Pedido', identification.orderCode),
          _info('Tubo / Material inferido', identification.tubeNumber),
          _info(
            'Confiança',
            '${(identification.confidence * 100).toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 16),
          const Text(
            'Exames identificados',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          if (identification.detectedExams.isEmpty)
            const Text(
              'Nenhum exame identificado automaticamente.',
              style: TextStyle(color: Color(0xFFFFC857)),
            )
          else
            ...identification.detectedExams.map(_examTile),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        '$label: ${value.isEmpty ? '-' : value}',
        style: const TextStyle(color: Color(0xFFEAF3FF), fontSize: 15),
      ),
    );
  }

  Widget _examTile(LabExamDefinition exam) {
    return Card(
      color: const Color(0xFF071827),
      child: ListTile(
        leading: const Icon(Icons.science, color: Color(0xFF73D7FF)),
        title: Text(
          '${exam.code} • ${exam.name}',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${exam.sector} • ${exam.material} • SIRE ${exam.sireCode}',
          style: const TextStyle(color: Color(0xFFB7D7F1)),
        ),
      ),
    );
  }
}
