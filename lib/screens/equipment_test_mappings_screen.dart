import 'package:flutter/material.dart';

import '../models/equipment_connection_config.dart';
import '../services/auth_service.dart';
import '../services/equipment_result_mapping_service.dart';
import '../services/lab_repository.dart';

class EquipmentTestMappingsScreen extends StatefulWidget {
  final AuthSession session;
  final EquipmentConnectionConfig equipment;

  const EquipmentTestMappingsScreen({
    super.key,
    required this.session,
    required this.equipment,
  });

  @override
  State<EquipmentTestMappingsScreen> createState() =>
      _EquipmentTestMappingsScreenState();
}

class _EquipmentTestMappingsScreenState
    extends State<EquipmentTestMappingsScreen> {
  final LabRepository repository = LabRepository();
  final TextEditingController sourceCode = TextEditingController();
  List<Map<String, dynamic>> mappings = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> exams = <Map<String, dynamic>>[];
  String? examId;
  bool loading = true;
  String status = '';

  bool get canEdit => widget.session.isAdmin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    sourceCode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final List<Map<String, dynamic>> loadedMappings = await repository.all(
      'equipment_test_mappings',
      where: 'equipmentId = ? AND arquivado = ?',
      whereArgs: <Object?>[widget.equipment.id, '0'],
      orderBy: 'sourceCode ASC',
    );
    final List<Map<String, dynamic>> loadedExams = await repository.all(
      'exames',
      where: 'ativo = ?',
      whereArgs: const <Object?>['1'],
      orderBy: 'codigo ASC',
    );
    if (!mounted) return;
    setState(() {
      mappings = loadedMappings;
      exams = loadedExams;
      examId = loadedExams.isEmpty ? null : loadedExams.first['id']?.toString();
      loading = false;
      status = '${loadedMappings.length} mapeamento(s) ativo(s).';
    });
  }

  Future<void> _save() async {
    if (!canEdit) return;
    final String code = sourceCode.text.trim();
    final Map<String, dynamic>? exam =
        exams.where((item) => item['id']?.toString() == examId).firstOrNull;
    if (code.isEmpty || exam == null) {
      setState(
          () => status = 'Informe o código do equipamento e o exame KRISTAL.');
      return;
    }
    final String mappingId = 'MAP-${widget.equipment.id}-${code.toUpperCase()}';
    await EquipmentResultMappingService().save(
      id: mappingId,
      equipmentId: widget.equipment.id,
      sourceCode: code,
      examId: exam['id'].toString(),
      systemCode: (exam['codigo'] ?? '').toString(),
      usuario: widget.session.login,
    );
    sourceCode.clear();
    await _load();
  }

  Future<void> _archive(Map<String, dynamic> mapping) async {
    if (!canEdit) return;
    await repository.archiveWithoutDelete(
      'equipment_test_mappings',
      (mapping['id'] ?? '').toString(),
      usuario: widget.session.login,
      motivo: 'Mapeamento de equipamento inativado pelo usuário.',
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapeamento • ${widget.equipment.nome}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (canEdit)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: sourceCode,
                      decoration: const InputDecoration(
                        labelText: 'Código enviado pelo equipamento',
                        prefixIcon: Icon(Icons.input),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 420,
                    child: DropdownButtonFormField<String>(
                      value: examId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Exame no catálogo KRISTAL',
                        prefixIcon: Icon(Icons.biotech),
                        border: OutlineInputBorder(),
                      ),
                      items: exams
                          .map(
                            (Map<String, dynamic> exam) =>
                                DropdownMenuItem<String>(
                              value: exam['id']?.toString(),
                              child: Text(
                                '${exam['codigo'] ?? ''} • ${exam['nome'] ?? ''}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) =>
                          setState(() => examId = value),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Salvar mapeamento',
                    onPressed: exams.isEmpty ? null : _save,
                    icon: const Icon(Icons.save),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(status),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : mappings.isEmpty
                    ? const Center(child: Text('Nenhum mapeamento cadastrado.'))
                    : ListView.builder(
                        itemCount: mappings.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Map<String, dynamic> item = mappings[index];
                          return ListTile(
                            leading: const Icon(Icons.swap_horiz),
                            title: Text(
                              '${item['sourceCode'] ?? ''} → ${item['systemCode'] ?? ''}',
                            ),
                            subtitle: Text('Exame: ${item['examId'] ?? ''}'),
                            trailing: canEdit
                                ? IconButton(
                                    tooltip: 'Inativar mapeamento',
                                    onPressed: () => _archive(item),
                                    icon: const Icon(Icons.archive_outlined),
                                  )
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
