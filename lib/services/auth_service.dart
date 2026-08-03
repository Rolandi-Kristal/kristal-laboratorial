import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/app_constants.dart';
import 'audit_service.dart';
import 'lab_repository.dart';

class AuthSession {
  final String login;
  final String nome;
  final String perfil;

  const AuthSession({
    required this.login,
    required this.nome,
    required this.perfil,
  });

  bool get isSuperUser => perfil == 'SUPER_USUARIO';
  bool get isAdmin => perfil == 'ADMINISTRADOR' || isSuperUser;
  bool get canManageUsers => isAdmin;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final LabRepository _repo = LabRepository();

  AuthSession? _session;

  AuthSession? get session => _session;

  Future<AuthSession?> login({
    required String login,
    required String password,
  }) async {
    final String normalizedLogin = login.trim();

    if (normalizedLogin == AppConstants.masterLogin &&
        password == AppConstants.masterPassword) {
      _session = const AuthSession(
        login: AppConstants.masterLogin,
        nome: 'Super Usuario',
        perfil: 'SUPER_USUARIO',
      );

      await AuditService.instance.registrar(
        usuario: normalizedLogin,
        acao: 'LOGIN',
        tabela: 'usuarios',
        registroId: normalizedLogin,
        detalhes: 'Login superusuario efetuado.',
      );

      return _session;
    }

    final List<Map<String, dynamic>> users = await _repo.all(
      'usuarios',
      where: 'login = ? AND ativo = ?',
      whereArgs: <Object?>[normalizedLogin, '1'],
      limit: 1,
    );

    if (users.isNotEmpty) {
      final Map<String, dynamic> user = users.first;
      final String storedHash = user['senhaHash']?.toString() ?? '';

      if (storedHash == _hashPassword(password)) {
        _session = AuthSession(
          login: user['login']?.toString() ?? normalizedLogin,
          nome: user['nome']?.toString() ?? normalizedLogin,
          perfil: user['perfil']?.toString() ?? 'OPERADOR',
        );

        await AuditService.instance.registrar(
          usuario: normalizedLogin,
          acao: 'LOGIN',
          tabela: 'usuarios',
          registroId: user['id']?.toString() ?? normalizedLogin,
          detalhes: 'Login de operador efetuado.',
        );

        return _session;
      }
    }

    await AuditService.instance.registrar(
      usuario: normalizedLogin,
      acao: 'LOGIN_NEGADO',
      tabela: 'usuarios',
      registroId: normalizedLogin,
      detalhes: 'Tentativa de login invalida.',
    );

    return null;
  }

  Future<AuthSession?> loginMaster(String usuario, String senha) {
    return login(login: usuario, password: senha);
  }

  void logout() {
    _session = null;
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode('KRISTAL_LAB|$password')).toString();
  }
}
