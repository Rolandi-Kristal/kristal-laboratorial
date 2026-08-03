import 'auth_service.dart';

class OperationGuardService {
  OperationGuardService._();

  static void requireSuperUser(AuthSession session) {
    if (!session.isSuperUser) {
      throw StateError('Operação permitida somente ao Superusuário.');
    }
  }

  static void requireAdmin(AuthSession session) {
    if (!session.isAdmin) {
      throw StateError(
        'Operação permitida somente ao Superusuário ou Administrador.',
      );
    }
  }

  static void requireResponsibleOrSuperUser(AuthSession session) {
    if (!(session.isSuperUser ||
        session.perfil.toUpperCase() == 'RESPONSAVEL_TECNICO')) {
      throw StateError(
        'Operação permitida somente ao Superusuário ou Responsável Técnico.',
      );
    }
  }
}
