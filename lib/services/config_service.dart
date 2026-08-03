import 'lab_repository.dart';

class ConfigService {
  ConfigService._();

  static final ConfigService instance = ConfigService._();

  final LabRepository _repo = LabRepository();

  Future<String> getValue(String chave, {String defaultValue = ''}) async {
    final List<Map<String, dynamic>> rows = await _repo.all(
      'configuracoes',
      where: 'chave = ?',
      whereArgs: <Object?>[chave],
      limit: 1,
    );

    if (rows.isEmpty) return defaultValue;

    return rows.first['valor']?.toString() ?? defaultValue;
  }

  Future<void> setValue(String chave, String valor) async {
    await _repo.upsert('configuracoes', <String, dynamic>{
      'id': chave,
      'chave': chave,
      'valor': valor,
      'atualizadoEm': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, String>> allConfig() async {
    final List<Map<String, dynamic>> rows = await _repo.all(
      'configuracoes',
      orderBy: 'chave ASC',
    );

    return <String, String>{
      for (final Map<String, dynamic> row in rows)
        row['chave']?.toString() ?? '': row['valor']?.toString() ?? '',
    };
  }
}
