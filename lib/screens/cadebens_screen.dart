import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/auth_service.dart';
import '../services/cadbens_service.dart';
import '../services/log_service.dart';

class CadebensScreen extends StatefulWidget {
  final AuthSession session;

  const CadebensScreen({
    super.key,
    required this.session,
  });

  @override
  State<CadebensScreen> createState() => _CadebensScreenState();
}

class _CadebensScreenState extends State<CadebensScreen> {
  final TextEditingController arquivo = TextEditingController();
  final TextEditingController conteudo = TextEditingController();
  final TextEditingController pesquisa = TextEditingController();

  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  bool loading = false;
  String mensagem =
      'Importe o cadastro CADBENS/FUSEx em CSV com cabecalhos como nome, cpf, numero_beneficio, matricula, situacao.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    arquivo.dispose();
    conteudo.dispose();
    pesquisa.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    rows = await CadbensService.instance.listar();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _importarTexto() async {
    if (conteudo.text.trim().isEmpty) {
      _msg('Cole o conteudo CSV do CADBENS/FUSEx.');
      return;
    }
    await _importar(() {
      return CadbensService.instance.importarTexto(
        conteudo: conteudo.text,
        usuario: widget.session.login,
      );
    });
  }

  Future<void> _importarArquivo() async {
    if (arquivo.text.trim().isEmpty) {
      _msg('Informe o caminho do arquivo CSV.');
      return;
    }
    await _importar(() {
      return CadbensService.instance.importarArquivo(
        path: arquivo.text.trim(),
        usuario: widget.session.login,
      );
    });
  }

  Future<void> _importar(Future<int> Function() action) async {
    setState(() => loading = true);
    try {
      final int total = await action();
      mensagem = '$total cadastro(s) CADBENS/FUSEx importado(s).';
      await _load();
    } on FileSystemException catch (e, stackTrace) {
      await LogService.instance.error('CADBENS_IMPORT_FILE', e, stackTrace);
      mensagem = 'Erro ao importar CADBENS/FUSEx: $e';
    } on FormatException catch (e, stackTrace) {
      await LogService.instance.error('CADBENS_IMPORT_FORMAT', e, stackTrace);
      mensagem = 'Erro ao importar CADBENS/FUSEx: $e';
    } on DatabaseException catch (e, stackTrace) {
      await LogService.instance.error('CADBENS_IMPORT_DATABASE', e, stackTrace);
      mensagem = 'Erro ao importar CADBENS/FUSEx: $e';
    } on ArgumentError catch (e, stackTrace) {
      await LogService.instance.error('CADBENS_IMPORT_INPUT', e, stackTrace);
      mensagem = 'Erro ao importar CADBENS/FUSEx: $e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _consultar() async {
    final String q = pesquisa.text.trim();
    if (q.isEmpty) {
      await _load();
      return;
    }

    final Map<String, dynamic>? found = await CadbensService.instance.consultar(
      cpf: q,
      nome: q,
      numeroBeneficio: q,
    );

    setState(() {
      rows = found == null
          ? <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[found];
      mensagem = found == null
          ? 'Nenhum beneficiario encontrado.'
          : 'Beneficiario encontrado no CADBENS/FUSEx.';
    });
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importacao CADBENS/FUSEx'),
        actions: <Widget>[
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Row(
        children: <Widget>[
          SizedBox(
            width: 420,
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: <Widget>[
                TextField(
                  controller: arquivo,
                  decoration: const InputDecoration(
                    labelText: 'Caminho do arquivo CSV CADBENS/FUSEx',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.folder_open),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: loading ? null : _importarArquivo,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar arquivo'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: conteudo,
                  minLines: 10,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    labelText: 'Ou cole aqui o CSV do CADBENS/FUSEx',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: loading ? null : _importarTexto,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Importar texto colado'),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(mensagem),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: pesquisa,
                          decoration: const InputDecoration(
                            labelText: 'Consultar por CPF, nome ou beneficio',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _consultar(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _consultar,
                        icon: const Icon(Icons.search),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : rows.isEmpty
                          ? const Center(
                              child: Text('Nenhum cadastro importado.'))
                          : ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (BuildContext context, int index) {
                                final Map<String, dynamic> row = rows[index];
                                return Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.badge),
                                    title: Text(
                                      row['pacienteNome']?.toString() ?? '',
                                    ),
                                    subtitle: Text(
                                      'CPF: ${row['cpf'] ?? ''} | Beneficio: ${row['numeroBeneficio'] ?? ''} | Situacao: ${row['situacao'] ?? ''}',
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
