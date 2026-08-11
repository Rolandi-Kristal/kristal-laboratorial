import 'lab_repository.dart';

class EquipmentResultMapping {
  final String mappingId;
  final String equipmentId;
  final String sourceCode;
  final String examId;
  final String systemCode;

  const EquipmentResultMapping({
    required this.mappingId,
    required this.equipmentId,
    required this.sourceCode,
    required this.examId,
    required this.systemCode,
  });
}

class EquipmentResultMappingService {
  EquipmentResultMappingService({LabRepository? repository})
      : _repository = repository ?? LabRepository();

  final LabRepository _repository;

  Future<EquipmentResultMapping> resolve({
    required String equipmentId,
    required String sourceCode,
  }) async {
    final String equipment = equipmentId.trim();
    final String source = sourceCode.trim();
    if (equipment.isEmpty) {
      throw ArgumentError.value(
          equipmentId, 'equipmentId', 'Informe o equipamento.');
    }
    if (source.isEmpty) {
      throw ArgumentError.value(
          sourceCode, 'sourceCode', 'Código de exame vazio.');
    }

    final List<Map<String, dynamic>> mappings = await _repository.all(
      'equipment_test_mappings',
      where:
          'equipmentId = ? AND UPPER(sourceCode) = ? AND ativo = ? AND arquivado = ?',
      whereArgs: <Object?>[equipment, source.toUpperCase(), '1', '0'],
      limit: 2,
    );
    if (mappings.length > 1) {
      throw StateError(
        'Mapeamento duplicado para $equipment/$source. Corrija antes de importar.',
      );
    }
    if (mappings.length == 1) {
      final Map<String, dynamic> row = mappings.single;
      final String examId = (row['examId'] ?? '').toString().trim();
      final String systemCode = (row['systemCode'] ?? '').toString().trim();
      if (examId.isEmpty || systemCode.isEmpty) {
        throw StateError('Mapeamento ${row['id']} incompleto para $source.');
      }
      return EquipmentResultMapping(
        mappingId: (row['id'] ?? '').toString(),
        equipmentId: equipment,
        sourceCode: source,
        examId: examId,
        systemCode: systemCode,
      );
    }

    final List<Map<String, dynamic>> exams = await _repository.all(
      'exames',
      where: 'UPPER(codigo) = ? AND ativo = ?',
      whereArgs: <Object?>[source.toUpperCase(), '1'],
      limit: 2,
    );
    if (exams.length != 1) {
      throw StateError(
        'Não existe mapeamento único para o código $source do equipamento $equipment.',
      );
    }
    final Map<String, dynamic> exam = exams.single;
    return EquipmentResultMapping(
      mappingId: 'CATALOGO-DIRETO',
      equipmentId: equipment,
      sourceCode: source,
      examId: (exam['id'] ?? '').toString(),
      systemCode: (exam['codigo'] ?? '').toString(),
    );
  }

  Future<void> save({
    required String id,
    required String equipmentId,
    required String sourceCode,
    required String examId,
    required String systemCode,
    required String usuario,
  }) async {
    final List<String> requiredValues = <String>[
      id.trim(),
      equipmentId.trim(),
      sourceCode.trim(),
      examId.trim(),
      systemCode.trim(),
    ];
    if (requiredValues.any((String value) => value.isEmpty)) {
      throw ArgumentError('Todos os campos do mapeamento são obrigatórios.');
    }
    final String now = DateTime.now().toIso8601String();
    await _repository.upsert(
      'equipment_test_mappings',
      <String, dynamic>{
        'id': id.trim(),
        'equipmentId': equipmentId.trim(),
        'sourceCode': sourceCode.trim(),
        'examId': examId.trim(),
        'systemCode': systemCode.trim(),
        'ativo': '1',
        'criadoEm': now,
        'atualizadoEm': now,
        'ativoConsultaRecente': '1',
        'arquivado': '0',
      },
      usuario: usuario,
    );
  }
}
