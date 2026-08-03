import 'auth_service.dart';

enum KristalPermission {
  dashboard,
  pacientes,
  exames,
  pedidos,
  etiquetas,
  resultados,
  laudos,
  equipamentos,
  integracaoEquipamentos,
  portalPaciente,
  backup,
  auditoria,
  usuarios,
  configuracoes,
  liberarLaudo,
  excluirRegistro,
  restaurarBackup,
}

class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  bool can(AuthSession session, KristalPermission permission) {
    if (session.isSuperUser) return true;

    final String perfil = session.perfil.toUpperCase();

    if (perfil == 'ADMINISTRADOR') {
      return permission != KristalPermission.restaurarBackup;
    }

    if (perfil == 'RECEPCAO') {
      return <KristalPermission>{
        KristalPermission.dashboard,
        KristalPermission.pacientes,
        KristalPermission.pedidos,
        KristalPermission.portalPaciente,
      }.contains(permission);
    }

    if (perfil == 'COLETA') {
      return <KristalPermission>{
        KristalPermission.dashboard,
        KristalPermission.pacientes,
        KristalPermission.pedidos,
        KristalPermission.etiquetas,
      }.contains(permission);
    }

    if (perfil == 'TECNICO') {
      return <KristalPermission>{
        KristalPermission.dashboard,
        KristalPermission.exames,
        KristalPermission.etiquetas,
        KristalPermission.resultados,
        KristalPermission.integracaoEquipamentos,
      }.contains(permission);
    }

    if (perfil == 'RESPONSAVEL_TECNICO') {
      return <KristalPermission>{
        KristalPermission.dashboard,
        KristalPermission.pacientes,
        KristalPermission.exames,
        KristalPermission.pedidos,
        KristalPermission.etiquetas,
        KristalPermission.resultados,
        KristalPermission.laudos,
        KristalPermission.liberarLaudo,
      }.contains(permission);
    }

    return permission == KristalPermission.dashboard;
  }
}
