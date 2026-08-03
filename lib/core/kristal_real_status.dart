class KristalRealStatus {
  const KristalRealStatus._();

  static String loaded({required int total}) {
    return 'Dados carregados com sucesso. Registros carregados: $total.';
  }

  static String saved() {
    return 'Registro salvo com sucesso.';
  }

  static String exported(String path) {
    return 'ExportaÃ§Ã£o concluÃ­da: $path';
  }

  static String updated({required int total}) {
    return 'AtualizaÃ§Ã£o concluÃ­da. Registros carregados: $total.';
  }

  static String error(Object error) {
    return 'Falha operacional: $error';
  }
}
