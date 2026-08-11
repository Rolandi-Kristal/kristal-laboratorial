import 'package:flutter/material.dart';

import '../services/etiqueta_service.dart';

class LeituraEtiquetaScreen extends StatefulWidget {
  const LeituraEtiquetaScreen({super.key});

  @override
  State<LeituraEtiquetaScreen> createState() => _LeituraEtiquetaScreenState();
}

class _LeituraEtiquetaScreenState extends State<LeituraEtiquetaScreen> {
  final TextEditingController codigoController = TextEditingController();
  final TextEditingController pacienteController = TextEditingController();
  final TextEditingController pedidoController = TextEditingController();
  final TextEditingController exameController = TextEditingController();
  final TextEditingController imagemController = TextEditingController();
  final TextEditingController observacaoController = TextEditingController();

  String tipoLeitura = 'LASER_USB';
  String status = 'Aguardando leitura da etiqueta.';
  bool salvando = false;

  @override
  void dispose() {
    codigoController.dispose();
    pacienteController.dispose();
    pedidoController.dispose();
    exameController.dispose();
    imagemController.dispose();
    observacaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (salvando) return;

    final String codigo = codigoController.text.trim();

    if (codigo.isEmpty) {
      _msg('Informe ou leia o código da etiqueta.');
      return;
    }

    setState(() => salvando = true);

    final bool duplicado = await EtiquetaService.instance.codigoExiste(codigo);

    if (duplicado) {
      if (!mounted) return;
      setState(() {
        status = 'Etiqueta já utilizada. Verifique a amostra.';
        salvando = false;
      });
      _msg('Etiqueta já utilizada.');
      return;
    }

    await EtiquetaService.instance.salvarEtiqueta(
      codigoBarras: codigo,
      codigoManual: codigo,
      tipoLeitura: tipoLeitura,
      pacienteId: pacienteController.text.trim(),
      pedidoId: pedidoController.text.trim(),
      exameId: exameController.text.trim(),
      imagemPath: imagemController.text.trim(),
      observacao: observacaoController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      status = 'Etiqueta vinculada ao exame com sucesso.';
      salvando = false;
    });

    _msg('Etiqueta salva e auditada.');
    codigoController.clear();
    observacaoController.clear();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    int minLines = 1,
    int maxLines = 1,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
      ),
      onSubmitted: onSubmitted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitura de Etiqueta / Código de Barras'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                status,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _field(
            controller: codigoController,
            label: 'Código da etiqueta / leitura laser USB',
            icon: Icons.qr_code_scanner,
            onSubmitted: (_) => _salvar(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: tipoLeitura,
            decoration: const InputDecoration(
              labelText: 'Tipo de leitura',
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(
                  value: 'LASER_USB', child: Text('Leitor laser/USB')),
              DropdownMenuItem(value: 'MANUAL', child: Text('Inserção manual')),
              DropdownMenuItem(
                  value: 'IMAGEM', child: Text('Imagem da etiqueta')),
            ],
            onChanged: (String? value) {
              if (value == null) return;
              setState(() => tipoLeitura = value);
            },
          ),
          const SizedBox(height: 12),
          _field(
              controller: pacienteController,
              label: 'Paciente ID',
              icon: Icons.person),
          const SizedBox(height: 12),
          _field(
              controller: pedidoController,
              label: 'Pedido ID',
              icon: Icons.assignment),
          const SizedBox(height: 12),
          _field(
              controller: exameController,
              label: 'Exame ID',
              icon: Icons.biotech),
          const SizedBox(height: 12),
          _field(
              controller: imagemController,
              label: 'Caminho da imagem',
              icon: Icons.image),
          const SizedBox(height: 12),
          _field(
              controller: observacaoController,
              label: 'Observação',
              minLines: 2,
              maxLines: 4),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: salvando ? null : _salvar,
            icon: const Icon(Icons.save),
            label:
                Text(salvando ? 'Salvando...' : 'Vincular etiqueta ao exame'),
          ),
        ],
      ),
    );
  }
}
