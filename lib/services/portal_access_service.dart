import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'audit_service.dart';
import 'lab_repository.dart';

class PortalAccessService {
  PortalAccessService._();

  static final PortalAccessService instance = PortalAccessService._();

  final LabRepository _repo = LabRepository();

  String gerarToken({
    required String cpf,
    required String pedidoId,
  }) {
    final String base = '$cpf|$pedidoId|KRISTAL_PORTAL';
    return sha256.convert(utf8.encode(base)).toString().substring(0, 12).toUpperCase();
  }

  Future<List<Map<String, dynamic>>> consultarLaudosLiberados({
    required String cpf,
    required String token,
  }) async {
    final List<Map<String, dynamic>> pacientes = await _repo.all(
      'pacientes',
      where: 'cpf = ?',
      whereArgs: <Object?>[cpf],
      limit: 1,
    );

    if (pacientes.isEmpty) return <Map<String, dynamic>>[];

    final String pacienteId = pacientes.first['id']?.toString() ?? '';

    final List<Map<String, dynamic>> laudos = await _repo.all(
      'laudos',
      where: 'pacienteId = ? AND status = ?',
      whereArgs: <Object?>[pacienteId, 'LIBERADO'],
    );

    final List<Map<String, dynamic>> autorizados = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> laudo in laudos) {
      final String pedidoId = laudo['pedidoId']?.toString() ?? '';
      final String expected = gerarToken(cpf: cpf, pedidoId: pedidoId);

      if (expected == token.trim().toUpperCase()) {
        autorizados.add(laudo);
      }
    }

    await AuditService.instance.registrar(
      usuario: 'PORTAL_PACIENTE',
      acao: 'CONSULTA_PORTAL',
      tabela: 'laudos',
      registroId: cpf,
      detalhes: 'Consulta de laudos liberados pelo portal do paciente.',
    );

    return autorizados;
  }
}
