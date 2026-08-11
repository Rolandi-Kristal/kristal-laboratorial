import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/lab_exam_definition.dart';
import '../services/auth_service.dart';
import '../services/lab_exam_catalog_service.dart';
import '../services/log_service.dart';
import '../widgets/kristal_shell.dart';

class CatalogoExamesCompletoScreen extends StatefulWidget {
  const CatalogoExamesCompletoScreen({super.key});

  @override
  State<CatalogoExamesCompletoScreen> createState() =>
      _CatalogoExamesCompletoScreenState();
}

class _CatalogoExamesCompletoScreenState
    extends State<CatalogoExamesCompletoScreen> {
  final TextEditingController _searchController = TextEditingController();
  final LabExamCatalogService _service = LabExamCatalogService.instance;

  List<LabExamDefinition> _items = <LabExamDefinition>[];
  bool _loading = true;
  bool _showHistory = false;
  String _status = 'Carregando catálogo permanente...';

  AuthSession? get _session => AuthService.instance.session;
  bool get _canEdit => _session?.isAdmin == true;
  bool get _isSuper => _session?.isSuperUser == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final List<LabExamDefinition> items = await _service
        .search(_searchController.text, includeDeleted: _showHistory);
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _loading = false;
      _status = 'Catálogo carregado: ${items.length} registros.';
    });
  }

  Future<void> _search(String value) async {
    final List<LabExamDefinition> items =
        await _service.search(value, includeDeleted: _showHistory);
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
    });
  }

  Future<void> _importFile() async {
    final AuthSession? session = _session;
    if (!_canEdit || session == null) {
      _setStatus(
          'Apenas SUPER_USUARIO ou ADMINISTRADOR pode importar catálogo.');
      return;
    }
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Importar catálogo de exames',
      type: FileType.any,
      allowMultiple: false,
      lockParentWindow: true,
    );
    final String? path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) {
      _setStatus('Importação cancelada.');
      return;
    }
    try {
      final LabExamCatalogImportResult imported =
          await _service.importarArquivo(path: path, session: session);
      await _load();
      _setStatus(
        '${imported.message} Registros integrados: ${imported.importedCount}. SHA256: ${imported.sha256}',
      );
    } on FileSystemException catch (error, stackTrace) {
      await _catalogFailure(
          'IMPORT_FILE', error, stackTrace, 'Falha na importação');
    } on FormatException catch (error, stackTrace) {
      await _catalogFailure(
          'IMPORT_FORMAT', error, stackTrace, 'Falha na importação');
    } on ArgumentError catch (error, stackTrace) {
      await _catalogFailure(
          'IMPORT_INPUT', error, stackTrace, 'Falha na importação');
    } on StateError catch (error, stackTrace) {
      await _catalogFailure(
          'IMPORT_STATE', error, stackTrace, 'Falha na importação');
    } on DatabaseException catch (error, stackTrace) {
      await _catalogFailure(
          'IMPORT_DATABASE', error, stackTrace, 'Falha na importação');
    }
  }

  Future<void> _saveDialog({LabExamDefinition? exam}) async {
    final AuthSession? session = _session;
    if (!_canEdit || session == null) {
      _setStatus(
          'Apenas SUPER_USUARIO ou ADMINISTRADOR pode editar o catálogo.');
      return;
    }
    final LabExamDefinition? edited = await showDialog<LabExamDefinition>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _ExamDialog(exam: exam),
    );
    if (edited == null) {
      return;
    }
    try {
      await _service.salvar(exam: edited, session: session);
      await _load();
      _setStatus('Exame salvo no catálogo permanente: ${edited.code}.');
    } on FileSystemException catch (error, stackTrace) {
      await _catalogFailure(
          'SAVE_FILE', error, stackTrace, 'Falha ao salvar exame');
    } on FormatException catch (error, stackTrace) {
      await _catalogFailure(
          'SAVE_FORMAT', error, stackTrace, 'Falha ao salvar exame');
    } on ArgumentError catch (error, stackTrace) {
      await _catalogFailure(
          'SAVE_INPUT', error, stackTrace, 'Falha ao salvar exame');
    } on StateError catch (error, stackTrace) {
      await _catalogFailure(
          'SAVE_STATE', error, stackTrace, 'Falha ao salvar exame');
    } on DatabaseException catch (error, stackTrace) {
      await _catalogFailure(
          'SAVE_DATABASE', error, stackTrace, 'Falha ao salvar exame');
    }
  }

  Future<void> _toggleActive(LabExamDefinition exam) async {
    final AuthSession? session = _session;
    if (!_canEdit || session == null) {
      _setStatus('Apenas SUPER_USUARIO ou ADMINISTRADOR pode alterar status.');
      return;
    }
    try {
      if (exam.active) {
        await _service.inativar(code: exam.code, session: session);
        _setStatus('Exame inativado: ${exam.code}.');
      } else {
        await _service.reativar(code: exam.code, session: session);
        _setStatus('Exame reativado: ${exam.code}.');
      }
      await _load();
    } on FileSystemException catch (error, stackTrace) {
      await _catalogFailure(
          'STATUS_FILE', error, stackTrace, 'Falha ao alterar status');
    } on FormatException catch (error, stackTrace) {
      await _catalogFailure(
          'STATUS_FORMAT', error, stackTrace, 'Falha ao alterar status');
    } on StateError catch (error, stackTrace) {
      await _catalogFailure(
          'STATUS_STATE', error, stackTrace, 'Falha ao alterar status');
    } on DatabaseException catch (error, stackTrace) {
      await _catalogFailure(
          'STATUS_DATABASE', error, stackTrace, 'Falha ao alterar status');
    }
  }

  Future<void> _deleteLogical(LabExamDefinition exam) async {
    final AuthSession? session = _session;
    if (!_isSuper || session == null) {
      _setStatus('Apenas SUPER_USUARIO pode excluir registros do catálogo.');
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Excluir do catálogo'),
        content: Text(
          'Confirmar exclusão lógica de ${exam.code} - ${exam.name}? O histórico permanente será mantido.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _service.excluirLogicamente(code: exam.code, session: session);
      await _load();
      _setStatus(
          'Exame excluído logicamente pelo SUPER_USUARIO: ${exam.code}.');
    } on FileSystemException catch (error, stackTrace) {
      await _catalogFailure(
          'ARCHIVE_FILE', error, stackTrace, 'Falha ao excluir exame');
    } on FormatException catch (error, stackTrace) {
      await _catalogFailure(
          'ARCHIVE_FORMAT', error, stackTrace, 'Falha ao excluir exame');
    } on StateError catch (error, stackTrace) {
      await _catalogFailure(
          'ARCHIVE_STATE', error, stackTrace, 'Falha ao excluir exame');
    } on DatabaseException catch (error, stackTrace) {
      await _catalogFailure(
          'ARCHIVE_DATABASE', error, stackTrace, 'Falha ao excluir exame');
    }
  }

  Future<void> _catalogFailure(
    String operation,
    Object error,
    StackTrace stackTrace,
    String message,
  ) async {
    await LogService.instance.error(
      'CATALOG_$operation',
      error,
      stackTrace,
    );
    _setStatus('$message: $error');
  }

  void _setStatus(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return KristalShell(
      title: 'Catálogo Completo de Exames',
      subtitle: 'Exames laboratoriais por MNE, setor, material e código SIRE',
      icon: Icons.biotech,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool narrow = constraints.maxWidth < 820;
                final Widget search = TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: _search,
                  decoration: const InputDecoration(
                    labelText:
                        'Buscar exame, MNE, setor, material ou código SIRE',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Color(0xFF071827),
                    border: OutlineInputBorder(),
                  ),
                );
                final List<Widget> actions = <Widget>[
                  OutlinedButton.icon(
                    onPressed: _canEdit ? _importFile : null,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Importar'),
                  ),
                  FilledButton.icon(
                    onPressed: _canEdit ? () => _saveDialog() : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Adicionar'),
                  ),
                  if (_canEdit)
                    FilterChip(
                      selected: _showHistory,
                      label: const Text('Histórico'),
                      avatar: const Icon(Icons.history_rounded),
                      onSelected: (bool value) async {
                        setState(() => _showHistory = value);
                        await _load();
                      },
                    ),
                ];
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      search,
                      const SizedBox(height: 10),
                      Wrap(spacing: 10, runSpacing: 10, children: actions),
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    ...actions
                        .expand((Widget item) =>
                            <Widget>[item, const SizedBox(width: 10)])
                        .toList()
                      ..removeLast(),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _canEdit
                    ? _status
                    : 'Catálogo em modo consulta. Edição restrita a SUPER_USUARIO e ADMINISTRADOR.',
                style: const TextStyle(
                  color: Color(0xFFFFC857),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final LabExamDefinition exam = _items[index];
                        return ListTile(
                          tileColor: const Color(0xFF0D2033),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: exam.active
                                  ? const Color(0xFF244B6D)
                                  : const Color(0xFFFFC857),
                            ),
                          ),
                          leading: Icon(
                            exam.active
                                ? Icons.science
                                : Icons.visibility_off_rounded,
                            color: exam.active
                                ? const Color(0xFF73D7FF)
                                : const Color(0xFFFFC857),
                          ),
                          title: Text(
                            '${exam.code} • ${exam.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${exam.sector} • ${exam.material} • SIRE: ${exam.sireCode}'
                            '${exam.active ? '' : ' • INATIVO'}',
                            style: const TextStyle(color: Color(0xFFB7D7F1)),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: <Widget>[
                              if (exam.isCriticalTrackable)
                                const Icon(
                                  Icons.warning,
                                  color: Color(0xFFFFC857),
                                ),
                              IconButton(
                                tooltip: 'Editar',
                                onPressed: _canEdit
                                    ? () => _saveDialog(exam: exam)
                                    : null,
                                icon: const Icon(Icons.edit_rounded),
                              ),
                              IconButton(
                                tooltip: exam.active ? 'Inativar' : 'Reativar',
                                onPressed:
                                    _canEdit ? () => _toggleActive(exam) : null,
                                icon: Icon(
                                  exam.active
                                      ? Icons.block_rounded
                                      : Icons.check_circle_rounded,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Excluir',
                                onPressed: _isSuper
                                    ? () => _deleteLogical(exam)
                                    : null,
                                icon: const Icon(Icons.delete_rounded),
                              ),
                            ],
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

class _ExamDialog extends StatefulWidget {
  const _ExamDialog({this.exam});

  final LabExamDefinition? exam;

  @override
  State<_ExamDialog> createState() => _ExamDialogState();
}

class _ExamDialogState extends State<_ExamDialog> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _sector;
  late final TextEditingController _material;
  late final TextEditingController _sireCode;
  late final TextEditingController _sireSubgroupCode;
  late final TextEditingController _unit;
  late final TextEditingController _reference;
  late final TextEditingController _synonyms;
  bool _active = true;
  bool _critical = false;
  bool _fasting = false;

  @override
  void initState() {
    super.initState();
    final LabExamDefinition? exam = widget.exam;
    _code = TextEditingController(text: exam?.code ?? '');
    _name = TextEditingController(text: exam?.name ?? '');
    _sector = TextEditingController(text: exam?.sector ?? '');
    _material = TextEditingController(text: exam?.material ?? '');
    _sireCode = TextEditingController(text: exam?.sireCode ?? '');
    _sireSubgroupCode =
        TextEditingController(text: exam?.sireSubgroupCode ?? '');
    _unit = TextEditingController(text: exam?.unit ?? '');
    _reference = TextEditingController(text: exam?.reference ?? '');
    _synonyms = TextEditingController(text: exam?.synonyms.join('|') ?? '');
    _active = exam?.active ?? true;
    _critical = exam?.isCriticalTrackable ?? false;
    _fasting = exam?.requiresFasting ?? false;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _sector.dispose();
    _material.dispose();
    _sireCode.dispose();
    _sireSubgroupCode.dispose();
    _unit.dispose();
    _reference.dispose();
    _synonyms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exam == null ? 'Adicionar exame' : 'Editar exame'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _field(_code, 'MNE / Código *'),
              _field(_name, 'Nome do exame *'),
              _field(_sector, 'Setor'),
              _field(_material, 'Material'),
              _field(_sireCode, 'Código SIRE'),
              _field(_sireSubgroupCode, 'Subgrupo CBHPM'),
              _field(_unit, 'Unidade'),
              _field(_reference, 'Referência'),
              _field(_synonyms, 'Sinônimos separados por |'),
              SwitchListTile(
                value: _active,
                onChanged: (bool value) => setState(() => _active = value),
                title: const Text('Ativo'),
              ),
              SwitchListTile(
                value: _critical,
                onChanged: (bool value) => setState(() => _critical = value),
                title: const Text('Rastrear como crítico'),
              ),
              SwitchListTile(
                value: _fasting,
                onChanged: (bool value) => setState(() => _fasting = value),
                title: const Text('Exige jejum'),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  void _submit() {
    final String code = _code.text.trim().toUpperCase();
    final String name = _name.text.trim();
    if (code.isEmpty || name.isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      LabExamDefinition(
        code: code,
        name: name,
        sector: _sector.text.trim(),
        material: _material.text.trim(),
        sireCode: _sireCode.text.trim(),
        sireSubgroupCode: _sireSubgroupCode.text.trim(),
        synonyms: _synonyms.text
            .split('|')
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toList(growable: false),
        unit: _unit.text.trim(),
        reference: _reference.text.trim(),
        active: _active,
        requiresFasting: _fasting,
        isCriticalTrackable: _critical,
      ),
    );
  }
}
