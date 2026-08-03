import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/app_constants.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;
  String? _path;

  Future<Database> get database async {
    if (_database != null) return _database!;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    _path = p.join(dir.path, AppConstants.databaseName);

    _database = await databaseFactory.openDatabase(
      _path!,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      ),
    );

    return _database!;
  }

  Future<Database> get db => database;

  Future<String> databasePath() async {
    await database;
    return _path!;
  }

  Future<void> _onOpen(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');

    await _createV2Tables(db);
    await _createSchedulingAndCadebensTables(db);
    await _createAtendimentoTables(db);
    await _createRetentionAndHistoryTables(db);
    await _createEquipmentConnectionTables(db);
    await _ensureOperationalColumns(db);
    await _ensurePermanentRetentionColumns(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
    }

    await _createSchedulingAndCadebensTables(db);
    await _createAtendimentoTables(db);
    await _ensureOperationalColumns(db);

    if (oldVersion < 3) {
      await _createRetentionAndHistoryTables(db);
      await _createEquipmentConnectionTables(db);
      await _ensurePermanentRetentionColumns(db);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pacientes (
        id TEXT PRIMARY KEY,
        nome TEXT,
        cpf TEXT,
        cns TEXT,
        preccp TEXT,
        nascimento TEXT,
        telefone TEXT,
        endereco TEXT,
        criadoEm TEXT,
        status TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS exames (
        id TEXT PRIMARY KEY,
        codigo TEXT,
        nome TEXT,
        setor TEXT,
        material TEXT,
        metodo TEXT,
        referencia TEXT,
        ativo TEXT,
        criadoEm TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pedidos (
        id TEXT PRIMARY KEY,
        pacienteId TEXT,
        medicoSolicitante TEXT,
        prioridade TEXT,
        status TEXT,
        criadoEm TEXT,
        observacao TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS amostras (
        id TEXT PRIMARY KEY,
        pacienteId TEXT,
        pedidoId TEXT,
        exameId TEXT,
        codigoBarras TEXT UNIQUE,
        codigoManual TEXT,
        tipoLeitura TEXT,
        imagemPath TEXT,
        status TEXT,
        coletadoEm TEXT,
        criadoEm TEXT,
        criadoPor TEXT,
        observacao TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS resultados (
        id TEXT PRIMARY KEY,
        pacienteId TEXT,
        pedidoId TEXT,
        amostraId TEXT,
        exameId TEXT,
        valor TEXT,
        unidade TEXT,
        referencia TEXT,
        critico TEXT,
        status TEXT,
        liberadoEm TEXT,
        criadoEm TEXT,
        observacao TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS laudos (
        id TEXT PRIMARY KEY,
        pacienteId TEXT,
        pedidoId TEXT,
        hash TEXT,
        status TEXT,
        arquivoPath TEXT,
        criadoEm TEXT,
        liberadoEm TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS equipamentos (
        id TEXT PRIMARY KEY,
        nome TEXT,
        fabricante TEXT,
        modelo TEXT,
        protocolo TEXT,
        conexao TEXT,
        porta TEXT,
        ip TEXT,
        baudRate TEXT,
        ativo TEXT,
        criadoEm TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id TEXT PRIMARY KEY,
        nome TEXT,
        login TEXT UNIQUE,
        senhaHash TEXT,
        perfil TEXT,
        ativo TEXT,
        criadoEm TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS configuracoes (
        id TEXT PRIMARY KEY,
        chave TEXT UNIQUE,
        valor TEXT,
        atualizadoEm TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS auditoria (
        id TEXT PRIMARY KEY,
        usuario TEXT,
        acao TEXT,
        tabela TEXT,
        registroId TEXT,
        dataHora TEXT,
        detalhes TEXT
      )
    ''');

    await _createV2Tables(db);
    await _createSchedulingAndCadebensTables(db);
    await _createAtendimentoTables(db);
    await _createRetentionAndHistoryTables(db);
    await _createEquipmentConnectionTables(db);
    await _ensureOperationalColumns(db);
    await _ensurePermanentRetentionColumns(db);

    await db.insert(
      'configuracoes',
      <String, Object?>{
        'id': 'portal_paciente_url',
        'chave': 'portal_paciente_url',
        'valor': '',
        'atualizadoEm': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS materiais (
        id TEXT PRIMARY KEY,
        codigo TEXT,
        nome TEXT,
        tipo TEXT,
        unidade TEXT,
        estoqueMinimo TEXT,
        ativo TEXT,
        criadoEm TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS estoque (
        id TEXT PRIMARY KEY,
        materialId TEXT,
        lote TEXT,
        validade TEXT,
        quantidade TEXT,
        localizacao TEXT,
        status TEXT,
        criadoEm TEXT,
        observacao TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS calibracoes (
        id TEXT PRIMARY KEY,
        equipamentoId TEXT,
        tipo TEXT,
        realizadaEm TEXT,
        proximaEm TEXT,
        responsavel TEXT,
        resultado TEXT,
        status TEXT,
        observacao TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS manutencoes (
        id TEXT PRIMARY KEY,
        equipamentoId TEXT,
        tipo TEXT,
        realizadaEm TEXT,
        proximaEm TEXT,
        responsavel TEXT,
        status TEXT,
        observacao TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS controle_qualidade (
        id TEXT PRIMARY KEY,
        exameId TEXT,
        loteControle TEXT,
        nivel TEXT,
        valorEsperado TEXT,
        valorObtido TEXT,
        unidade TEXT,
        status TEXT,
        executadoEm TEXT,
        responsavel TEXT,
        observacao TEXT
      )
    ''');
  }

  Future<void> _createSchedulingAndCadebensTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS agendamentos (
        id TEXT PRIMARY KEY,
        tipo TEXT,
        pacienteId TEXT,
        pacienteNome TEXT,
        cpf TEXT,
        telefone TEXT,
        exameId TEXT,
        exameNome TEXT,
        dataHora TEXT,
        origem TEXT,
        status TEXT,
        prioridade TEXT,
        cadebensNumero TEXT,
        cadebensSituacao TEXT,
        peso TEXT,
        altura TEXT,
        observacao TEXT,
        criadoEm TEXT,
        atualizadoEm TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_agendamentos_data
      ON agendamentos(dataHora, status)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_agendamentos_paciente
      ON agendamentos(pacienteNome, cpf)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cadebens_integracao (
        id TEXT PRIMARY KEY,
        pacienteId TEXT,
        pacienteNome TEXT,
        cpf TEXT,
        numeroBeneficio TEXT,
        matricula TEXT,
        categoria TEXT,
        situacao TEXT,
        dataConsulta TEXT,
        origem TEXT,
        retorno TEXT,
        status TEXT,
        criadoEm TEXT,
        atualizadoEm TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cadebens_cpf
      ON cadebens_integracao(cpf, numeroBeneficio)
    ''');
  }

  Future<void> _createAtendimentoTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS atendimentos (
        id TEXT PRIMARY KEY,
        pacienteId TEXT,
        pacienteNome TEXT,
        cpf TEXT,
        telefone TEXT,
        celular TEXT,
        email TEXT,
        exames TEXT,
        medicos TEXT,
        convenio TEXT,
        plano TEXT,
        matriculaConvenio TEXT,
        guia TEXT,
        localColeta TEXT,
        localEntrega TEXT,
        formaEntrega TEXT,
        procedenciaPaciente TEXT,
        autorizaSms TEXT,
        enviaCorreio TEXT,
        internet TEXT,
        codigoInternet TEXT,
        cor TEXT,
        religiao TEXT,
        altura TEXT,
        peso TEXT,
        imc TEXT,
        estadoCivil TEXT,
        tratamento TEXT,
        idadeGestacional TEXT,
        localInternacao TEXT,
        quarto TEXT,
        cid TEXT,
        cnes TEXT,
        nomeMae TEXT,
        nomePai TEXT,
        dataTransfusao TEXT,
        dnv TEXT,
        motivoExame TEXT,
        matriculaEmpregado TEXT,
        atividadeProfissional TEXT,
        cep TEXT,
        endereco TEXT,
        bairro TEXT,
        cidade TEXT,
        uf TEXT,
        grupoAgenda TEXT,
        horario TEXT,
        statusPaciente TEXT,
        statusAtendimento TEXT,
        valorCheio TEXT,
        valorIndenizar20 TEXT,
        cadebensNumero TEXT,
        cadebensSituacao TEXT,
        observacao TEXT,
        criadoEm TEXT,
        atualizadoEm TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_atendimentos_paciente
      ON atendimentos(pacienteNome, cpf)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_atendimentos_horario
      ON atendimentos(horario, statusAtendimento)
    ''');
  }

  Future<void> _ensureOperationalColumns(Database db) async {
    if (await _tableExists(db, 'pacientes')) {
      await _ensureColumn(db,
          table: 'pacientes', column: 'sexo', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'email', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'celular', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'peso', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'altura', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'nomeMae', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'nomePai', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'cep', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'bairro', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'cidade', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'uf', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'matricula', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes',
          column: 'categoriaBeneficiario',
          definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'cadebensNumero', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'cadebensSituacao', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pacientes', column: 'codigoAcessoPortal', definition: 'TEXT');
    }

    if (await _tableExists(db, 'cadebens_integracao')) {
      await _ensureColumn(db,
          table: 'cadebens_integracao',
          column: 'nascimento',
          definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'sexo', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'cns', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'preccp', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'telefone', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'celular', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'email', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'endereco', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'cep', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'bairro', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'cidade', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'uf', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'nomeMae', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'nomePai', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'peso', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'cadebens_integracao', column: 'altura', definition: 'TEXT');
    }

    if (await _tableExists(db, 'exames')) {
      await _ensureColumn(db,
          table: 'exames', column: 'valorCheio', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'exames', column: 'valorIndenizar20', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'exames', column: 'codigoCadebens', definition: 'TEXT');
    }

    if (await _tableExists(db, 'pedidos')) {
      await _ensureColumn(db,
          table: 'pedidos', column: 'agendamentoId', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pedidos', column: 'valorCheio', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pedidos', column: 'valorIndenizar20', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pedidos', column: 'cadebensNumero', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pedidos', column: 'numeroAtendimento', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'pedidos', column: 'codigoEtiqueta', definition: 'TEXT');
    }

    if (await _tableExists(db, 'resultados')) {
      await _ensureColumn(db,
          table: 'resultados',
          column: 'valorBrutoEquipamento',
          definition: 'TEXT');
      await _ensureColumn(db,
          table: 'resultados',
          column: 'mensagemBrutaEquipamento',
          definition: 'TEXT');
    }

    if (await _tableExists(db, 'laudos')) {
      await _ensureColumn(db,
          table: 'laudos', column: 'resultadoId', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'laudos', column: 'exameId', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'laudos',
          column: 'profissionalResponsavel',
          definition: 'TEXT');
      await _ensureColumn(db,
          table: 'laudos', column: 'responsavelConselho', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'laudos', column: 'conteudo', definition: 'TEXT');
      await _ensureColumn(db,
          table: 'laudos', column: 'observacao', definition: 'TEXT');
    }
  }

  Future<void> _createRetentionAndHistoryTables(Database db) async {
    await db.execute('''
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
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hist_exames_paciente_nome
      ON historico_exames_pacientes(pacienteNome)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hist_exames_cpf
      ON historico_exames_pacientes(cpf)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hist_exames_preccp
      ON historico_exames_pacientes(preccp)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hist_exames_pedido
      ON historico_exames_pacientes(pedidoId)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hist_exames_liberado
      ON historico_exames_pacientes(liberadoEm)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hist_exames_arquivado
      ON historico_exames_pacientes(arquivado, ativoConsultaRecente)
    ''');
  }

  Future<void> _createEquipmentConnectionTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS equipment_connections (
        id TEXT PRIMARY KEY,
        nome TEXT,
        fabricante TEXT,
        modelo TEXT,
        setor TEXT,
        tipoConexao TEXT,
        protocolo TEXT,
        ip TEXT,
        portaTcp TEXT,
        portaCom TEXT,
        baudRate TEXT,
        dataBits TEXT,
        stopBits TEXT,
        paridade TEXT,
        handshake TEXT,
        pastaEntrada TEXT,
        pastaSaida TEXT,
        extensoesMonitoradas TEXT,
        driverPath TEXT,
        executavelPath TEXT,
        timeoutSegundos TEXT,
        ativo TEXT,
        observacao TEXT,
        criadoEm TEXT,
        atualizadoEm TEXT,
        ativoConsultaRecente TEXT DEFAULT '1',
        arquivado TEXT DEFAULT '0',
        excluidoFisicamente TEXT DEFAULT '0',
        bloqueioExclusao TEXT DEFAULT '1',
        arquivadoEm TEXT,
        motivoArquivamento TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_equipment_connections_nome
      ON equipment_connections(nome)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_equipment_connections_tipo
      ON equipment_connections(tipoConexao, protocolo)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_equipment_connections_ativo
      ON equipment_connections(ativo, arquivado)
    ''');
  }

  Future<void> _ensurePermanentRetentionColumns(Database db) async {
    final List<String> protectedTables = <String>[
      'pacientes',
      'pedidos',
      'amostras',
      'resultados',
      'laudos',
      'exames',
      'equipamentos',
      'materiais',
      'estoque',
      'calibracoes',
      'manutencoes',
      'controle_qualidade',
      'atendimentos',
      'agendamentos',
      'cadebens_integracao',
      'configuracoes',
      'auditoria',
      'equipment_connections',
    ];

    for (final String table in protectedTables) {
      if (!await _tableExists(db, table)) continue;

      await _ensureColumn(
        db,
        table: table,
        column: 'ativoConsultaRecente',
        definition: "TEXT DEFAULT '1'",
      );

      await _ensureColumn(
        db,
        table: table,
        column: 'arquivado',
        definition: "TEXT DEFAULT '0'",
      );

      await _ensureColumn(
        db,
        table: table,
        column: 'excluidoFisicamente',
        definition: "TEXT DEFAULT '0'",
      );

      await _ensureColumn(
        db,
        table: table,
        column: 'bloqueioExclusao',
        definition: "TEXT DEFAULT '1'",
      );

      await _ensureColumn(
        db,
        table: table,
        column: 'arquivadoEm',
        definition: 'TEXT',
      );

      await _ensureColumn(
        db,
        table: table,
        column: 'motivoArquivamento',
        definition: 'TEXT',
      );

      await _ensureColumn(
        db,
        table: table,
        column: 'atualizadoEm',
        definition: 'TEXT',
      );
    }

    if (await _tableExists(db, 'historico_exames_pacientes')) {
      await db.execute('''
        UPDATE historico_exames_pacientes
        SET ativoConsultaRecente = '0'
        WHERE ativoConsultaRecente IS NULL OR ativoConsultaRecente = ''
      ''');

      await db.execute('''
        UPDATE historico_exames_pacientes
        SET arquivado = '1'
        WHERE arquivado IS NULL OR arquivado = ''
      ''');
    }
  }

  Future<bool> _tableExists(Database db, String table) async {
    final List<Map<String, Object?>> result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      <Object?>[table],
    );

    return result.isNotEmpty;
  }

  Future<void> _ensureColumn(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final List<Map<String, Object?>> columns =
        await db.rawQuery('PRAGMA table_info($table)');

    final bool exists = columns.any(
      (Map<String, Object?> row) => row['name']?.toString() == column,
    );

    if (exists) return;

    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }
}
