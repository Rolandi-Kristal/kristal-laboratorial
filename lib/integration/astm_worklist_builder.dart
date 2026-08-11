class AstmWorklistBuilder {
  static String build(
      {required String pedidoId,
      required String paciente,
      required String amostra,
      required List<String> exames}) {
    return 'H|\\^&|||KRISTAL LAB|||||||P|1\rP|1|$pedidoId||$paciente\rO|1|$amostra||${exames.join('\\')}|R||||||A\rL|1|N\r';
  }
}
