import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'audit_service.dart';
import 'auth_service.dart';
import 'lab_repository.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  final LabRepository _repo = LabRepository();

  String hashPassword(String password) {
    return sha256.convert(utf8.encode('KRISTAL_LAB|$password')).toString();
  }

  Future<void> criarOperador({
    required AuthSession session,
    required String nome,
    required String login,
    required String senha,
    required String perfil,
  }) async {
    if (!session.canManageUsers) {
      throw StateError(
        'Somente Superusuario ou Administrador pode cadastrar operadores.',
      );
    }

    final String nomeNormalizado = nome.trim();
    final String loginNormalizado = login.trim();

    if (nomeNormalizado.isEmpty) {
      throw ArgumentError('Informe o nome do operador.');
    }

    if (loginNormalizado.isEmpty) {
      throw ArgumentError('Informe o login do operador.');
    }

    if (senha.length < 6) {
      throw ArgumentError('A senha deve ter pelo menos 6 caracteres.');
    }

    final bool loginEmUso = await _repo.existsWhere(
      'usuarios',
      'login = ?',
      <Object?>[loginNormalizado],
    );

    if (loginEmUso) {
      throw StateError('Ja existe um operador cadastrado com este login.');
    }

    final String now = DateTime.now().toIso8601String();

    await _repo.upsert('usuarios', <String, dynamic>{
      'id': 'USER-${DateTime.now().microsecondsSinceEpoch}',
      'nome': nomeNormalizado,
      'login': loginNormalizado,
      'senhaHash': hashPassword(senha),
      'perfil': perfil,
      'ativo': '1',
      'criadoEm': now,
      'atualizadoEm': now,
    });

    await AuditService.instance.registrar(
      usuario: session.login,
      acao: 'CRIAR_USUARIO',
      tabela: 'usuarios',
      registroId: loginNormalizado,
      detalhes: 'Operador cadastrado com perfil $perfil.',
    );
  }

  Future<List<Map<String, dynamic>>> listarUsuarios() {
    return _repo.all('usuarios', orderBy: 'nome ASC');
  }
}
