class KristalRealStatus {
  const KristalRealStatus._();

  static String loaded({required int total}) {
    return 'Dados carregados com sucesso. Registros carregados: $total.';
  }

  static String saved() {
    return 'Registro salvo com sucesso.';
  }

  static String exported(String path) {
    return 'Exportação concluída: $path';
  }

  static String updated({required int total}) {
    return 'Atualização concluída. Registros carregados: $total.';
  }

  static String error(Object error) {
    return 'Falha operacional: $error';
  }
}
