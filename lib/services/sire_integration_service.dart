import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/app_constants.dart';
import 'kristal_sire_launcher_service.dart';

class SireBillingItem {
  const SireBillingItem({
    required this.patientCode,
    required this.patientName,
    required this.orderCode,
    required this.examCode,
    required this.examName,
    required this.sireCode,
    required this.quantity,
    required this.performedAt,
    this.codigoCbhpm = '',
    this.codigoSubGrupoCbhpm = '',
    this.valorUnitario = 0,
    this.authorizationNumber = '',
  });

  final String patientCode;
  final String patientName;
  final String orderCode;
  final String examCode;
  final String examName;
  final String sireCode;
  final int quantity;
  final DateTime performedAt;
  final String codigoCbhpm;
  final String codigoSubGrupoCbhpm;
  final double valorUnitario;
  final String authorizationNumber;

  List<String> toCsvRow() {
    return <String>[
      patientCode,
      patientName,
      orderCode,
      examCode,
      examName,
      sireCode,
      quantity.toString(),
      _date(performedAt),
      authorizationNumber,
      'KRISTAL_SIRE',
    ];
  }

  String toTxtLine() {
    return <String>[
      patientCode,
      orderCode,
      examCode,
      sireCode,
      quantity.toString().padLeft(3, '0'),
      _date(performedAt),
      authorizationNumber,
      'KRISTAL_SIRE',
    ].join('|');
  }

  Map<String, dynamic> toSireProcedureJson({
    required String fallbackSubGrupoCbhpm,
    required double fallbackValorUnitario,
  }) {
    final String cbhpm =
        codigoCbhpm.trim().isNotEmpty ? codigoCbhpm.trim() : sireCode.trim();
    final String subGrupo = codigoSubGrupoCbhpm.trim().isNotEmpty
        ? codigoSubGrupoCbhpm.trim()
        : fallbackSubGrupoCbhpm.trim();
    final double valor =
        valorUnitario > 0 ? valorUnitario : fallbackValorUnitario;

    if (cbhpm.isEmpty) {
      throw StateError('Código CBHPM/SIRE ausente para o exame $examCode.');
    }
    if (subGrupo.isEmpty) {
      throw StateError(
          'Código do SubGrupo CBHPM obrigatório para o exame $examCode.');
    }
    if (valor <= 0) {
      throw StateError('Valor unitário obrigatório para o exame $examCode.');
    }
    if (quantity <= 0) {
      throw StateError('Quantidade obrigatória para o exame $examCode.');
    }

    return <String, dynamic>{
      'Codigo_CBHPM': int.tryParse(cbhpm) ?? cbhpm,
      'Codigo_SubGrupoCBHMP': int.tryParse(subGrupo) ?? subGrupo,
      'ValorUnitario': valor,
      'Quantidade': quantity,
    };
  }

  static String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year.toString().padLeft(4, '0')}';
  }
}

class SirePlanoInterno {
  const SirePlanoInterno({
    required this.id,
    required this.sigla,
    required this.descricao,
    required this.saldo,
  });

  final String id;
  final String sigla;
  final String descricao;
  final double saldo;

  factory SirePlanoInterno.fromJson(Map<String, dynamic> json) {
    return SirePlanoInterno(
      id: (json['PI_Id'] ?? '').toString(),
      sigla: (json['PI_Sigla'] ?? '').toString(),
      descricao: (json['PI_Descricao'] ?? '').toString(),
      saldo: double.tryParse((json['Saldo'] ?? '0').toString()) ?? 0,
    );
  }
}

class SireBeneficiarioResult {
  const SireBeneficiarioResult({
    required this.beneficiarioId,
    required this.planosInternos,
    required this.raw,
  });

  final String beneficiarioId;
  final List<SirePlanoInterno> planosInternos;
  final Map<String, dynamic> raw;

  factory SireBeneficiarioResult.fromJson(Map<String, dynamic> json) {
    final Object? lista = json['Lista_PI'];
    return SireBeneficiarioResult(
      beneficiarioId: (json['BeneficiarioId'] ?? '').toString(),
      planosInternos: lista is List
          ? lista
              .whereType<Map>()
              .map((Map item) => SirePlanoInterno.fromJson(
                    item.map((dynamic key, dynamic value) =>
                        MapEntry<String, dynamic>(key.toString(), value)),
                  ))
              .toList(growable: false)
          : <SirePlanoInterno>[],
      raw: json,
    );
  }
}

class SirePostCdmResult {
  const SirePostCdmResult({
    required this.cdmId,
    required this.success,
    required this.message,
    required this.raw,
  });

  final String cdmId;
  final bool success;
  final String message;
  final Map<String, dynamic> raw;

  factory SirePostCdmResult.fromJson(Map<String, dynamic> json) {
    return SirePostCdmResult(
      cdmId: (json['CDMId'] ?? '').toString(),
      success: json['OutSuccess'] == true ||
          json['OutSuccess']?.toString().toLowerCase() == 'true',
      message: (json['Message'] ?? '').toString(),
      raw: json,
    );
  }
}

class SireIntegrationService {
  const SireIntegrationService({
    KristalSireLauncherService launcher = const KristalSireLauncherService(),
  }) : _launcher = launcher;

  final KristalSireLauncherService _launcher;

  static const String productionBaseUrl =
      'https://sire2025.eb.mil.br/P002_SIRE2025_BL/rest/PostCDM';
  static const String homologationBaseUrl =
      'https://hom-sire2025.sistemas.eb.mil.br/P002_SIRE2025_BL/rest/PostCDM';

  Future<SireBeneficiarioResult> getBeneficiarioByCpf({
    required String cpf,
    required String username,
    required String password,
    String baseUrl = productionBaseUrl,
  }) async {
    final String cleanCpf = cpf.replaceAll(RegExp(r'\D'), '');
    if (cleanCpf.length != 11) {
      throw ArgumentError('CPF inválido para consulta SIRE.');
    }

    final Uri uri = _sireEndpointUri(baseUrl, 'GetBeneficiarioByCPF').replace(
      queryParameters: <String, String>{'CPF': cleanCpf},
    );
    final Map<String, dynamic> json = await _getJson(
      uri: uri,
      username: username,
      password: password,
    );
    final SireBeneficiarioResult result = SireBeneficiarioResult.fromJson(json);
    if (result.beneficiarioId.isEmpty) {
      throw StateError(
          'SIRE não retornou BeneficiarioId para o CPF informado.');
    }
    return result;
  }

  Future<SirePostCdmResult> postCdm({
    required String beneficiarioId,
    required String planoInternoId,
    required int percentualDesconto,
    required List<SireBillingItem> items,
    required String username,
    required String password,
    required String fallbackSubGrupoCbhpm,
    required double fallbackValorUnitario,
    String baseUrl = productionBaseUrl,
  }) async {
    if (beneficiarioId.trim().isEmpty) {
      throw ArgumentError('BeneficiarioId obrigatório para emissão do CDM.');
    }
    if (planoInternoId.trim().isEmpty) {
      throw ArgumentError('PlanoInternoId obrigatório para emissão do CDM.');
    }
    if (percentualDesconto != 0 &&
        percentualDesconto != 20 &&
        percentualDesconto != 100) {
      throw ArgumentError('PercentualDesconto deve ser 0, 20 ou 100.');
    }
    if (items.isEmpty) {
      throw ArgumentError(
          'Informe ao menos um procedimento para emissão do CDM.');
    }

    final Uri uri = _sireEndpointUri(baseUrl, 'PostCDM').replace(
      queryParameters: <String, String>{
        'BeneficiarioId': beneficiarioId.trim(),
        'PlanoInternoId': planoInternoId.trim(),
        'PercentualDesconto': percentualDesconto.toString(),
      },
    );
    final List<Map<String, dynamic>> body = items
        .map(
          (SireBillingItem item) => item.toSireProcedureJson(
            fallbackSubGrupoCbhpm: fallbackSubGrupoCbhpm,
            fallbackValorUnitario: fallbackValorUnitario,
          ),
        )
        .toList(growable: false);

    final Map<String, dynamic> json = await _postJson(
      uri: uri,
      username: username,
      password: password,
      body: body,
    );
    return SirePostCdmResult.fromJson(json);
  }

  Future<File> exportCsv({
    required List<SireBillingItem> items,
    String directoryPath = AppConstants.kristalSireExportDirectoryPath,
  }) async {
    final Directory directory = Directory(directoryPath);
    await directory.create(recursive: true);

    final File file = File(
      p.join(directory.path, 'KRISTAL_SIRE_${_stamp()}.csv'),
    );

    final List<List<String>> rows = <List<String>>[
      <String>[
        'PacienteCodigo',
        'PacienteNome',
        'Pedido',
        'MNE',
        'Exame',
        'CodigoKRISTAL_SIRE',
        'Quantidade',
        'Data',
        'Autorizacao',
        'Origem',
      ],
      ...items.map((SireBillingItem item) => item.toCsvRow()),
    ];

    final String content = rows
        .map((List<String> row) => row.map(_csvEscape).join(';'))
        .join('\r\n');

    await file.writeAsString('$content\r\n', encoding: latin1);
    return file;
  }

  Future<File> exportTxt({
    required List<SireBillingItem> items,
    String directoryPath = AppConstants.kristalSireExportDirectoryPath,
  }) async {
    final Directory directory = Directory(directoryPath);
    await directory.create(recursive: true);

    final File file = File(
      p.join(directory.path, 'KRISTAL_SIRE_${_stamp()}.txt'),
    );

    final String content =
        items.map((SireBillingItem item) => item.toTxtLine()).join('\r\n');

    await file.writeAsString('$content\r\n', encoding: latin1);
    return file;
  }

  Future<void> openKristalSire() async {
    await _launcher.openKristalSire();
  }

  Future<void> openKristalSireExternal() async {
    await _launcher.openKristalSireExternal();
  }

  Future<void> openExportDirectory() async {
    await _launcher.openSireExportDirectory();
  }

  Future<void> openSire(String executablePath) async {
    if (executablePath.trim().isEmpty ||
        executablePath == AppConstants.kristalSireShortcutPath ||
        executablePath == AppConstants.sireExecutablePath) {
      await openKristalSire();
      return;
    }

    final File target = File(executablePath);
    if (!await target.exists()) {
      await openKristalSire();
      return;
    }

    final ProcessResult result = await Process.run(
      'cmd',
      <String>['/c', 'start', '', target.path],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw FileSystemException('Falha ao iniciar KRISTAL SIRE.', target.path);
    }
  }

  Future<void> openDirectory(String directoryPath) async {
    final Directory directory = Directory(
      directoryPath.trim().isEmpty
          ? AppConstants.kristalSireExportDirectoryPath
          : directoryPath,
    );
    await directory.create(recursive: true);
    await Process.run('explorer.exe', <String>[directory.path],
        runInShell: true);
  }

  String _csvEscape(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  String _stamp() {
    final DateTime now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Uri _sireEndpointUri(String baseUrl, String endpoint) {
    final String normalizedEndpoint =
        endpoint.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (normalizedEndpoint.isEmpty) {
      throw ArgumentError('Endpoint SIRE obrigatório.');
    }

    final Uri parsed = Uri.parse(_cleanBaseUrl(baseUrl));
    final List<String> segments = parsed.pathSegments
        .where((String segment) => segment.trim().isNotEmpty)
        .toList(growable: true);

    if (segments.isNotEmpty) {
      final String last = segments.last.toLowerCase();
      if (last == 'postcdm' || last == 'getbeneficiariobycpf') {
        segments.removeLast();
      }
    }

    segments.add(normalizedEndpoint);
    return parsed.replace(path: '/${segments.join('/')}');
  }

  String _cleanBaseUrl(String value) {
    final String cleaned = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleaned.isEmpty) {
      return productionBaseUrl;
    }
    return cleaned;
  }

  Future<Map<String, dynamic>> _getJson({
    required Uri uri,
    required String username,
    required String password,
  }) async {
    final HttpClientRequest request = await _authorizedRequest(
        method: 'GET', uri: uri, username: username, password: password);
    final HttpClientResponse response = await request.close();
    return _decodeObjectResponse(response);
  }

  Future<Map<String, dynamic>> _postJson({
    required Uri uri,
    required String username,
    required String password,
    required Object body,
  }) async {
    final HttpClientRequest request = await _authorizedRequest(
        method: 'POST', uri: uri, username: username, password: password);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final HttpClientResponse response = await request.close();
    return _decodeObjectResponse(response);
  }

  Future<HttpClientRequest> _authorizedRequest({
    required String method,
    required Uri uri,
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      throw ArgumentError('Usuário e senha do SIRE são obrigatórios.');
    }
    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    final HttpClientRequest request = await client.openUrl(method, uri);
    final String token =
        base64Encode(utf8.encode('${username.trim()}:$password'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Basic $token');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    return request;
  }

  Future<Map<String, dynamic>> _decodeObjectResponse(
    HttpClientResponse response,
  ) async {
    final String content = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'SIRE HTTP ${response.statusCode}: $content',
        uri: response.redirects.isNotEmpty
            ? response.redirects.last.location
            : null,
      );
    }
    final Object? decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value));
    }
    throw const FormatException('Resposta SIRE não é objeto JSON.');
  }
}
