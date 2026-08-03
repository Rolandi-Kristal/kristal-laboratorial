import 'lab_repository.dart';

class EtiquetaService {
  EtiquetaService._();

  static final EtiquetaService instance = EtiquetaService._();

  final LabRepository _repo = LabRepository();

  Future<bool> codigoExiste(String codigo) {
    return _repo.existsWhere(
      'amostras',
      'codigoBarras = ? OR codigoManual = ?',
      <Object?>[codigo, codigo],
    );
  }

  Future<void> criarEtiqueta({
    required String pacienteId,
    required String pedidoId,
    required String exameId,
    required String codigoBarras,
    String codigoManual = '',
    String tipoLeitura = 'MANUAL',
    String imagemPath = '',
    String observacao = '',
  }) {
    return salvarEtiqueta(
      codigoBarras: codigoBarras,
      codigoManual: codigoManual.isEmpty ? codigoBarras : codigoManual,
      tipoLeitura: tipoLeitura,
      pacienteId: pacienteId,
      pedidoId: pedidoId,
      exameId: exameId,
      imagemPath: imagemPath,
      observacao: observacao,
    );
  }

  Future<void> salvarEtiqueta({
    required String codigoBarras,
    required String codigoManual,
    required String tipoLeitura,
    required String pacienteId,
    required String pedidoId,
    required String exameId,
    required String imagemPath,
    required String observacao,
  }) async {
    final String now = DateTime.now().toIso8601String();
    final String normalizedPedido = pedidoId.trim();
    if (normalizedPedido.isEmpty) {
      throw ArgumentError(
          'Número do atendimento/pedido obrigatório para etiqueta.');
    }
    if (codigoBarras.trim() != normalizedPedido ||
        codigoManual.trim() != normalizedPedido) {
      throw ArgumentError(
          'A etiqueta deve usar exatamente a mesma numeração do atendimento/pedido.');
    }

    await _repo.upsert('amostras', <String, dynamic>{
      'id': normalizedPedido,
      'pacienteId': pacienteId,
      'pedidoId': pedidoId,
      'exameId': exameId,
      'codigoBarras': codigoBarras,
      'codigoManual': codigoManual,
      'tipoLeitura': tipoLeitura,
      'imagemPath': imagemPath,
      'status': 'COLETADA',
      'coletadoEm': now,
      'criadoEm': now,
      'criadoPor': 'SISTEMA',
      'observacao': observacao,
    });
  }

  Future<List<Map<String, dynamic>>> listarEtiquetas() {
    return _repo.all('amostras', orderBy: 'criadoEm DESC');
  }

  Future<void> excluirEtiqueta(String id) {
    return _repo.archiveWithoutDelete('amostras', id, usuario: 'sistema');
  }
}
