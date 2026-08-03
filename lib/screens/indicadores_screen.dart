import 'package:flutter/material.dart';

import '../services/indicadores_service.dart';

class IndicadoresScreen extends StatefulWidget {
  const IndicadoresScreen({super.key});

  @override
  State<IndicadoresScreen> createState() => _IndicadoresScreenState();
}

class _IndicadoresScreenState extends State<IndicadoresScreen> {
  Map<String, int> indicadores = <String, int>{};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final Map<String, int> data =
        await IndicadoresService.instance.carregarIndicadores();

    if (!mounted) return;

    setState(() {
      indicadores = data;
      loading = false;
    });
  }

  IconData _icon(String title) {
    if (title.contains('críticos')) return Icons.warning_amber;
    if (title.contains('Amostras')) return Icons.qr_code;
    if (title.contains('Laudos')) return Icons.picture_as_pdf;
    if (title.contains('Equipamentos')) return Icons.precision_manufacturing;
    if (title.contains('Pacientes')) return Icons.people;
    if (title.contains('Resultados')) return Icons.fact_check;
    return Icons.analytics;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Indicadores Laboratoriais'),
        actions: <Widget>[
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: indicadores.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.55,
              ),
              itemBuilder: (BuildContext context, int index) {
                final MapEntry<String, int> entry =
                    indicadores.entries.elementAt(index);

                return Card(
                  child: Center(
                    child: ListTile(
                      leading: Icon(_icon(entry.key), size: 42),
                      title: Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(entry.key),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
