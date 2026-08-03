import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/export_csv_service.dart';

class ExportacoesScreen extends StatefulWidget {
  final AuthSession session;

  const ExportacoesScreen({
    super.key,
    required this.session,
  });

  @override
  State<ExportacoesScreen> createState() => _ExportacoesScreenState();
}

class _ExportacoesScreenState extends State<ExportacoesScreen> {
  String tabela = 'pacientes';
  String mensagem = 'Nenhuma exportação realizada nesta sessão.';
  bool exporting = false;

  final List<String> tabelas = const <String>[
    'pacientes',
    'exames',
    'atendimentos',
    'agendamentos',
    'cadebens_integracao',
    'pedidos',
    'amostras',
    'resultados',
    'laudos',
    'equipamentos',
    'usuarios',
    'auditoria',
  ];

  Future<void> _exportar() async {
    if (exporting) return;

    setState(() => exporting = true);

    try {
      final String path = await ExportCsvService.instance.exportarTabela(
        tabela: tabela,
        usuario: widget.session.login,
      );

      if (!mounted) return;

      setState(() {
        mensagem = 'Arquivo CSV exportado em: $path';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        mensagem = 'Erro ao exportar: $e';
      });
    } finally {
      if (mounted) {
        setState(() => exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool podeExportar = widget.session.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportações CSV'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Exportação de dados'),
              subtitle: Text(
                podeExportar
                    ? 'Selecione a tabela e gere o arquivo CSV.'
                    : 'Acesso restrito ao Superusuário e Administrador.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: tabela,
            decoration: const InputDecoration(
              labelText: 'Tabela',
              border: OutlineInputBorder(),
            ),
            items: tabelas
                .map(
                  (String item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChanged: podeExportar
                ? (String? value) {
                    if (value == null) return;
                    setState(() => tabela = value);
                  }
                : null,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: podeExportar && !exporting ? _exportar : null,
            icon: exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(exporting ? 'Exportando...' : 'Exportar CSV'),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(mensagem),
            ),
          ),
        ],
      ),
    );
  }
}
