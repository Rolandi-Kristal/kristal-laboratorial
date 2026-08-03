import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'lab_repository.dart';

class PortalPacienteService {
  PortalPacienteService._();

  static final PortalPacienteService instance = PortalPacienteService._();

  final LabRepository _repo = LabRepository();

  Future<String> getPortalUrl() async {
    final List<Map<String, dynamic>> rows = await _repo.all(
      'configuracoes',
      where: 'chave = ?',
      whereArgs: <Object?>['portal_paciente_url'],
      limit: 1,
    );

    if (rows.isEmpty) return '';

    return rows.first['valor']?.toString() ?? '';
  }

  Future<void> setPortalUrl(String url) async {
    await _repo.upsert('configuracoes', <String, dynamic>{
      'id': 'portal_paciente_url',
      'chave': 'portal_paciente_url',
      'valor': url,
      'atualizadoEm': DateTime.now().toIso8601String(),
    });
  }

  String gerarTokenPaciente({
    required String cpf,
    required String pedidoId,
  }) {
    final String base =
        '$cpf|$pedidoId|KRISTAL_LAB|${DateTime.now().toIso8601String()}';

    return sha256.convert(utf8.encode(base)).toString().substring(0, 12);
  }
}
