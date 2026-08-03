import 'audit_service.dart';
import 'lab_repository.dart';

class EstoqueService {
  EstoqueService._();

  static final EstoqueService instance = EstoqueService._();

  final LabRepository _repo = LabRepository();

  Future<void> salvarMaterial(Map<String, dynamic> material, {String usuario = 'SISTEMA'}) async {
    await _repo.upsert('materiais', material);

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'SALVAR_MATERIAL',
      tabela: 'materiais',
      registroId: material['id']?.toString() ?? '',
      detalhes: 'Material/reagente cadastrado ou atualizado.',
    );
  }

  Future<void> salvarLote(Map<String, dynamic> lote, {String usuario = 'SISTEMA'}) async {
    await _repo.upsert('estoque', lote);

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'SALVAR_LOTE_ESTOQUE',
      tabela: 'estoque',
      registroId: lote['id']?.toString() ?? '',
      detalhes: 'Lote de estoque cadastrado ou atualizado.',
    );
  }

  Future<List<Map<String, dynamic>>> materiais() {
    return _repo.all('materiais', orderBy: 'nome ASC');
  }

  Future<List<Map<String, dynamic>>> lotes() {
    return _repo.all('estoque', orderBy: 'validade ASC');
  }

  Future<List<Map<String, dynamic>>> lotesVencendo({int dias = 30}) async {
    final DateTime limite = DateTime.now().add(Duration(days: dias));
    final List<Map<String, dynamic>> rows = await lotes();

    return rows.where((Map<String, dynamic> row) {
      final DateTime? validade = DateTime.tryParse(row['validade']?.toString() ?? '');
      if (validade == null) return false;
      return validade.isBefore(limite);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> estoqueCritico() async {
    final List<Map<String, dynamic>> materiaisRows = await materiais();
    final List<Map<String, dynamic>> lotesRows = await lotes();

    final List<Map<String, dynamic>> criticos = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> material in materiaisRows) {
      final String materialId = material['id']?.toString() ?? '';
      final double minimo =
          double.tryParse(material['estoqueMinimo']?.toString() ?? '0') ?? 0;

      double total = 0;
      for (final Map<String, dynamic> lote in lotesRows) {
        if ((lote['materialId']?.toString() ?? '') == materialId) {
          total += double.tryParse(lote['quantidade']?.toString() ?? '0') ?? 0;
        }
      }

      if (total <= minimo) {
        criticos.add(<String, dynamic>{
          ...material,
          'quantidadeAtual': total.toStringAsFixed(2),
        });
      }
    }

    return criticos;
  }
}
