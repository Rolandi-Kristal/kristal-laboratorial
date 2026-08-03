import 'equipment_adapter_service.dart';
import 'exame_catalog_service.dart';
import 'lab_repository.dart';

class SeedService {
  SeedService._();

  static final SeedService instance = SeedService._();

  final LabRepository _repo = LabRepository();

  Future<void> instalarBaseInicial() async {
    await ExameCatalogService.instance.instalarCatalogoBasico();
    await _instalarEquipamentos();
    await _instalarMateriais();
  }

  Future<void> _instalarEquipamentos() async {
    for (final EquipmentProfile profile
        in EquipmentAdapterService.instance.perfisPadrao()) {
      await _repo.upsert('equipamentos', profile.toMap());
    }
  }

  Future<void> _instalarMateriais() async {
    final String now = DateTime.now().toIso8601String();

    final List<Map<String, dynamic>> materiais = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'MAT-EDTA',
        'codigo': 'EDTA',
        'nome': 'Tubo EDTA',
        'tipo': 'Coleta',
        'unidade': 'un',
        'estoqueMinimo': '50',
        'ativo': '1',
        'criadoEm': now,
      },
      <String, dynamic>{
        'id': 'MAT-SORO',
        'codigo': 'SORO',
        'nome': 'Tubo seco / soro',
        'tipo': 'Coleta',
        'unidade': 'un',
        'estoqueMinimo': '50',
        'ativo': '1',
        'criadoEm': now,
      },
      <String, dynamic>{
        'id': 'MAT-URINA',
        'codigo': 'URINA',
        'nome': 'Frasco coletor de urina',
        'tipo': 'Coleta',
        'unidade': 'un',
        'estoqueMinimo': '30',
        'ativo': '1',
        'criadoEm': now,
      },
      <String, dynamic>{
        'id': 'MAT-CONTROLE-HEM',
        'codigo': 'CTRL-HEM',
        'nome': 'Controle hematológico',
        'tipo': 'Controle de qualidade',
        'unidade': 'frasco',
        'estoqueMinimo': '2',
        'ativo': '1',
        'criadoEm': now,
      },
    ];

    for (final Map<String, dynamic> material in materiais) {
      await _repo.upsert('materiais', material);
    }
  }
}
