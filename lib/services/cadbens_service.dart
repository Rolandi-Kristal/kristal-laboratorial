import 'dart:convert';
import 'dart:io';

import 'audit_service.dart';
import 'lab_repository.dart';

class CadbensService {
  CadbensService._();

  static final CadbensService instance = CadbensService._();

  final LabRepository _repo = LabRepository();

  Future<int> importarTexto({
    required String conteudo,
    required String usuario,
  }) async {
    final List<String> lines = const LineSplitter()
        .convert(conteudo)
        .where((String line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return 0;

    final String separator = lines.first.contains(';') ? ';' : ',';
    final List<String> headers =
        _split(lines.first, separator).map(_normalizeHeader).toList();

    int total = 0;
    for (final String line in lines.skip(1)) {
      final List<String> values = _split(line, separator);
      final Map<String, String> raw = <String, String>{};
      for (int i = 0; i < headers.length && i < values.length; i++) {
        raw[headers[i]] = values[i].trim();
      }

      final Map<String, dynamic> data = _cadbensMap(raw);
      if ((data['cpf']?.toString() ?? '').isEmpty &&
          (data['pacienteNome']?.toString() ?? '').isEmpty) {
        continue;
      }

      await _repo.upsert('cadebens_integracao', data);
      total++;
    }

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'IMPORTAR_CADBENS',
      tabela: 'cadebens_integracao',
      registroId: 'lote_${DateTime.now().millisecondsSinceEpoch}',
      detalhes: '$total cadastro(s) CADBENS/FUSEx importado(s).',
    );

    return total;
  }

  Future<int> importarArquivo({
    required String path,
    required String usuario,
  }) async {
    final File file = File(path);
    final String conteudo = await file.readAsString(encoding: utf8);
    return importarTexto(conteudo: conteudo, usuario: usuario);
  }

  Future<Map<String, dynamic>?> consultar({
    String cpf = '',
    String nome = '',
    String numeroBeneficio = '',
  }) async {
    final List<Map<String, dynamic>> rows = await _repo.all(
      'cadebens_integracao',
      orderBy: 'pacienteNome ASC',
    );
    final String cpfLimpo = _digits(cpf);
    if (cpfLimpo.isNotEmpty) {
      for (final Map<String, dynamic> row in rows) {
        if (_digits(row['cpf']?.toString() ?? '') == cpfLimpo) return row;
      }
    }

    if (numeroBeneficio.trim().isNotEmpty) {
      for (final Map<String, dynamic> row in rows) {
        if ((row['numeroBeneficio']?.toString() ?? '').trim() ==
            numeroBeneficio.trim()) {
          return row;
        }
      }
    }

    if (nome.trim().isNotEmpty) {
      final String normalizedName = nome.trim().toLowerCase();
      for (final Map<String, dynamic> row in rows) {
        if ((row['pacienteNome']?.toString() ?? '')
            .toLowerCase()
            .contains(normalizedName)) {
          return row;
        }
      }
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> listar() {
    return _repo.all('cadebens_integracao', orderBy: 'pacienteNome ASC');
  }

  Map<String, dynamic> pacienteFromCadbens(Map<String, dynamic> data) {
    return <String, dynamic>{
      'id': data['pacienteId']?.toString().isNotEmpty == true
          ? data['pacienteId']
          : 'PAC-${DateTime.now().microsecondsSinceEpoch}',
      'nome': data['pacienteNome'] ?? '',
      'cpf': data['cpf'] ?? '',
      'cns': data['cns'] ?? '',
      'preccp': data['preccp'] ?? '',
      'nascimento': data['nascimento'] ?? '',
      'sexo': data['sexo'] ?? '',
      'telefone': data['telefone'] ?? '',
      'celular': data['celular'] ?? '',
      'email': data['email'] ?? '',
      'endereco': data['endereco'] ?? '',
      'cep': data['cep'] ?? '',
      'bairro': data['bairro'] ?? '',
      'cidade': data['cidade'] ?? '',
      'uf': data['uf'] ?? '',
      'nomeMae': data['nomeMae'] ?? '',
      'nomePai': data['nomePai'] ?? '',
      'peso': data['peso'] ?? '',
      'altura': data['altura'] ?? '',
      'matricula': data['matricula'] ?? '',
      'categoriaBeneficiario': data['categoria'] ?? '',
      'cadebensNumero': data['numeroBeneficio'] ?? '',
      'cadebensSituacao': data['situacao'] ?? '',
      'status': data['status'] ?? 'ATIVO',
      'criadoEm': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> atendimentoFromCadbens(Map<String, dynamic> data) {
    return <String, dynamic>{
      'pacienteNome': data['pacienteNome'] ?? '',
      'cpf': data['cpf'] ?? '',
      'telefone': data['telefone'] ?? '',
      'celular': data['celular'] ?? '',
      'email': data['email'] ?? '',
      'nomeMae': data['nomeMae'] ?? '',
      'nomePai': data['nomePai'] ?? '',
      'cep': data['cep'] ?? '',
      'endereco': data['endereco'] ?? '',
      'bairro': data['bairro'] ?? '',
      'cidade': data['cidade'] ?? '',
      'uf': data['uf'] ?? '',
      'peso': data['peso'] ?? '',
      'altura': data['altura'] ?? '',
      'matriculaEmpregado': data['matricula'] ?? '',
      'convenio': 'FUSEx',
      'cadebensNumero': data['numeroBeneficio'] ?? '',
      'cadebensSituacao': data['situacao'] ?? '',
    };
  }

  Map<String, dynamic> _cadbensMap(Map<String, String> raw) {
    final String now = DateTime.now().toIso8601String();
    final String cpf = _digits(_pick(raw, <String>['cpf', 'nr_cpf']));
    final String beneficio = _pick(raw, <String>[
      'numero_beneficio',
      'beneficio',
      'cadbens',
      'cadebens',
      'numero'
    ]);

    return <String, dynamic>{
      'id':
          'CADBENS-${cpf.isNotEmpty ? cpf : DateTime.now().microsecondsSinceEpoch}',
      'pacienteId': '',
      'pacienteNome': _pick(raw, <String>['nome', 'paciente', 'beneficiario']),
      'cpf': cpf,
      'numeroBeneficio': beneficio,
      'matricula': _pick(raw, <String>['matricula', 'identidade']),
      'categoria': _pick(raw, <String>['categoria', 'tipo', 'dependencia']),
      'situacao': _pick(raw, <String>['situacao', 'status']) == ''
          ? 'ATIVO'
          : _pick(raw, <String>['situacao', 'status']),
      'dataConsulta': now,
      'origem': 'IMPORTACAO_CSV',
      'retorno': '',
      'status': _pick(raw, <String>['situacao', 'status']) == ''
          ? 'ATIVO'
          : _pick(raw, <String>['situacao', 'status']),
      'nascimento': _pick(raw, <String>['nascimento', 'data_nascimento']),
      'sexo': _pick(raw, <String>['sexo']),
      'cns': _pick(raw, <String>['cns']),
      'preccp': _pick(raw, <String>['preccp', 'prec_cp']),
      'telefone': _pick(raw, <String>['telefone', 'fone']),
      'celular': _pick(raw, <String>['celular']),
      'email': _pick(raw, <String>['email', 'e_mail']),
      'endereco': _pick(raw, <String>['endereco', 'logradouro']),
      'cep': _digits(_pick(raw, <String>['cep'])),
      'bairro': _pick(raw, <String>['bairro']),
      'cidade': _pick(raw, <String>['cidade', 'municipio']),
      'uf': _pick(raw, <String>['uf']),
      'nomeMae': _pick(raw, <String>['nome_mae', 'mae']),
      'nomePai': _pick(raw, <String>['nome_pai', 'pai']),
      'peso': _pick(raw, <String>['peso']),
      'altura': _pick(raw, <String>['altura']),
      'criadoEm': now,
      'atualizadoEm': now,
    };
  }

  String _pick(Map<String, String> raw, List<String> keys) {
    for (final String key in keys) {
      final String value = raw[_normalizeHeader(key)] ?? '';
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  List<String> _split(String line, String separator) {
    final List<String> result = <String>[];
    final StringBuffer current = StringBuffer();
    bool quoted = false;

    for (int i = 0; i < line.length; i++) {
      final String char = line[i];
      if (char == '"') {
        quoted = !quoted;
        continue;
      }
      if (char == separator && !quoted) {
        result.add(current.toString());
        current.clear();
        continue;
      }
      current.write(char);
    }

    result.add(current.toString());
    return result;
  }

  String _normalizeHeader(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll('/', '_')
        .replaceAll('ç', 'c')
        .replaceAll('ã', 'a')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u');
  }

  String _digits(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
