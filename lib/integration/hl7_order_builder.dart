class Hl7OrderBuilder {
  static String buildOrm({required String pedidoId, required String paciente, required String amostra, required List<String> exames}) {
    final now = DateTime.now().toIso8601String().replaceAll(RegExp(r'[-:T.]'), '').substring(0,14);
    return ['MSH|^~\\&|KRISTAL|LAB|EQUIP|LAB|$now||ORM^O01|$pedidoId|P|2.3', 'PID|||$pedidoId||$paciente', 'ORC|NW|$pedidoId', 'OBR|1|$pedidoId|$amostra|${exames.join('^')}'].join('\r');
  }
}
