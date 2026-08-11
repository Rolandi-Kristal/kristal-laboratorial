import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../models/kristal_operational_record.dart';
import '../services/kristal_operational_store_service.dart';

class KristalModuleField {
  const KristalModuleField({
    required this.key,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.required = true,
  });

  final String key;
  final String label;
  final IconData icon;
  final int maxLines;
  final bool required;
}

class KristalRealModuleScreen extends StatefulWidget {
  const KristalRealModuleScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.module,
    required this.fields,
    required this.primaryColumns,
    this.actionLabel = 'Salvar registro',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String module;
  final List<KristalModuleField> fields;
  final List<String> primaryColumns;
  final String actionLabel;

  @override
  State<KristalRealModuleScreen> createState() =>
      _KristalRealModuleScreenState();
}

class _KristalRealModuleScreenState extends State<KristalRealModuleScreen> {
  final KristalOperationalStoreService _store =
      KristalOperationalStoreService.instance;

  final TextEditingController _searchController = TextEditingController();
  late final Map<String, TextEditingController> _controllers;

  List<KristalOperationalRecord> _records = <KristalOperationalRecord>[];
  bool _loading = true;
  String _status = 'Carregando dados...';

  @override
  void initState() {
    super.initState();
    _controllers = <String, TextEditingController>{
      for (final KristalModuleField field in widget.fields)
        field.key: TextEditingController(),
    };
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    try {
      final List<KristalOperationalRecord> records =
          await _store.load(widget.module);

      if (!mounted) {
        return;
      }

      setState(() {
        _records = records;
        _status = 'Dados carregados com sucesso.';
      });
    } on FileSystemException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Erro de arquivo: ${error.message}';
      });
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Dados inválidos: ${error.message}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final Map<String, String> data = <String, String>{};

    for (final KristalModuleField field in widget.fields) {
      final String value = _controllers[field.key]?.text.trim() ?? '';
      if (field.required && value.isEmpty) {
        setState(() {
          _status = 'Preencha o campo obrigatório: ${field.label}.';
        });
        return;
      }
      data[field.key] = value;
    }

    await _store.create(module: widget.module, data: data);

    for (final TextEditingController controller in _controllers.values) {
      controller.clear();
    }

    await _load();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Registro salvo com retenção permanente.';
    });
  }

  Future<void> _archive(String id) async {
    await _store.archive(
      module: widget.module,
      id: id,
      reason: 'Registro preservado permanentemente para consulta histórica.',
    );

    await _load();

    if (!mounted) {
      return;
    }

    setState(() {
      _status =
          'Registro movido para histórico permanente sem exclusão física.';
    });
  }

  Future<void> _export() async {
    try {
      final File file = await _store.exportJson(widget.module);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Arquivo exportado: ${file.path}';
      });
    } on FileSystemException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Erro ao exportar: ${error.message}';
      });
    }
  }

  List<KristalOperationalRecord> get _filteredRecords {
    final String query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _records;
    }

    return _records.where((KristalOperationalRecord record) {
      return record.data.values.any(
        (String value) => value.toLowerCase().contains(query),
      );
    }).toList(growable: false);
  }

  int get _recentCount {
    return _records
        .where(
          (KristalOperationalRecord record) =>
              record.activeRecent && !record.archived,
        )
        .length;
  }

  int get _historyCount {
    return _records
        .where((KristalOperationalRecord record) => record.archived)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF06111D),
      child: Column(
        children: <Widget>[
          _ModuleHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            icon: widget.icon,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: 390,
                    child: _buildFormPanel(),
                  ),
                  const SizedBox(width: 18),
                  Expanded(child: _buildTablePanel()),
                ],
              ),
            ),
          ),
          _StatusFooter(status: _status),
        ],
      ),
    );
  }

  Widget _buildFormPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(widget.icon, color: const Color(0xFF73D7FF), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _CountCard(
                  title: 'Consulta recente',
                  value: _recentCount.toString(),
                  color: const Color(0xFF4EA3FF),
                  icon: Icons.history_toggle_off_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CountCard(
                  title: 'Histórico',
                  value: _historyCount.toString(),
                  color: const Color(0xFFFFC857),
                  icon: Icons.archive_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  for (final KristalModuleField field
                      in widget.fields) ...<Widget>[
                    TextField(
                      controller: _controllers[field.key],
                      maxLines: field.maxLines,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText:
                            field.required ? '${field.label} *' : field.label,
                        prefixIcon: Icon(field.icon),
                        filled: true,
                        fillColor: const Color(0xFF071827),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(widget.actionLabel),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Atualizar'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _export,
            icon: const Icon(Icons.file_download_rounded),
            label: const Text('Exportar dados'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablePanel() {
    final List<KristalOperationalRecord> records = _filteredRecords;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : records.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum registro encontrado.',
                          style: TextStyle(
                            color: Color(0xFFB7D7F1),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          return _RecordCard(
                            record: records[index],
                            columns: widget.primaryColumns,
                            onArchive: _archive,
                          );
                        },
                      ),
          ),
        ],
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

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF18344F),
        border: Border(bottom: BorderSide(color: Color(0xFF26577D))),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF0E88C6).withOpacity(0.24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3EC6FF)),
            ),
            child: Icon(icon, color: const Color(0xFF73D7FF), size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFB7D7F1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Image.asset(
            AppConstants.hmrLogoPath,
            width: 52,
            height: 52,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.local_hospital_rounded,
              color: Color(0xFF73D7FF),
              size: 42,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF071827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.85)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              style: const TextStyle(
                color: Color(0xFFB7D7F1),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.columns,
    required this.onArchive,
  });

  final KristalOperationalRecord record;
  final List<String> columns;
  final ValueChanged<String> onArchive;

  @override
  Widget build(BuildContext context) {
    final bool archived = record.archived;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: archived ? const Color(0xFF182536) : const Color(0xFF071827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: archived ? const Color(0xFFFFC857) : const Color(0xFF244B6D),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            archived ? Icons.archive_rounded : Icons.description_rounded,
            color: archived ? const Color(0xFFFFC857) : const Color(0xFF73D7FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              children: <Widget>[
                for (final String column in columns)
                  _DataChip(
                    label: column,
                    value: record.data[column] ?? '',
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          archived
              ? const Text(
                  'Histórico',
                  style: TextStyle(
                    color: Color(0xFFFFC857),
                    fontWeight: FontWeight.w900,
                  ),
                )
              : IconButton(
                  tooltip: 'Arquivar sem excluir',
                  onPressed: () => onArchive(record.id),
                  icon: const Icon(Icons.archive_outlined),
                  color: const Color(0xFFFFC857),
                ),
        ],
      ),
    );
  }
}

class _DataChip extends StatelessWidget {
  const _DataChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFF73D7FF),
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFooter extends StatelessWidget {
  const _StatusFooter({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: const Color(0xFF06111D),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFFFC857),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
