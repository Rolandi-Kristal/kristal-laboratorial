import 'lab_repository.dart';

class IndicadoresService {
  IndicadoresService._();

  static final IndicadoresService instance = IndicadoresService._();

  final LabRepository _repo = LabRepository();

  Future<Map<String, int>> carregarIndicadores() async {
    final int pacientes = await _repo.count('pacientes');
    final int exames = await _repo.count('exames');
    final int pedidos = await _repo.count('pedidos');
    final int amostras = await _repo.count('amostras');
    final int resultados = await _repo.count('resultados');
    final int laudos = await _repo.count('laudos');
    final int equipamentos = await _repo.count('equipamentos');

    final List<Map<String, dynamic>> resultadosRows = await _repo.all('resultados');
    final int criticos = resultadosRows
        .where(
          (Map<String, dynamic> r) =>
              (r['critico']?.toString().toUpperCase() ?? '') == 'SIM',
        )
        .length;

    final List<Map<String, dynamic>> amostrasRows = await _repo.all('amostras');
    final int coletadas = amostrasRows
        .where(
          (Map<String, dynamic> r) =>
              (r['status']?.toString().toUpperCase() ?? '') == 'COLETADA',
        )
        .length;

    return <String, int>{
      'Pacientes': pacientes,
      'Exames': exames,
      'Pedidos': pedidos,
      'Amostras': amostras,
      'Amostras coletadas': coletadas,
      'Resultados': resultados,
      'Resultados críticos': criticos,
      'Laudos': laudos,
      'Equipamentos': equipamentos,
    };
  }
}
