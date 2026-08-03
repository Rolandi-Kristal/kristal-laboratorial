import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/lab_repository.dart';
import '../services/patient_document_import_service.dart';

class PacientesScreen extends StatefulWidget {
  const PacientesScreen({super.key});

  @override
  State<PacientesScreen> createState() => _PacientesScreenState();
}

class _PacientesScreenState extends State<PacientesScreen> {
  final LabRepository _repo = LabRepository();
  final TextEditingController _search = TextEditingController();

  bool _loading = true;
  String _status = 'Carregando pacientes...';
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final List<Map<String, dynamic>> rows = await _repo.all(
      'pacientes',
      orderBy: 'nome ASC',
      limit: 1000,
    );
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
      _status = '${rows.length} paciente(s) cadastrado(s).';
    });
  }

  Future<void> _importar() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Importar dados de pacientes',
      type: FileType.any,
      allowMultiple: false,
      lockParentWindow: true,
    );
    final String? path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) {
      setState(() => _status = 'Importação cancelada.');
      return;
    }
    try {
      final PatientDocumentImportResult imported =
          await PatientDocumentImportService.instance.importFile(path);
      await _load();
      if (!mounted) return;
      setState(() {
        _status =
            '${imported.message} Arquivo: ${imported.archivedPath}. HASH: ${imported.sha256Hash}';
      });
    } on FileSystemException catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Erro de arquivo: ${error.message}');
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Arquivo inválido: ${error.message}');
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final String query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _rows;
    return _rows.where((Map<String, dynamic> row) {
      return <String>['nome', 'cpf', 'preccp', 'telefone'].any((String key) =>
          (row[key]?.toString().toLowerCase() ?? '').contains(query));
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> rows = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pacientes'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Importar pacientes',
            onPressed: _importar,
            icon: const Icon(Icons.upload_file_rounded),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Buscar paciente por nome, CPF, PREC-CP ou telefone',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: _importar,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Importar dados dos pacientes'),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_status, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                      ? const Center(child: Text('Nenhum paciente encontrado.'))
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (BuildContext context, int index) {
                            final Map<String, dynamic> row = rows[index];
                            return ListTile(
                              leading: const Icon(Icons.person_rounded),
                              title: Text(row['nome']?.toString() ?? ''),
                              subtitle: Text(
                                'CPF: ${row['cpf'] ?? ''} | PREC-CP: ${row['preccp'] ?? ''} | Tel: ${row['telefone'] ?? ''}',
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
