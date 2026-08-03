import 'lab_repository.dart';

class ExameCatalogService {
  ExameCatalogService._();

  static final ExameCatalogService instance = ExameCatalogService._();

  final LabRepository _repo = LabRepository();

  Future<List<Map<String, dynamic>>> listarExames() {
    return _repo.all('exames', orderBy: 'nome ASC');
  }

  Future<void> salvarExame(Map<String, dynamic> data) {
    return _repo.upsert('exames', data);
  }

  Future<void> excluirExame(String id) {
    return _repo.archiveWithoutDelete('exames', id, usuario: 'sistema');
  }

  Future<void> instalarCatalogoBasico() async {
    final String now = DateTime.now().toIso8601String();

    final List<Map<String, dynamic>> exames = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'EXAME-HEMOGRAMA',
        'codigo': 'HEM',
        'nome': 'Hemograma Completo',
        'setor': 'Hematologia',
        'material': 'Sangue total EDTA',
        'metodo': 'Automatizado',
        'referencia': 'Conforme idade/sexo',
        'valorCheio': '50,00',
        'valorIndenizar20': '10,00',
        'codigoCadebens': 'HEM',
        'ativo': '1',
        'criadoEm': now,
      },
      <String, dynamic>{
        'id': 'EXAME-GLICOSE',
        'codigo': 'GLI',
        'nome': 'Glicose',
        'setor': 'Bioquimica',
        'material': 'Soro/Plasma',
        'metodo': 'Enzimatico',
        'referencia': '70 a 99 mg/dL em jejum',
        'valorCheio': '20,00',
        'valorIndenizar20': '4,00',
        'codigoCadebens': 'GLI',
        'ativo': '1',
        'criadoEm': now,
      },
      <String, dynamic>{
        'id': 'EXAME-EAS',
        'codigo': 'EAS',
        'nome': 'Urina tipo I / EAS',
        'setor': 'Urinalise',
        'material': 'Urina',
        'metodo': 'Fisico-quimico e microscopico',
        'referencia': 'Conforme parametro',
        'valorCheio': '25,00',
        'valorIndenizar20': '5,00',
        'codigoCadebens': 'EAS',
        'ativo': '1',
        'criadoEm': now,
      },
    ];

    for (final Map<String, dynamic> exame in exames) {
      await _repo.upsert('exames', exame);
    }
  }
}
