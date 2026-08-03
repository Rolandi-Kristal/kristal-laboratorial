import 'package:flutter/material.dart';

import '../services/pdf_laudo_service.dart';
import '../services/portal_access_service.dart';

class PortalPacienteAcessoScreen extends StatefulWidget {
  const PortalPacienteAcessoScreen({super.key});

  @override
  State<PortalPacienteAcessoScreen> createState() =>
      _PortalPacienteAcessoScreenState();
}

class _PortalPacienteAcessoScreenState
    extends State<PortalPacienteAcessoScreen> {
  final TextEditingController cpfController = TextEditingController();
  final TextEditingController tokenController = TextEditingController();

  List<Map<String, dynamic>> laudos = <Map<String, dynamic>>[];
  bool loading = false;
  String mensagem = 'Informe CPF e token para consultar laudos liberados.';

  @override
  void dispose() {
    cpfController.dispose();
    tokenController.dispose();
    super.dispose();
  }

  Future<void> _consultar() async {
    setState(() {
      loading = true;
      mensagem = 'Consultando...';
    });

    final List<Map<String, dynamic>> data =
        await PortalAccessService.instance.consultarLaudosLiberados(
      cpf: cpfController.text.trim(),
      token: tokenController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      laudos = data;
      mensagem = data.isEmpty
          ? 'Nenhum laudo liberado encontrado para os dados informados.'
          : '${data.length} laudo(s) liberado(s) encontrado(s).';
      loading = false;
    });
  }

  Future<void> _abrirPdf(Map<String, dynamic> laudo) {
    return PdfLaudoService.instance.gerarLaudoPdf(laudo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acesso do Paciente'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Consulta protegida'),
              subtitle: Text(mensagem),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cpfController,
            decoration: const InputDecoration(
              labelText: 'CPF',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tokenController,
            decoration: const InputDecoration(
              labelText: 'Token de acesso',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: loading ? null : _consultar,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(loading ? 'Consultando...' : 'Consultar laudos'),
          ),
          const SizedBox(height: 18),
          ...laudos.map(
            (Map<String, dynamic> laudo) => Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text('Laudo ${laudo['id'] ?? ''}'),
                subtitle: Text('Pedido: ${laudo['pedidoId'] ?? ''}'),
                trailing: ElevatedButton.icon(
                  onPressed: () => _abrirPdf(laudo),
                  icon: const Icon(Icons.print),
                  label: const Text('Abrir PDF'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
