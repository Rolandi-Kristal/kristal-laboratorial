import 'package:flutter/material.dart';

import '../services/system_health_service.dart';

class SystemHealthScreen extends StatefulWidget {
  const SystemHealthScreen({super.key});

  @override
  State<SystemHealthScreen> createState() => _SystemHealthScreenState();
}

class _SystemHealthScreenState extends State<SystemHealthScreen> {
  List<SystemHealthStatus> items = <SystemHealthStatus>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => loading = true);

    final List<SystemHealthStatus> data =
        await SystemHealthService.instance.check();

    if (!mounted) return;

    setState(() {
      items = data;
      loading = false;
    });
  }

  int get totalOk => items.where((SystemHealthStatus e) => e.ok).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico do Sistema'),
        actions: <Widget>[
          IconButton(
            onPressed: _check,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar diagnóstico',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                Card(
                  child: ListTile(
                    leading: Icon(
                      totalOk == items.length
                          ? Icons.verified
                          : Icons.warning_amber,
                    ),
                    title: Text('$totalOk de ${items.length} verificações OK'),
                    subtitle: const Text(
                      'Diagnóstico técnico local da KRISTAL LABORATORIAL.',
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (BuildContext context, int index) {
                      final SystemHealthStatus item = items[index];

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            item.ok ? Icons.check_circle : Icons.error,
                            color:
                                item.ok ? Colors.greenAccent : Colors.redAccent,
                          ),
                          title: Text(item.item),
                          subtitle: Text(item.detalhe),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
