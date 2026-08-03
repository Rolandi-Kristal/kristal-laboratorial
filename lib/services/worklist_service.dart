import 'equipment_adapter_service.dart';
import 'lab_repository.dart';
import 'sample_code_service.dart';

class WorklistItem {
  final String pacienteId;
  final String pedidoId;
  final String exameId;
  final String exameCodigo;
  final String amostraId;

  const WorklistItem({
    required this.pacienteId,
    required this.pedidoId,
    required this.exameId,
    required this.exameCodigo,
    required this.amostraId,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'pacienteId': pacienteId,
      'pedidoId': pedidoId,
      'exameId': exameId,
      'exameCodigo': exameCodigo,
      'amostraId': amostraId,
    };
  }
}

class WorklistService {
  WorklistService._();

  static final WorklistService instance = WorklistService._();

  final LabRepository _repo = LabRepository();

  Future<List<WorklistItem>> pendentes() async {
    final List<Map<String, dynamic>> pedidos = await _repo.all(
      'pedidos',
      where: 'status = ?',
      whereArgs: <Object?>['ABERTO'],
      orderBy: 'criadoEm DESC',
    );

    final List<Map<String, dynamic>> exames = await _repo.all('exames');

    final List<WorklistItem> items = <WorklistItem>[];

    for (final Map<String, dynamic> pedido in pedidos) {
      final String pacienteId = pedido['pacienteId']?.toString() ?? '';
      final String pedidoId = pedido['id']?.toString() ?? '';

      for (final Map<String, dynamic> exame in exames) {
        final String exameId = exame['id']?.toString() ?? '';
        final String exameCodigo = exame['codigo']?.toString() ?? exameId;

        if (pacienteId.isEmpty || pedidoId.isEmpty || exameId.isEmpty) {
          continue;
        }

        final String amostraId = SampleCodeService.gerarCodigoAmostra(
          pacienteId: pacienteId,
          pedidoId: pedidoId,
          exameId: exameId,
        );

        items.add(
          WorklistItem(
            pacienteId: pacienteId,
            pedidoId: pedidoId,
            exameId: exameId,
            exameCodigo: exameCodigo,
            amostraId: amostraId,
          ),
        );
      }
    }

    return items;
  }

  Future<String> gerarMensagem({
    required WorklistItem item,
    required String protocolo,
  }) async {
    if (protocolo.toUpperCase() == 'HL7') {
      return EquipmentAdapterService.instance.buildHl7Orm(
        pacienteId: item.pacienteId,
        pedidoId: item.pedidoId,
        exameCodigo: item.exameCodigo,
        amostraId: item.amostraId,
      );
    }

    return EquipmentAdapterService.instance.buildAstmOrder(
      pacienteId: item.pacienteId,
      pedidoId: item.pedidoId,
      exameCodigo: item.exameCodigo,
      amostraId: item.amostraId,
    );
  }
}
