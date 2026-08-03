import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseSchemaService {
  DatabaseSchemaService._();

  static const List<String> historicoExamesPacientesSql = <String>[
    "CREATE TABLE IF NOT EXISTS historico_exames_pacientes (\n  id TEXT PRIMARY KEY,\n  pacienteId TEXT,\n  pacienteNome TEXT,\n  cpf TEXT,\n  preccp TEXT,\n  cns TEXT,\n  pedidoId TEXT,\n  amostraId TEXT,\n  exameId TEXT,\n  exameNome TEXT,\n  resultadoId TEXT,\n  valor TEXT,\n  unidade TEXT,\n  referencia TEXT,\n  statusLaudo TEXT,\n  critico TEXT,\n  coletadoEm TEXT,\n  liberadoEm TEXT,\n  medicoResponsavel TEXT,\n  profissionalResponsavel TEXT,\n  equipamento TEXT,\n  origem TEXT,\n  loteBackup TEXT,\n  tipoRegistro TEXT,\n  ativoConsultaRecente TEXT DEFAULT '0',\n  arquivado TEXT DEFAULT '1',\n  criadoEm TEXT,\n  atualizadoEm TEXT,\n  observacao TEXT\n);",
    'CREATE INDEX IF NOT EXISTS idx_hist_exames_paciente_nome\nON historico_exames_pacientes(pacienteNome);',
    'CREATE INDEX IF NOT EXISTS idx_hist_exames_cpf\nON historico_exames_pacientes(cpf);',
    'CREATE INDEX IF NOT EXISTS idx_hist_exames_preccp\nON historico_exames_pacientes(preccp);',
    'CREATE INDEX IF NOT EXISTS idx_hist_exames_pedido\nON historico_exames_pacientes(pedidoId);',
    'CREATE INDEX IF NOT EXISTS idx_hist_exames_liberado\nON historico_exames_pacientes(liberadoEm);',
    'CREATE INDEX IF NOT EXISTS idx_hist_exames_arquivado\nON historico_exames_pacientes(arquivado, ativoConsultaRecente);'
  ];

  static Future<void> applyHistoricoExamesPacientes(Database db) async {
    for (final String statement in historicoExamesPacientesSql) {
      await db.execute(statement);
    }
  }
}
