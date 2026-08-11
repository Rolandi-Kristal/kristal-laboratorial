import 'package:flutter_test/flutter_test.dart';
import 'package:kristal_laboratorial/services/auth_service.dart';
import 'package:kristal_laboratorial/services/equipment_connection_service.dart';
import 'package:kristal_laboratorial/services/permission_service.dart';

void main() {
  const AuthSession superUser = AuthSession(
    login: 'super',
    nome: 'Superusuário',
    perfil: 'SUPER_USUARIO',
  );
  const AuthSession administrator = AuthSession(
    login: 'admin',
    nome: 'Administrador',
    perfil: 'ADMINISTRADOR',
  );
  const AuthSession operator = AuthSession(
    login: 'operador',
    nome: 'Operador',
    perfil: 'RECEPCAO',
  );

  group('PermissionService - retenção permanente', () {
    test('superusuário pode solicitar exclusão lógica e restauração', () {
      expect(
        PermissionService.instance.can(
          superUser,
          KristalPermission.excluirRegistro,
        ),
        isTrue,
      );
      expect(
        PermissionService.instance.can(
          superUser,
          KristalPermission.restaurarBackup,
        ),
        isTrue,
      );
    });

    test('administrador não pode excluir nem restaurar backup', () {
      expect(
        PermissionService.instance.can(
          administrator,
          KristalPermission.excluirRegistro,
        ),
        isFalse,
      );
      expect(
        PermissionService.instance.can(
          administrator,
          KristalPermission.restaurarBackup,
        ),
        isFalse,
      );
    });

    test('operador convencional não pode excluir registros', () {
      expect(
        PermissionService.instance.can(
          operator,
          KristalPermission.excluirRegistro,
        ),
        isFalse,
      );
    });

    test('administrador não pode arquivar configuração de equipamento',
        () async {
      await expectLater(
        EquipmentConnectionService.instance.excluir(
          session: administrator,
          id: 'EQ-1',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
