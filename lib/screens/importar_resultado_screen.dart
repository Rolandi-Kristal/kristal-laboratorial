import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/result_import_service.dart';

class ImportarResultadoScreen extends StatefulWidget {
  final AuthSession session;

  const ImportarResultadoScreen({
    super.key,
    required this.session,
  });

  @override
  State<ImportarResultadoScreen> createState() => _ImportarResultadoScreenState();
}

class _ImportarResultadoScreenState extends State<ImportarResultadoScreen> {
  final TextEditingController entrada = TextEditingController();
  final TextEditingController saida = TextEditingController();

  String protocolo = 'ASTM';
  bool importing = false;

  @override
  void dispose() {
    entrada.dispose();
    saida.dispose();
    super.dispose();
  }

  Future<void> _importar() async {
    if (importing) return;

    setState(() => importing = true);

    try {
      final Map<String, dynamic> resultado =
          await ResultImportService.instance.importarMensagem(
        protocolo: protocolo,
        mensagem: entrada.text,
        usuario: widget.session.login,
      );

      saida.text = resultado.entries
          .map((MapEntry<String, dynamic> e) => '${e.key}: ${e.value}')
          .join('\n');
    } catch (e) {
      saida.text = 'Erro ao importar: $e';
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Resultado de Equipamento'),
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
              DropdownMenuItem(value: 'HL7', child: Text('HL7 ORU')),
            ],
            onChanged: (String? value) {
              if (value == null) return;
              setState(() => protocolo = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: entrada,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Mensagem recebida',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: importing ? null : _importar,
            icon: importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload),
            label: Text(importing ? 'Importando...' : 'Importar resultado'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: saida,
            readOnly: true,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Resultado importado',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
