import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/auth_service.dart';
import '../services/lab_repository.dart';
import '../services/log_service.dart';
import '../services/report_pdf_service.dart';

class RelatoriosScreen extends StatefulWidget {
  final AuthSession session;

  const RelatoriosScreen({
    super.key,
    required this.session,
  });

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  final LabRepository repo = LabRepository();

  String tabela = 'pacientes';
  String mensagem = 'Selecione a tabela para gerar relatório PDF.';
  bool loading = false;

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
    'materiais',
    'estoque',
    'calibracoes',
    'manutencoes',
    'controle_qualidade',
    'auditoria',
  ];

  Future<void> _gerarPdf() async {
    setState(() => loading = true);

    try {
      final List<Map<String, dynamic>> rows = await repo.all(tabela);

      await ReportPdfService.instance.imprimirTabela(
        titulo: 'RELATÓRIO - ${tabela.toUpperCase()}',
        rows: rows,
      );

      if (!mounted) return;

      setState(() {
        mensagem = 'Relatório gerado para a tabela $tabela.';
      });
    } on DatabaseException catch (e, stackTrace) {
      await LogService.instance.error('REPORT_DATABASE', e, stackTrace);
      if (!mounted) return;
      setState(() => mensagem = 'Erro ao gerar relatório: $e');
    } on PlatformException catch (e, stackTrace) {
      await LogService.instance.error('REPORT_PRINT', e, stackTrace);
      if (!mounted) return;
      setState(() => mensagem = 'Erro ao gerar relatório: $e');
    } on FileSystemException catch (e, stackTrace) {
      await LogService.instance.error('REPORT_FILE', e, stackTrace);
      if (!mounted) return;
      setState(() => mensagem = 'Erro ao gerar relatório: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool permitido = widget.session.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios PDF'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Relatórios administrativos'),
              subtitle: Text(
                permitido
                    ? mensagem
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
                  (String t) => DropdownMenuItem<String>(
                    value: t,
                    child: Text(t),
                  ),
                )
                .toList(),
            onChanged: permitido
                ? (String? value) {
                    if (value == null) return;
                    setState(() => tabela = value);
                  }
                : null,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: permitido && !loading ? _gerarPdf : null,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print),
            label: Text(loading ? 'Gerando...' : 'Gerar PDF'),
          ),
        ],
      ),
    );
  }
}
