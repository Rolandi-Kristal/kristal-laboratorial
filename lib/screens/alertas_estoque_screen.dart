import 'package:flutter/material.dart';

import '../services/estoque_service.dart';

class AlertasEstoqueScreen extends StatefulWidget {
  const AlertasEstoqueScreen({super.key});

  @override
  State<AlertasEstoqueScreen> createState() => _AlertasEstoqueScreenState();
}

class _AlertasEstoqueScreenState extends State<AlertasEstoqueScreen> {
  List<Map<String, dynamic>> vencendo = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> criticos = <Map<String, dynamic>>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<Map<String, dynamic>> v =
        await EstoqueService.instance.lotesVencendo();
    final List<Map<String, dynamic>> c =
        await EstoqueService.instance.estoqueCritico();

    if (!mounted) return;

    setState(() {
      vencendo = v;
      criticos = c;
      loading = false;
    });
  }

  Widget _section(
      String title, List<Map<String, dynamic>> rows, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const Text('Nenhum alerta.')
            else
              ...rows.map(
                (Map<String, dynamic> row) => ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: Text(row['nome']?.toString() ??
                      row['materialId']?.toString() ??
                      ''),
                  subtitle: Text(row.entries
                      .take(6)
                      .map((MapEntry<String, dynamic> e) =>
                          '${e.key}: ${e.value}')
                      .join(' | ')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de Estoque'),
        actions: <Widget>[
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: <Widget>[
                _section('Lotes vencendo em até 30 dias', vencendo,
                    Icons.event_busy),
                _section('Estoque crítico', criticos, Icons.inventory),
              ],
            ),
    );
  }
}
