import 'package:flutter/material.dart';
import '../services/etiqueta_service.dart';
import '../widgets/simple_crud_screen.dart';

class EtiquetaExameScreen extends StatefulWidget {
  const EtiquetaExameScreen({super.key});
  @override
  State<EtiquetaExameScreen> createState() => _EtiquetaExameScreenState();
}

class _EtiquetaExameScreenState extends State<EtiquetaExameScreen> {
  final paciente = TextEditingController(),
      pedido = TextEditingController(),
      exame = TextEditingController(),
      codigo = TextEditingController(),
      codigoManual = TextEditingController(),
      imagem = TextEditingController(),
      obs = TextEditingController();
  String tipo = 'LASER_USB';
  bool saving = false;
  @override
  void dispose() {
    for (final c in [
      paciente,
      pedido,
      exame,
      codigo,
      codigoManual,
      imagem,
      obs
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> salvar() async {
    setState(() => saving = true);
    try {
      await EtiquetaService.instance.criarEtiqueta(
          pacienteId: paciente.text.trim(),
          pedidoId: pedido.text.trim(),
          exameId: exame.text.trim(),
          codigoBarras: codigo.text.trim(),
          codigoManual: codigoManual.text.trim(),
          tipoLeitura: tipo,
          imagemPath: imagem.text.trim(),
          observacao: obs.text.trim());
      _msg('Etiqueta vinculada ao exame com sucesso.');
      codigo.clear();
      codigoManual.clear();
    } catch (e) {
      _msg('Erro: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Etiqueta vinculada ao exame')),
      body: Row(children: [
        Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Cadastro de etiqueta por exame',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
              controller: paciente,
              decoration: const InputDecoration(
                  labelText: 'Paciente ID', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
              controller: pedido,
              decoration: const InputDecoration(
                  labelText: 'Pedido ID', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
              controller: exame,
              decoration: const InputDecoration(
                  labelText: 'Exame ID/Código', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
              value: tipo,
              decoration: const InputDecoration(
                  labelText: 'Tipo de leitura', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'LASER_USB', child: Text('Leitura laser/USB')),
                DropdownMenuItem(
                    value: 'MANUAL', child: Text('Digitação manual')),
                DropdownMenuItem(value: 'IMAGEM', child: Text('Imagem anexada'))
              ],
              onChanged: (v) => setState(() => tipo = v ?? 'LASER_USB')),
          const SizedBox(height: 10),
          TextField(
              controller: codigo,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Código lido pelo scanner/laser',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.document_scanner)),
              onSubmitted: (_) => salvar()),
          const SizedBox(height: 10),
          TextField(
              controller: codigoManual,
              decoration: const InputDecoration(
                  labelText: 'Código manual da etiquetadora',
                  border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
              controller: imagem,
              decoration: const InputDecoration(
                  labelText: 'Caminho da imagem da etiqueta/amostra',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image))),
          const SizedBox(height: 10),
          TextField(
              controller: obs,
              decoration: const InputDecoration(
                  labelText: 'Observação', border: OutlineInputBorder())),
          const SizedBox(height: 18),
          ElevatedButton.icon(
              onPressed: saving ? null : salvar,
              icon: const Icon(Icons.save),
              label:
                  Text(saving ? 'SALVANDO...' : 'VINCULAR ETIQUETA AO EXAME'))
        ])),
        Expanded(
            child: SimpleCrudScreen(
                title: 'Etiquetas cadastradas',
                table: 'etiquetas_exames',
                fields: [
              'id',
              'pacienteId',
              'pedidoId',
              'exameId',
              'amostraId',
              'codigoBarras',
              'codigoManual',
              'tipoLeitura',
              'imagemPath',
              'status',
              'criadoEm',
              'criadoPor',
              'observacao'
            ],
                visibleFields: [
              'codigoBarras',
              'exameId',
              'status'
            ]))
      ]));
}
