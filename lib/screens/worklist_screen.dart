import 'package:flutter/material.dart';

import '../services/worklist_service.dart';

class WorklistScreen extends StatefulWidget {
  const WorklistScreen({super.key});

  @override
  State<WorklistScreen> createState() => _WorklistScreenState();
}

class _WorklistScreenState extends State<WorklistScreen> {
  String protocolo = 'ASTM';
  List<WorklistItem> items = <WorklistItem>[];
  bool loading = true;
  String saida = 'Selecione um item para gerar a mensagem.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<WorklistItem> data = await WorklistService.instance.pendentes();

    if (!mounted) return;

    setState(() {
      items = data;
      loading = false;
    });
  }

  Future<void> _gerar(WorklistItem item) async {
    final String msg = await WorklistService.instance.gerarMensagem(
      item: item,
      protocolo: protocolo,
    );

    if (!mounted) return;

    setState(() {
      saida = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worklist para Equipamentos'),
        actions: <Widget>[
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Row(
        children: <Widget>[
          SizedBox(
            width: 430,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: DropdownButtonFormField<String>(
                    value: protocolo,
                    decoration: const InputDecoration(
                      labelText: 'Protocolo de saída',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'ASTM', child: Text('ASTM')),
                      DropdownMenuItem(value: 'HL7', child: Text('HL7 ORM')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) return;
                      setState(() => protocolo = value);
                    },
                  ),
                ),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhum pedido aberto encontrado para Worklist.',
                              ),
                            )
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (BuildContext context, int index) {
                                final WorklistItem item = items[index];

                                return Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.send),
                                    title: Text(
                                      '${item.exameCodigo} • ${item.amostraId}',
                                    ),
                                    subtitle: Text(
                                      'Paciente: ${item.pacienteId} | Pedido: ${item.pedidoId}',
                                    ),
                                    onTap: () => _gerar(item),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: TextEditingController(text: saida),
                readOnly: true,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  labelText: 'Mensagem Worklist gerada',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
