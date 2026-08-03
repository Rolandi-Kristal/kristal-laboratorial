class BarcodeService {
  static String amostraCode(String pedidoId, String material) {
    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final m = material.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return 'KLAB-${stamp.substring(stamp.length-8)}-${m.substring(0, m.length < 3 ? m.length : 3)}-${pedidoId.hashCode.abs().toString().padLeft(5,'0')}';
  }
}
