import '../utils/barcode_service.dart';
import 'lab_repository.dart';

class AmostraService {
  final _repo = LabRepository();
  Future<String> criar(
      {required String pedidoId,
      required String material,
      required String coletador}) async {
    final code = BarcodeService.amostraCode(pedidoId, material);
    await _repo.upsert('amostras', {
      'id': code,
      'pedidoId': pedidoId,
      'codigo': code,
      'material': material,
      'status': 'COLETADA',
      'coletador': coletador,
      'coletadoEm': DateTime.now().toIso8601String(),
      'observacao': ''
    });
    return code;
  }
}
