import 'dart:io';

import 'package:path/path.dart' as p;

import 'audit_service.dart';
import 'auth_service.dart';
import 'lab_repository.dart';

class FaturamentoSireConfig {
  final String exePath;
  final String pastaBase;
  final String ativo;
  final String observacao;

  const FaturamentoSireConfig({
    required this.exePath,
    required this.pastaBase,
    required this.ativo,
    required this.observacao,
  });

  bool get isAtivo => ativo == '1';

  factory FaturamentoSireConfig.empty() {
    return const FaturamentoSireConfig(
      exePath: '',
      pastaBase: r'D:\kristal_laboratorial\drivers',
      ativo: '0',
      observacao: '',
    );
  }
}

class FaturamentoSireService {
  FaturamentoSireService._();

  static final FaturamentoSireService instance = FaturamentoSireService._();

  final LabRepository _repo = LabRepository();

  Future<FaturamentoSireConfig> carregar() async {
    final List<Map<String, dynamic>> rows = await _repo.all('configuracoes');

    String getValue(String key) {
      for (final Map<String, dynamic> row in rows) {
        final String chave = row['chave']?.toString() ?? '';
        if (chave == key) {
          return row['valor']?.toString() ?? '';
        }
      }
      return '';
    }

    final String pasta = getValue('sire_pasta_base');

    return FaturamentoSireConfig(
      exePath: getValue('sire_exe_path'),
      pastaBase: pasta.isEmpty ? r'D:\kristal_laboratorial\drivers' : pasta,
      ativo: getValue('sire_ativo').isEmpty ? '0' : getValue('sire_ativo'),
      observacao: getValue('sire_observacao'),
    );
  }

  Future<void> salvar({
    required AuthSession session,
    required FaturamentoSireConfig config,
  }) async {
    if (!session.isAdmin) {
      throw StateError(
        'Somente Superusuário ou Administrador pode configurar o Faturamento SIRE.',
      );
    }

    final String now = DateTime.now().toIso8601String();

    final Map<String, String> values = <String, String>{
      'sire_exe_path': config.exePath,
      'sire_pasta_base': config.pastaBase,
      'sire_ativo': config.ativo,
      'sire_observacao': config.observacao,
    };

    for (final MapEntry<String, String> entry in values.entries) {
      await _repo.upsert(
        'configuracoes',
        <String, dynamic>{
          'id': entry.key,
          'chave': entry.key,
          'valor': entry.value,
          'atualizadoEm': now,
        },
      );
    }

    await AuditService.instance.registrar(
      usuario: session.login,
      acao: 'CONFIGURAR_FATURAMENTO_SIRE',
      tabela: 'configuracoes',
      registroId: 'sire',
      detalhes:
          'EXE=${config.exePath}; pasta=${config.pastaBase}; ativo=${config.ativo}',
    );
  }

  Future<String> localizarExeAutomatico({
    required String pastaRaiz,
  }) async {
    final Directory root = Directory(pastaRaiz.trim());

    if (!await root.exists()) {
      return '';
    }

    final List<String> nomesPossiveis = <String>[
      'FaturamentoSIRE_Externos.exe',
      'FaturamentoSIRE.exe',
      'faturamentosire_externos.exe',
      'faturamentosire.exe',
      'SIRE.exe',
      'sire.exe',
    ];

    await for (final FileSystemEntity entity in root.list(recursive: true)) {
      if (entity is! File) continue;

      final String fileName = p.basename(entity.path).toLowerCase();

      for (final String nome in nomesPossiveis) {
        if (fileName == nome.toLowerCase()) {
          return entity.path;
        }
      }
    }

    return '';
  }

  Future<bool> validarExecutavel(String exePath) async {
    final String path = exePath.trim();
    if (path.isEmpty) return false;

    final File exe = File(path);
    if (!await exe.exists()) return false;

    return p.extension(exe.path).toLowerCase() == '.exe';
  }

  Future<void> abrir({
    required AuthSession session,
  }) async {
    final FaturamentoSireConfig config = await carregar();

    if (!config.isAtivo) {
      throw StateError('A integração com o Faturamento SIRE está desativada.');
    }

    if (config.exePath.trim().isEmpty) {
      throw StateError('Caminho do Faturamento SIRE não configurado.');
    }

    final File exe = File(config.exePath.trim());

    if (!await exe.exists()) {
      throw StateError(
          'Executável do Faturamento SIRE não encontrado: ${exe.path}');
    }

    await AuditService.instance.registrar(
      usuario: session.login,
      acao: 'ABRIR_FATURAMENTO_SIRE',
      tabela: 'configuracoes',
      registroId: 'sire',
      detalhes: exe.path,
    );

    await Process.start(
      exe.path,
      <String>[],
      workingDirectory: exe.parent.path,
      mode: ProcessStartMode.detached,
    );
  }
}
