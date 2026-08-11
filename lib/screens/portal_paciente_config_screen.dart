import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/log_service.dart';
import '../services/portal_paciente_service.dart';

class PortalPacienteConfigScreen extends StatefulWidget {
  const PortalPacienteConfigScreen({super.key});

  @override
  State<PortalPacienteConfigScreen> createState() =>
      _PortalPacienteConfigScreenState();
}

class _PortalPacienteConfigScreenState
    extends State<PortalPacienteConfigScreen> {
  final TextEditingController urlController = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final String url = await PortalPacienteService.instance.getPortalUrl();
    if (!mounted) return;
    setState(() => urlController.text = url);
  }

  Future<void> _save() async {
    final Uri? uri = Uri.tryParse(urlController.text.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma URL HTTPS válida.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await PortalPacienteService.instance.setPortalUrl(
        uri.toString().replaceAll(RegExp(r'/+$'), ''),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Portal atualizado.')),
      );
    } on DatabaseException catch (error, stackTrace) {
      await LogService.instance
          .error('PORTAL_CONFIG_DATABASE', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao salvar o portal: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portal Web do Paciente')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'URL HTTPS do portal do paciente',
              hintText: 'https://10.4.169.64:8787',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.language),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Salvar'),
            ),
          ),
        ],
      ),
    );
  }
}
