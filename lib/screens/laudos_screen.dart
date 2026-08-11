import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/lab_repository.dart';
import '../services/laudo_automatico_service.dart';
import '../services/laudo_liberacao_service.dart';
import '../services/pdf_laudo_service.dart';

class LaudosScreen extends StatefulWidget {
  final AuthSession session;

  const LaudosScreen({
    super.key,
    required this.session,
  });

  @override
  State<LaudosScreen> createState() => _LaudosScreenState();
}

class _LaudosScreenState extends State<LaudosScreen> {
  final LabRepository repo = LabRepository();
  List<Map<String, dynamic>> laudos = <Map<String, dynamic>>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await repo.all('laudos', orderBy: 'criadoEm DESC');

    if (!mounted) return;

    setState(() {
      laudos = data;
      loading = false;
    });
  }

  Future<void> _laudarTodos() async {
    try {
      final int total =
          await LaudoAutomaticoService.instance.laudarTodosRegistrados();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$total laudo(s) gerado(s).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao laudar exames: $e')),
      );
    }
  }

  Future<void> _liberar(String id) async {
    try {
      await LaudoLiberacaoService.instance.liberarLaudo(
        session: widget.session,
        laudoId: id,
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao liberar: $e')),
      );
    }
  }

  Future<void> _cancelar(String id) async {
    final TextEditingController motivo = TextEditingController();

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancelar laudo'),
          content: TextField(
            controller: motivo,
            decoration: const InputDecoration(
              labelText: 'Motivo do cancelamento',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      try {
        await LaudoLiberacaoService.instance.cancelarLaudo(
          session: widget.session,
          laudoId: id,
          motivo: motivo.text.trim(),
        );
        await _load();
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao cancelar: $e')),
        );
      }
    }

    motivo.dispose();
  }

  Future<void> _gerarPdf(Map<String, dynamic> laudo) {
    return PdfLaudoService.instance.gerarLaudoPdf(laudo);
  }

  @override
  Widget build(BuildContext context) {
    final bool podeLiberar = widget.session.isSuperUser ||
        widget.session.perfil.toUpperCase() == 'RESPONSAVEL_TECNICO';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laudos PDF'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Laudar todos os exames registrados',
            onPressed: _laudarTodos,
            icon: const Icon(Icons.playlist_add_check),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : laudos.isEmpty
              ? const Center(child: Text('Nenhum laudo cadastrado.'))
              : ListView.builder(
                  itemCount: laudos.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> laudo = laudos[index];
                    final String id = laudo['id']?.toString() ?? '';
                    final String status = laudo['status']?.toString() ?? '';

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          status == 'LIBERADO'
                              ? Icons.verified
                              : Icons.picture_as_pdf,
                        ),
                        title: Text('Laudo $id'),
                        subtitle: Text(
                          'Pedido: ${laudo['pedidoId'] ?? ''} | Status: $status',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: <Widget>[
                            ElevatedButton.icon(
                              onPressed: () => _gerarPdf(laudo),
                              icon: const Icon(Icons.print),
                              label: const Text('PDF'),
                            ),
                            if (podeLiberar && status != 'LIBERADO')
                              ElevatedButton.icon(
                                onPressed: () => _liberar(id),
                                icon: const Icon(Icons.verified),
                                label: const Text('Liberar'),
                              ),
                            if (widget.session.isSuperUser &&
                                status != 'CANCELADO')
                              IconButton(
                                tooltip: 'Cancelar laudo',
                                onPressed: () => _cancelar(id),
                                icon: const Icon(Icons.cancel),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
