import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:path/path.dart' as p;

import '../core/app_constants.dart';
import '../widgets/kristal_shell.dart';

class LabOperationalModuleScreen extends StatefulWidget {
  const LabOperationalModuleScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.storageName,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String storageName;

  @override
  State<LabOperationalModuleScreen> createState() =>
      _LabOperationalModuleScreenState();
}

class _LabOperationalModuleScreenState
    extends State<LabOperationalModuleScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _recordController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  final FocusNode _recordFocusNode = FocusNode();

  List<Map<String, Object?>> _records = <Map<String, Object?>>[];
  String _statusMessage = 'Pronto para operação.';
  bool _isLoading = false;

  File get _storageFile {
    final String safeName = widget.storageName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_');

    return File(
      p.join(
        AppConstants.dataDirectoryPath,
        'modulos_operacionais',
        '$safeName.json',
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _recordController.dispose();
    _detailsController.dispose();
    _recordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final File file = _storageFile;
      await file.parent.create(recursive: true);

      if (!await file.exists()) {
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(<Map<String, Object?>>[]),
          encoding: utf8,
        );
      }

      final String rawContent = await file.readAsString(encoding: utf8);
      final Object? decoded = jsonDecode(rawContent);

      if (decoded is List) {
        setState(() {
          _records = decoded
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (Map<dynamic, dynamic> item) => item.map(
                  (dynamic key, dynamic value) =>
                      MapEntry<String, Object?>(key.toString(), value),
                ),
              )
              .toList(growable: true);
          _statusMessage = 'Dados carregados de ${file.path}';
        });
      }
    } on FileSystemException catch (error) {
      setState(() {
        _statusMessage = 'Erro de arquivo: ${error.message}';
      });
    } on FormatException catch (error) {
      setState(() {
        _statusMessage = 'Arquivo de dados inválido: ${error.message}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _persistRecords() async {
    final File file = _storageFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_records),
      encoding: utf8,
    );
  }

  Future<void> _saveRecord() async {
    final String record = _recordController.text.trim();
    final String details = _detailsController.text.trim();

    if (record.isEmpty) {
      setState(() {
        _statusMessage = 'Informe a identificação do registro.';
      });
      _recordFocusNode.requestFocus();
      return;
    }

    final DateTime now = DateTime.now();

    final Map<String, Object?> newRecord = <String, Object?>{
      'id': now.microsecondsSinceEpoch.toString(),
      'titulo': record,
      'detalhe': details,
      'modulo': widget.storageName,
      'criadoEm': now.toIso8601String(),
      'atualizadoEm': now.toIso8601String(),
      'ativoConsultaRecente': '1',
      'arquivado': '0',
      'excluidoFisicamente': '0',
      'bloqueioExclusao': '1',
    };

    setState(() {
      _records.insert(0, newRecord);
      _recordController.clear();
      _detailsController.clear();
      _statusMessage = 'Registro salvo com retenção permanente.';
    });

    await _persistRecords();
  }

  Future<void> _archiveRecord(String id) async {
    final DateTime now = DateTime.now();

    setState(() {
      _records = _records.map((Map<String, Object?> item) {
        if (item['id']?.toString() == id) {
          return <String, Object?>{
            ...item,
            'ativoConsultaRecente': '0',
            'arquivado': '1',
            'arquivadoEm': now.toIso8601String(),
            'motivoArquivamento':
                'Registro preservado permanentemente para consulta histórica.',
          };
        }

        return item;
      }).toList(growable: true);

      _statusMessage =
          'Registro arquivado sem exclusão física e preservado no histórico.';
    });

    await _persistRecords();
  }

  Future<void> _exportJson() async {
    try {
      final Directory exportDirectory = Directory(
        p.join(AppConstants.exportsDirectoryPath, 'modulos_operacionais'),
      );
      await exportDirectory.create(recursive: true);

      final String fileName =
          '${widget.storageName}_${DateTime.now().millisecondsSinceEpoch}.json';

      final File targetFile = File(p.join(exportDirectory.path, fileName));
      await targetFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_records),
        encoding: utf8,
      );

      setState(() {
        _statusMessage = 'Exportado para ${targetFile.path}';
      });
    } on FileSystemException catch (error) {
      setState(() {
        _statusMessage = 'Erro ao exportar: ${error.message}';
      });
    }
  }

  List<Map<String, Object?>> get _filteredRecords {
    final String query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _records;
    }

    return _records.where((Map<String, Object?> item) {
      return item.values.any(
        (Object? value) => value.toString().toLowerCase().contains(query),
      );
    }).toList(growable: false);
  }

  int get _recentCount {
    return _records.where((Map<String, Object?> item) {
      return item['ativoConsultaRecente']?.toString() == '1' &&
          item['arquivado']?.toString() == '0';
    }).length;
  }

  int get _historicalCount {
    return _records.where((Map<String, Object?> item) {
      return item['arquivado']?.toString() == '1';
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return KristalShell(
      title: widget.title,
      subtitle: widget.subtitle,
      icon: widget.icon,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 360,
              child: _buildOperationPanel(),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _buildRecordsPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationPanel() {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(widget.icon, color: const Color(0xFF73D7FF), size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildInfoCard(
            label: 'Consulta recente',
            value: _recentCount.toString(),
            icon: Icons.history_toggle_off_rounded,
            color: const Color(0xFF4EA3FF),
          ),
          const SizedBox(height: 10),
          _buildInfoCard(
            label: 'Histórico permanente',
            value: _historicalCount.toString(),
            icon: Icons.archive_rounded,
            color: const Color(0xFFFFC857),
          ),
          const SizedBox(height: 18),
          _field(
            controller: _recordController,
            label: 'Identificação do registro',
            icon: Icons.badge_rounded,
            focusNode: _recordFocusNode,
          ),
          const SizedBox(height: 10),
          _field(
            controller: _detailsController,
            label: 'Detalhamento técnico',
            icon: Icons.notes_rounded,
            maxLines: 5,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveRecord,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Salvar registro'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _loadRecords,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Atualizar dados'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _exportJson,
            icon: const Icon(Icons.file_download_rounded),
            label: const Text('Exportar JSON'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
          const Spacer(),
          Text(
            _statusMessage,
            style: const TextStyle(
              color: Color(0xFFFFC857),
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsPanel() {
    final List<Map<String, Object?>> records = _filteredRecords;

    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Pesquisar registros',
              prefixIcon: Icon(Icons.search_rounded),
              filled: true,
              fillColor: Color(0xFF071827),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : records.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum registro encontrado.',
                          style: TextStyle(
                            color: Color(0xFFB7D7F1),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          return _buildRecordTile(records[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordTile(Map<String, Object?> record) {
    final String id = record['id']?.toString() ?? '';
    final bool archived = record['arquivado']?.toString() == '1';

    return ListTile(
      tileColor: archived ? const Color(0xFF182536) : const Color(0xFF071827),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: archived ? const Color(0xFFFFC857) : const Color(0xFF244B6D),
        ),
      ),
      leading: Icon(
        archived ? Icons.archive_rounded : Icons.description_rounded,
        color: archived ? const Color(0xFFFFC857) : const Color(0xFF73D7FF),
      ),
      title: Text(
        record['titulo']?.toString() ?? '',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        record['detalhe']?.toString() ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFFB7D7F1)),
      ),
      trailing: archived
          ? const Text(
              'Histórico',
              style: TextStyle(
                color: Color(0xFFFFC857),
                fontWeight: FontWeight.w900,
              ),
            )
          : IconButton(
              tooltip: 'Arquivar sem excluir',
              onPressed: () => _archiveRecord(id),
              icon: const Icon(Icons.archive_outlined),
              color: const Color(0xFFFFC857),
            ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF071827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.75)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFB7D7F1),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF071827),
        border: const OutlineInputBorder(),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: const Color(0xFF0D2033),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF244B6D)),
    );
  }
}
