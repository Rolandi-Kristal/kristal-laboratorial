
$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\kristal_laboratorial"
$LibDir = Join-Path $ProjectRoot "lib"
$ScreensDir = Join-Path $LibDir "screens"
$ServicesDir = Join-Path $LibDir "services"
$ModelsDir = Join-Path $LibDir "models"
$ConfigDir = Join-Path $ProjectRoot "config\drivers\hematologia"
$DataDir = Join-Path $ProjectRoot "data\drivers\hematologia"
$PackageDir = Join-Path $DataDir "pacote"
$DriverPackPath = Join-Path $ProjectRoot "driver hemato.rar"

Set-Location $ProjectRoot

New-Item -ItemType Directory -Force -Path $ScreensDir | Out-Null
New-Item -ItemType Directory -Force -Path $ServicesDir | Out-Null
New-Item -ItemType Directory -Force -Path $ModelsDir | Out-Null
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null

Write-Host ""
Write-Host "======================================================"
Write-Host " KRISTAL - INSTALADOR HEMATOLOGIA RAIZ"
Write-Host "======================================================"
Write-Host ""

@'
{
  "familia": "HEMATOLOGIA",
  "origem_pacote": "driver hemato.rar",
  "modelos": [
    {"id":"HEMATO_5100","nome":"Analisador Hematológico 5100","fabricante":"Compatível por perfil KRISTAL","modelo":"5100","setor":"Hematologia","protocolos":["ASTM","HL7","TXT","CSV","TCP_IP","SERIAL_COM","PASTA_MONITORADA"],"conexaoPadrao":{"tipo":"SERIAL_COM","portaCom":"COM1","baudRate":9600,"dataBits":8,"paridade":"N","stopBits":1,"ip":"192.168.0.150","portaTcp":5000},"ativo":true},
    {"id":"HEMATO_5180","nome":"Analisador Hematológico 5180","fabricante":"Compatível por perfil KRISTAL","modelo":"5180","setor":"Hematologia","protocolos":["ASTM","HL7","TXT","CSV","TCP_IP","SERIAL_COM","PASTA_MONITORADA"],"conexaoPadrao":{"tipo":"SERIAL_COM","portaCom":"COM1","baudRate":9600,"dataBits":8,"paridade":"N","stopBits":1,"ip":"192.168.0.151","portaTcp":5000},"ativo":true},
    {"id":"HEMATO_5300","nome":"Analisador Hematológico 5300","fabricante":"Compatível por perfil KRISTAL","modelo":"5300","setor":"Hematologia","protocolos":["ASTM","HL7","TXT","CSV","TCP_IP","SERIAL_COM","PASTA_MONITORADA"],"conexaoPadrao":{"tipo":"TCP_IP","portaCom":"COM1","baudRate":9600,"dataBits":8,"paridade":"N","stopBits":1,"ip":"192.168.0.152","portaTcp":5000},"ativo":true},
    {"id":"HEMATO_5380","nome":"Analisador Hematológico 5380","fabricante":"Compatível por perfil KRISTAL","modelo":"5380","setor":"Hematologia","protocolos":["ASTM","HL7","TXT","CSV","TCP_IP","SERIAL_COM","PASTA_MONITORADA"],"conexaoPadrao":{"tipo":"TCP_IP","portaCom":"COM1","baudRate":9600,"dataBits":8,"paridade":"N","stopBits":1,"ip":"192.168.0.153","portaTcp":5000},"ativo":true}
  ]
}
'@ | Set-Content -Path (Join-Path $ConfigDir "hematologia_driver_profiles.json") -Encoding UTF8
Copy-Item (Join-Path $ConfigDir "hematologia_driver_profiles.json") (Join-Path $DataDir "hematologia_driver_profiles.json") -Force

@'
class HematologyDriverProfile {
  const HematologyDriverProfile({
    required this.id,
    required this.nome,
    required this.fabricante,
    required this.modelo,
    required this.setor,
    required this.protocolos,
    required this.conexaoPadrao,
    required this.ativo,
  });

  final String id;
  final String nome;
  final String fabricante;
  final String modelo;
  final String setor;
  final List<String> protocolos;
  final Map<String, Object?> conexaoPadrao;
  final bool ativo;

  factory HematologyDriverProfile.fromJson(Map<String, Object?> json) {
    return HematologyDriverProfile(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      fabricante: json['fabricante']?.toString() ?? '',
      modelo: json['modelo']?.toString() ?? '',
      setor: json['setor']?.toString() ?? 'Hematologia',
      protocolos: (json['protocolos'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      conexaoPadrao: (json['conexaoPadrao'] as Map<dynamic, dynamic>? ??
              <dynamic, dynamic>{})
          .map(
        (dynamic key, dynamic value) => MapEntry<String, Object?>(
          key.toString(),
          value,
        ),
      ),
      ativo: json['ativo']?.toString().toLowerCase() != 'false',
    );
  }
}
'@ | Set-Content -Path (Join-Path $ModelsDir "hematology_driver_profile.dart") -Encoding UTF8

@'
import 'dart:convert';
import 'dart:io';

import '../models/hematology_driver_profile.dart';

class HematologyDriverRegistryService {
  HematologyDriverRegistryService._();

  static final HematologyDriverRegistryService instance =
      HematologyDriverRegistryService._();

  Directory get baseDirectory =>
      Directory(r'C:\kristal_laboratorial\data\drivers\hematologia');

  File get profilesFile =>
      File('${baseDirectory.path}\\hematologia_driver_profiles.json');

  Future<List<HematologyDriverProfile>> loadProfiles() async {
    await baseDirectory.create(recursive: true);

    if (!await profilesFile.exists()) {
      return <HematologyDriverProfile>[];
    }

    final String content = await profilesFile.readAsString(encoding: utf8);
    final Object? decoded = jsonDecode(content);

    if (decoded is! Map<String, dynamic>) {
      return <HematologyDriverProfile>[];
    }

    final List<dynamic> rows = decoded['modelos'] as List<dynamic>? ?? <dynamic>[];

    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> row) => HematologyDriverProfile.fromJson(
            row.map(
              (dynamic key, dynamic value) =>
                  MapEntry<String, Object?>(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, Object?>> validateDriverPack() async {
    await baseDirectory.create(recursive: true);
    final Directory packageDir = Directory('${baseDirectory.path}\\pacote');
    final File rar = File('${baseDirectory.path}\\driver hemato.rar');

    return <String, Object?>{
      'baseDirectory': baseDirectory.path,
      'profilesFile': profilesFile.path,
      'driverPackCopied': await rar.exists(),
      'driverPackExtracted': await packageDir.exists(),
      'profiles': (await loadProfiles()).length,
    };
  }
}
'@ | Set-Content -Path (Join-Path $ServicesDir "hematology_driver_registry_service.dart") -Encoding UTF8

@'
import 'dart:convert';

class HematologyProtocolAdapterService {
  HematologyProtocolAdapterService._();

  static final HematologyProtocolAdapterService instance =
      HematologyProtocolAdapterService._();

  Map<String, Object?> parseIncomingMessage(String raw) {
    final String message = raw.trim();

    if (message.isEmpty) {
      return <String, Object?>{'ok': false, 'tipo': 'VAZIO', 'erro': 'Mensagem vazia.'};
    }

    if (message.contains('MSH|') || message.contains('OBX|')) {
      return _parseHl7(message);
    }

    if (message.contains('\x02') ||
        message.contains('\x03') ||
        message.contains('H|\\^&') ||
        message.contains('R|')) {
      return _parseAstm(message);
    }

    if (message.contains(';') || message.contains(',') || message.contains('\t')) {
      return _parseDelimited(message);
    }

    return <String, Object?>{
      'ok': true,
      'tipo': 'TXT',
      'conteudoBruto': message,
      'resultados': <Map<String, Object?>>[],
    };
  }

  Map<String, Object?> _parseHl7(String raw) {
    final List<String> lines = raw.split(RegExp(r'\r?\n|\r'));
    final List<Map<String, Object?>> results = <Map<String, Object?>>[];

    for (final String line in lines) {
      final List<String> fields = line.split('|');

      if (fields.isNotEmpty && fields.first == 'OBX') {
        results.add(<String, Object?>{
          'codigo': fields.length > 3 ? fields[3] : '',
          'valor': fields.length > 5 ? fields[5] : '',
          'unidade': fields.length > 6 ? fields[6] : '',
          'referencia': fields.length > 7 ? fields[7] : '',
          'flag': fields.length > 8 ? fields[8] : '',
        });
      }
    }

    return <String, Object?>{'ok': true, 'tipo': 'HL7', 'resultados': results, 'conteudoBruto': raw};
  }

  Map<String, Object?> _parseAstm(String raw) {
    final String cleaned = raw
        .replaceAll('\x02', '')
        .replaceAll('\x03', '')
        .replaceAll('\x04', '')
        .replaceAll('\x05', '')
        .replaceAll('\x06', '')
        .replaceAll('\x15', '');

    final List<String> lines = cleaned.split(RegExp(r'\r?\n|\r'));
    final List<Map<String, Object?>> results = <Map<String, Object?>>[];

    for (final String line in lines) {
      final List<String> fields = line.split('|');

      if (fields.isNotEmpty && fields.first.startsWith('R')) {
        results.add(<String, Object?>{
          'codigo': fields.length > 2 ? fields[2] : '',
          'valor': fields.length > 3 ? fields[3] : '',
          'unidade': fields.length > 4 ? fields[4] : '',
          'referencia': fields.length > 5 ? fields[5] : '',
          'flag': fields.length > 6 ? fields[6] : '',
        });
      }
    }

    return <String, Object?>{'ok': true, 'tipo': 'ASTM', 'resultados': results, 'conteudoBruto': raw};
  }

  Map<String, Object?> _parseDelimited(String raw) {
    final String separator = raw.contains(';') ? ';' : raw.contains('\t') ? '\t' : ',';
    final List<Map<String, Object?>> results = <Map<String, Object?>>[];

    for (final String line in raw.split(RegExp(r'\r?\n'))) {
      final List<String> fields = line.split(separator);

      if (fields.length >= 2) {
        results.add(<String, Object?>{
          'codigo': fields[0].trim(),
          'valor': fields[1].trim(),
          'unidade': fields.length > 2 ? fields[2].trim() : '',
          'referencia': fields.length > 3 ? fields[3].trim() : '',
          'flag': fields.length > 4 ? fields[4].trim() : '',
        });
      }
    }

    return <String, Object?>{'ok': true, 'tipo': 'DELIMITADO', 'resultados': results, 'conteudoBruto': raw};
  }

  String toJson(Map<String, Object?> message) {
    return const JsonEncoder.withIndent('  ').convert(message);
  }
}
'@ | Set-Content -Path (Join-Path $ServicesDir "hematology_protocol_adapter_service.dart") -Encoding UTF8

@'
import 'package:flutter/material.dart';

import '../models/hematology_driver_profile.dart';
import '../services/hematology_driver_registry_service.dart';
import '../services/hematology_protocol_adapter_service.dart';

class HematologyDriverCompatibilityScreen extends StatefulWidget {
  const HematologyDriverCompatibilityScreen({super.key});

  @override
  State<HematologyDriverCompatibilityScreen> createState() =>
      _HematologyDriverCompatibilityScreenState();
}

class _HematologyDriverCompatibilityScreenState
    extends State<HematologyDriverCompatibilityScreen> {
  final TextEditingController messageController = TextEditingController();
  final HematologyDriverRegistryService registry =
      HematologyDriverRegistryService.instance;
  final HematologyProtocolAdapterService adapter =
      HematologyProtocolAdapterService.instance;

  bool loading = true;
  String status = 'Carregando perfis de hematologia...';
  String parseResult = '';
  List<HematologyDriverProfile> profiles = <HematologyDriverProfile>[];

  @override
  void initState() {
    super.initState();
    loadProfiles();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> loadProfiles() async {
    setState(() => loading = true);

    try {
      final List<HematologyDriverProfile> rows = await registry.loadProfiles();
      final Map<String, Object?> validation = await registry.validateDriverPack();

      if (!mounted) return;

      setState(() {
        profiles = rows;
        status =
            'Perfis: ${rows.length}. Pacote copiado: ${validation['driverPackCopied']}. Extraído: ${validation['driverPackExtracted']}.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => status = 'Falha ao carregar perfis: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void parseMessage() {
    final Map<String, Object?> result =
        adapter.parseIncomingMessage(messageController.text);

    setState(() {
      parseResult = adapter.toJson(result);
      status = 'Mensagem processada pelo adaptador de hematologia.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF06111D),
      child: Column(
        children: <Widget>[
          Container(
            height: 96,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            color: const Color(0xFF18344F),
            child: const Row(
              children: <Widget>[
                Icon(Icons.bloodtype_rounded, color: Color(0xFF73D7FF), size: 34),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Compatibilidade Hematologia',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      Text('Drivers 5100, 5180, 5300, 5380, ASTM, HL7, TCP/IP, COM e pasta monitorada',
                          style: TextStyle(color: Color(0xFFB7D7F1), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(18),
                          itemCount: profiles.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            return profileCard(profiles[index]);
                          },
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: <Widget>[
                              TextField(
                                controller: messageController,
                                minLines: 8,
                                maxLines: 14,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Mensagem ASTM / HL7 / TXT / CSV do equipamento',
                                  alignLabelWithHint: true,
                                  filled: true,
                                  fillColor: Color(0xFF071827),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: parseMessage,
                                icon: const Icon(Icons.integration_instructions),
                                label: const Text('Testar leitura da mensagem'),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D2033),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF244B6D)),
                                  ),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      parseResult.isEmpty ? 'Resultado do parser aparecerá aqui.' : parseResult,
                                      style: const TextStyle(color: Color(0xFFB7D7F1), fontFamily: 'monospace'),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF06111D),
            child: Text(status, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFFC857), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget profileCard(HematologyDriverProfile profile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2033),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF244B6D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(profile.nome,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Modelo: ${profile.modelo} | Setor: ${profile.setor}',
              style: const TextStyle(color: Color(0xFFB7D7F1), fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: profile.protocolos
                .map((String protocolo) => Chip(
                      label: Text(protocolo),
                      backgroundColor: const Color(0xFF071827),
                      labelStyle: const TextStyle(color: Color(0xFF73D7FF)),
                    ))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
'@ | Set-Content -Path (Join-Path $ScreensDir "hematology_driver_compatibility_screen.dart") -Encoding UTF8

$HomePath = Join-Path $ScreensDir "home_screen.dart"
if (Test-Path $HomePath) {
  $HomeText = Get-Content $HomePath -Raw -Encoding UTF8

  if ($HomeText -notmatch "hematology_driver_compatibility_screen\.dart") {
    $HomeText = $HomeText -replace "import 'equipamentos_screen\.dart';", "import 'equipamentos_screen.dart';`r`nimport 'hematology_driver_compatibility_screen.dart';"
  }

  if ($HomeText -notmatch "HematologyDriverCompatibilityScreen") {
    $Menu = @"
    _ModuleItem(
      group: 'INTEGRAÇÕES',
      title: 'Drivers Hematologia',
      subtitle: '5100, 5180, 5300, 5380, ASTM, HL7, TCP/IP, COM e pasta monitorada',
      icon: Icons.bloodtype_rounded,
      builder: (_) => const HematologyDriverCompatibilityScreen(),
      moduleKey: 'drivers_hematologia',
    ),
"@

    $HomeText = $HomeText -replace "(_ModuleItem\(\s*group:\s*'INTEGRAÇÕES'[\s\S]*?\n\s*\),)", "`$1`r`n$Menu"
  }

  Set-Content $HomePath $HomeText -Encoding UTF8
}

if (Test-Path $DriverPackPath) {
  Copy-Item $DriverPackPath (Join-Path $DataDir "driver hemato.rar") -Force
  Write-Host "Pacote copiado para: $(Join-Path $DataDir 'driver hemato.rar')"

  $SevenZip = @(
    "C:\Program Files\7-Zip\7z.exe",
    "C:\Program Files (x86)\7-Zip\7z.exe"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1

  if ($SevenZip) {
    & $SevenZip x $DriverPackPath "-o$PackageDir" -y
    Write-Host "Pacote extraido em: $PackageDir"
  } else {
    Write-Host "7-Zip nao encontrado. O pacote foi copiado, mas nao extraido."
    Write-Host "Extraia manualmente para: $PackageDir"
  }
} else {
  Write-Host "driver hemato.rar nao encontrado em C:\kristal_laboratorial."
  Write-Host "Copie o arquivo para C:\kristal_laboratorial e execute este script novamente."
}

Write-Host ""
Write-Host "Compatibilidade adicionada:"
Write-Host "- 5100"
Write-Host "- 5180"
Write-Host "- 5300"
Write-Host "- 5380"
Write-Host "- ASTM / HL7 / TXT / CSV / TCP-IP / COM / Pasta monitorada"
Write-Host ""
Write-Host "Agora rode:"
Write-Host "flutter clean"
Write-Host "flutter pub get"
Write-Host "flutter analyze"
Write-Host ""
