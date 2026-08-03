CREATE TABLE IF NOT EXISTS historico_exames_pacientes (
  id TEXT PRIMARY KEY,
  pacienteId TEXT,
  pacienteNome TEXT,
  cpf TEXT,
  preccp TEXT,
  cns TEXT,
  pedidoId TEXT,
  amostraId TEXT,
  exameId TEXT,
  exameNome TEXT,
  resultadoId TEXT,
  valor TEXT,
  unidade TEXT,
  referencia TEXT,
  statusLaudo TEXT,
  critico TEXT,
  coletadoEm TEXT,
  liberadoEm TEXT,
  medicoResponsavel TEXT,
  profissionalResponsavel TEXT,
  equipamento TEXT,
  origem TEXT,
  loteBackup TEXT,
  tipoRegistro TEXT,
  ativoConsultaRecente TEXT DEFAULT '0',
  arquivado TEXT DEFAULT '1',
  criadoEm TEXT,
  atualizadoEm TEXT,
  observacao TEXT
);

CREATE INDEX IF NOT EXISTS idx_hist_exames_paciente_nome
ON historico_exames_pacientes(pacienteNome);

CREATE INDEX IF NOT EXISTS idx_hist_exames_cpf
ON historico_exames_pacientes(cpf);

CREATE INDEX IF NOT EXISTS idx_hist_exames_preccp
ON historico_exames_pacientes(preccp);

CREATE INDEX IF NOT EXISTS idx_hist_exames_pedido
ON historico_exames_pacientes(pedidoId);

CREATE INDEX IF NOT EXISTS idx_hist_exames_liberado
ON historico_exames_pacientes(liberadoEm);

CREATE INDEX IF NOT EXISTS idx_hist_exames_arquivado
ON historico_exames_pacientes(arquivado, ativoConsultaRecente);
