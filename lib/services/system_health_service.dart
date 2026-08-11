import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/app_constants.dart';
import 'database_service.dart';
import 'lab_repository.dart';

class SystemHealthStatus {
  final String item;
  final bool ok;
  final String detalhe;

  const SystemHealthStatus({
    required this.item,
    required this.ok,
    required this.detalhe,
  });
}

class SystemHealthService {
  SystemHealthService._();

  static final SystemHealthService instance = SystemHealthService._();

  final LabRepository _repo = LabRepository();

  Future<List<SystemHealthStatus>> check() async {
    final List<SystemHealthStatus> status = <SystemHealthStatus>[];

    void addFailure(String item, Object error) {
      status.add(
        SystemHealthStatus(
          item: item,
          ok: false,
          detalhe: error.toString(),
        ),
      );
    }

    try {
      await DatabaseService.instance.database;
      final String dbPath = await DatabaseService.instance.databasePath();
      status.add(
        SystemHealthStatus(
          item: 'Banco de dados',
          ok: File(dbPath).existsSync(),
          detalhe: dbPath,
        ),
      );
    } on DatabaseException catch (error) {
      addFailure('Banco de dados', error);
    } on FileSystemException catch (error) {
      addFailure('Banco de dados', error);
    }

    try {
      final Directory support = await getApplicationSupportDirectory();
      status.add(
        SystemHealthStatus(
          item: 'Diretório de suporte',
          ok: support.existsSync(),
          detalhe: support.path,
        ),
      );
    } on MissingPluginException catch (error) {
      addFailure('Diretório de suporte', error);
    } on FileSystemException catch (error) {
      addFailure('Diretório de suporte', error);
    }

    try {
      final List<String> tables = <String>[
        'pacientes',
        'exames',
        'atendimentos',
        'agendamentos',
        'cadebens_integracao',
        'pedidos',
        'amostras',
        'resultados',
        'laudos',
        'equipamentos',
        'usuarios',
        'auditoria',
        'materiais',
        'estoque',
        'calibracoes',
        'manutencoes',
        'controle_qualidade',
      ];
      for (final String table in tables) {
        final int total = await _repo.count(table);
        status.add(
          SystemHealthStatus(
            item: 'Tabela $table',
            ok: true,
            detalhe: '$total registro(s)',
          ),
        );
      }
    } on DatabaseException catch (error) {
      addFailure('Tabelas do sistema', error);
    }

    status.add(
      const SystemHealthStatus(
        item: 'Crédito do desenvolvedor',
        ok: AppConstants.developerCredit ==
            'Desenvolvedor: 3° Sgt Rolandi - H Mil Resende',
        detalhe: AppConstants.developerCredit,
      ),
    );
    return status;
  }
}
