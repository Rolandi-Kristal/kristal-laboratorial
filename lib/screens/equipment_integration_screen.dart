import 'package:flutter/material.dart';

import '../services/equipment_adapter_service.dart';
import '../services/lab_repository.dart';

class EquipmentIntegrationScreen extends StatefulWidget {
  const EquipmentIntegrationScreen({super.key});

  @override
  State<EquipmentIntegrationScreen> createState() =>
      _EquipmentIntegrationScreenState();
}

class _EquipmentIntegrationScreenState
    extends State<EquipmentIntegrationScreen> {
  final TextEditingController entradaController = TextEditingController();
  final TextEditingController saidaController = TextEditingController();

  final LabRepository repo = LabRepository();

  String protocolo = 'ASTM';

  @override
  void dispose() {
    entradaController.dispose();
    saidaController.dispose();
    super.dispose();
  }

  Future<void> _instalarPerfis() async {
    for (final profile in EquipmentAdapterService.instance.perfisPadrao()) {
      await repo.upsert('equipamentos', profile.toMap());
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfis de equipamentos instalados.')),
    );
  }

  void _processarEntrada() {
    final String entrada = entradaController.text;

    final Map<String, String> parsed = protocolo == 'HL7'
        ? EquipmentAdapterService.instance.parseHl7Oru(entrada)
        : EquipmentAdapterService.instance.parseAstmResult(entrada);

    setState(() {
      saidaController.text = parsed.entries
          .map((MapEntry<String, String> e) => '${e.key}: ${e.value}')
          .join('\n');
    });
  }

  void _gerarWorklist() {
    final String mensagem = protocolo == 'HL7'
        ? EquipmentAdapterService.instance.buildHl7Orm(
            pacienteId: 'PACIENTE-001',
            pedidoId: 'PEDIDO-001',
            exameCodigo: 'HEM',
            amostraId: 'AMOSTRA-001',
          )
        : EquipmentAdapterService.instance.buildAstmOrder(
            pacienteId: 'PACIENTE-001',
            pedidoId: 'PEDIDO-001',
            exameCodigo: 'HEM',
            amostraId: 'AMOSTRA-001',
          );

    setState(() {
      saidaController.text = mensagem;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integração com Equipamentos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Instalar perfis padrão',
            onPressed: _instalarPerfis,
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          DropdownButtonFormField<String>(
            value: protocolo,
            decoration: const InputDecoration(
              labelText: 'Protocolo',
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'ASTM', child: Text('ASTM')),
              DropdownMenuItem(value: 'HL7', child: Text('HL7 ORU/ORM')),
            ],
            onChanged: (String? value) {
              if (value == null) return;
              setState(() => protocolo = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: entradaController,
            minLines: 8,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Mensagem recebida do equipamento',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: _processarEntrada,
                icon: const Icon(Icons.input),
                label: const Text('Processar entrada'),
              ),
              ElevatedButton.icon(
                onPressed: _gerarWorklist,
                icon: const Icon(Icons.send),
                label: const Text('Gerar Worklist ORM/ASTM'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: saidaController,
            minLines: 8,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Saída / resultado processado',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
