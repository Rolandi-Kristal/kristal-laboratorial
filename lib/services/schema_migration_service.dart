import 'database_service.dart';
import 'log_service.dart';

class SchemaMigrationService {
  SchemaMigrationService._();

  static final SchemaMigrationService instance = SchemaMigrationService._();

  Future<void> ensureSchema() async {
    final db = await DatabaseService.instance.database;

    final List<String> sql = <String>[
      '''
      CREATE TABLE IF NOT EXISTS drivers_equipamentos (
        id TEXT PRIMARY KEY,
        equipamentoId TEXT,
        nome TEXT,
        modelo TEXT,
        protocolo TEXT,
        rootPath TEXT,
        pastaRelativa TEXT,
        executavelConfiguracao TEXT,
        arquivoDriver TEXT,
        arquivoConfig TEXT,
        observacao TEXT,
        status TEXT,
        criadoEm TEXT
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS drivers_diagnosticos (
        id TEXT PRIMARY KEY,
        driverId TEXT,
        equipamentoId TEXT,
        pastaExiste TEXT,
        driverExiste TEXT,
        configuradorExiste TEXT,
        pastaCompleta TEXT,
        dataHora TEXT,
        observacao TEXT
      )
      ''',
    ];

    for (final String statement in sql) {
      await db.execute(statement);
    }

    await LogService.instance.info(
      'SCHEMA_DRIVERS',
      'Tabelas de drivers laboratoriais verificadas.',
    );
  }
}
