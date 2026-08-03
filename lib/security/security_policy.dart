class SecurityPolicy {
  static const sensitiveFields = <String>{
    'cpf','cns','preccp','telefone','endereco','observacao','detalhes','email'
  };
  static bool isSensitiveField(String field) => sensitiveFields.contains(field.toLowerCase());
  static bool canDelete(String perfil) => false;
  static bool canEdit(String perfil) => perfil == 'SUPER_USUARIO' || perfil == 'ADMINISTRADOR' || perfil == 'TECNICO' || perfil == 'BIOMEDICO';
  static bool isMaster(String login) => login == 'KristalLaboratorial';
}
