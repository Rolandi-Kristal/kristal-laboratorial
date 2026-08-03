class SampleCodeService {
  SampleCodeService._();

  static String gerarCodigoAmostra({
    required String pacienteId,
    required String pedidoId,
    required String exameId,
  }) {
    final String code = pedidoId.trim();
    if (code.isEmpty) {
      throw ArgumentError('pedidoId obrigatório para gerar etiqueta/amostra.');
    }
    return code;
  }

  static String gerarCodigoPedido({
    required String pacienteId,
  }) {
    final String stamp = DateTime.now().microsecondsSinceEpoch.toString();
    return 'ATD-$stamp';
  }
}
