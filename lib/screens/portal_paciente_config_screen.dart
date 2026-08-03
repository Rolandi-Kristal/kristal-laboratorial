import 'package:flutter/material.dart';

import '../services/portal_paciente_service.dart';
import '../services/portal_web_runtime_service.dart';

class PortalPacienteConfigScreen extends StatefulWidget {
  const PortalPacienteConfigScreen({super.key});

  @override
  State<PortalPacienteConfigScreen> createState() =>
      _PortalPacienteConfigScreenState();
}

class _PortalPacienteConfigScreenState
    extends State<PortalPacienteConfigScreen> {
  final TextEditingController urlController = TextEditingController();

  String status = 'Configure o endereco web do portal do paciente.';
  String runtimeStatus = 'Portal web local ainda nao verificado.';

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
    await PortalPacienteService.instance.setPortalUrl(
      urlController.text.trim(),
    );
    if (!mounted) return;
    setState(() => status = 'Portal atualizado.');
  }

  Future<void> _gerarTokenTeste() async {
    final String token = PortalPacienteService.instance.gerarTokenPaciente(
      cpf: '00000000000',
      pedidoId: 'PEDIDO-TESTE',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Token de teste: $token')),
    );
  }

  Future<void> _iniciarPortal() async {
    final String result = await PortalWebRuntimeService.instance.start();
    if (!mounted) return;
    setState(() => runtimeStatus = result);
  }

  Future<void> _pararPortal() async {
    final String result = await PortalWebRuntimeService.instance.stop();
    if (!mounted) return;
    setState(() => runtimeStatus = result);
  }

  Future<void> _verificarPortal() async {
    final String result = await PortalWebRuntimeService.instance.health();
    if (!mounted) return;
    setState(() => runtimeStatus = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal Web do Paciente'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Portal para baixar e imprimir exames'),
              subtitle: Text(status),
            ),
          ),
          TextField(
            controller: urlController,
            decoration: const InputDecoration(
              labelText: 'URL do portal do paciente',
              hintText: 'http://127.0.0.1:8787',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Salvar configuracao'),
              ),
              ElevatedButton.icon(
                onPressed: _gerarTokenTeste,
                icon: const Icon(Icons.key),
                label: const Text('Gerar token de teste'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Portal web integrado ao KRISTAL'),
              subtitle: Text(runtimeStatus),
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: _iniciarPortal,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar portal local'),
              ),
              ElevatedButton.icon(
                onPressed: _verificarPortal,
                icon: const Icon(Icons.health_and_safety),
                label: const Text('Verificar /health'),
              ),
              OutlinedButton.icon(
                onPressed: _pararPortal,
                icon: const Icon(Icons.stop),
                label: const Text('Parar portal'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Paciente: ${PortalWebRuntimeService.instance.urlPaciente}'),
          Text('Admin: ${PortalWebRuntimeService.instance.urlAdmin}'),
        ],
      ),
    );
  }
}
