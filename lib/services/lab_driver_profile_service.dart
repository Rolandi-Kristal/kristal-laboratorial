import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audit_service.dart';
import 'lab_repository.dart';

class LabDriverProfile {
  final String id;
  final String nome;
  final String fabricante;
  final String modelo;
  final String protocolo;
  final String pastaRelativa;
  final String executavelConfiguracao;
  final String arquivoDriver;
  final String arquivoConfig;
  final String observacao;

  const LabDriverProfile({
    required this.id,
    required this.nome,
    required this.fabricante,
    required this.modelo,
    required this.protocolo,
    required this.pastaRelativa,
    this.executavelConfiguracao = '',
    this.arquivoDriver = '',
    this.arquivoConfig = '',
    this.observacao = '',
  });

  Map<String, dynamic> toEquipmentMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'fabricante': fabricante,
      'modelo': modelo,
      'protocolo': protocolo,
      'conexao': 'Serial/TCP/Arquivo',
      'porta': '',
      'ip': '',
      'baudRate': '',
      'ativo': '0',
      'criadoEm': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toDriverMap({
    required String rootPath,
  }) {
    return <String, dynamic>{
      'id': 'DRV-$id',
      'equipamentoId': id,
      'nome': nome,
      'modelo': modelo,
      'protocolo': protocolo,
      'rootPath': rootPath,
      'pastaRelativa': pastaRelativa,
      'executavelConfiguracao': executavelConfiguracao,
      'arquivoDriver': arquivoDriver,
      'arquivoConfig': arquivoConfig,
      'observacao': observacao,
      'status': 'PENDENTE_HOMOLOGACAO',
      'criadoEm': DateTime.now().toIso8601String(),
    };
  }
}

class LabDriverProfileService {
  LabDriverProfileService._();

  static final LabDriverProfileService instance = LabDriverProfileService._();

  final LabRepository _repo = LabRepository();

  List<LabDriverProfile> perfisOficiais() {
    return const <LabDriverProfile>[
      LabDriverProfile(
        id: 'EQ-AUDMAX',
        nome: 'Audmax',
        fabricante: 'KRISTAL LABORATORIAL',
        modelo: 'Audmax',
        protocolo: 'ASTM/Arquivo',
        pastaRelativa: r'Interface Avanced\Audmax',
        executavelConfiguracao: 'Audmax_1.1.1.06.exe',
        arquivoDriver: 'Audmax.drv',
        observacao:
            'Pasta observada com Audmax.drv, executáveis de versão e logs de erro.',
      ),
      LabDriverProfile(
        id: 'EQ-AUDLYTE',
        nome: 'AUDLYTE',
        fabricante: 'KRISTAL LABORATORIAL',
        modelo: 'AUDLYTE',
        protocolo: 'Arquivo/OLD',
        pastaRelativa: r'Interface Avanced\AUDLYTE',
        arquivoDriver: 'audlyte.old',
        observacao: 'Pasta observada com arquivo audlyte.old e subpasta Dados.',
      ),
      LabDriverProfile(
        id: 'EQ-BC5380',
        nome: 'BC5380',
        fabricante: 'KRISTAL LABORATORIAL',
        modelo: 'BC5380',
        protocolo: 'ASTM/Serial/TCP',
        pastaRelativa: r'Interface Avanced\BC5380',
        observacao:
            'Perfil criado para pasta BC5380 observada na Interface Avanced.',
      ),
      LabDriverProfile(
        id: 'EQ-BH5390',
        nome: 'BH-5390',
        fabricante: 'KRISTAL LABORATORIAL',
        modelo: 'BH-5390',
        protocolo: 'ASTM/Arquivo',
        pastaRelativa: r'Interface Avanced\BH-5390',
        arquivoDriver: 'BH5390.drv',
        observacao:
            'Pasta observada com BH5390.drv e múltiplos logs Erros_*.log.',
      ),
      LabDriverProfile(
        id: 'EQ-BS360E',
        nome: 'BS360E',
        fabricante: 'KRISTAL LABORATORIAL',
        modelo: 'BS360E',
        protocolo: 'ASTM/Arquivo',
        pastaRelativa: r'Interface Avanced\BS360E',
        executavelConfiguracao: 'BS360E_ASTM_1.1.0.0.exe',
        arquivoDriver: 'BS360E_ASTM.drv',
        observacao:
            'Pasta observada com BS360E_ASTM.drv, executável ASTM e logs.',
      ),
      LabDriverProfile(
        id: 'EQ-COAGMASTER',
        nome: 'Coagmaster',
        fabricante: 'KRISTAL LABORATORIAL',
        modelo: 'Coagmaster',
        protocolo: 'ASTM/CSV',
        pastaRelativa: r'Interface Avanced\Coagmaster',
        observacao:
            'Perfil criado para pasta Coagmaster observada na Interface.',
      ),
      LabDriverProfile(
        id: 'EQ-LABMAXPREMIUM',
        nome: 'Labmax Premium',
        fabricante: 'KRISTAL LABORATORIAL',
        modelo: 'LabmaxPremium',
        protocolo: 'ASTM/CSV',
        pastaRelativa: r'Interface Avanced\LabmaxPremium',
        observacao:
            'Perfil criado para pasta LabmaxPremium observada na Interface.',
      ),
      LabDriverProfile(
        id: 'EQ-URIVISION720',
        nome: 'Urivision 720',
        fabricante: 'KRISTAL LABORATORIAL',
        modelo: 'Urivision720',
        protocolo: 'CSV/ASTM',
        pastaRelativa: r'Interface Avanced\Urivision720',
        observacao:
            'Perfil criado para pasta Urivision720 observada na Interface.',
      ),
      LabDriverProfile(
        id: 'EQ-KRISTAL-ADVANCED',
        nome: 'KRISTAL Advanced',
        fabricante: 'KRISTAL',
        modelo: 'KRISTAL Advanced',
        protocolo: 'DLL/Arquivo/SQL',
        pastaRelativa: r'KRISTAL Advanced',
        executavelConfiguracao: 'IngConfig.exe',
        arquivoDriver: 'KRISTAL.ADV',
        arquivoConfig: 'DB.cfg',
        observacao:
            'Pasta observada com Interface, DB.cfg, IngConfig.exe, DLLs, SQL, Scripts e módulos auxiliares.',
      ),
      LabDriverProfile(
        id: 'EQ-HYPERTERMINAL',
        nome: 'Hyper Terminal',
        fabricante: 'Windows/Comunicação serial',
        modelo: 'Hyper Terminal',
        protocolo: 'Serial/COM',
        pastaRelativa: r'HYPER TERMINAL',
        executavelConfiguracao: 'hypertrm.exe',
        arquivoDriver: 'hypertrm.dll',
        arquivoConfig: 'HyperTerminal.rar',
        observacao: 'Ferramenta auxiliar para teste de comunicação serial/COM.',
      ),
      LabDriverProfile(
        id: 'EQ-MOSCHIP-USB-SERIAL',
        nome: 'Driver USB Serial MOSCHIP',
        fabricante: 'MosChip',
        modelo: '2S-PCI-E-MCS99x Windows 64bits',
        protocolo: 'Driver Windows 64bits',
        pastaRelativa:
            r'2S-PCI-E-MCS99x_Windows_driver_v3.0.0_WHCK_Binary\Windows 64bits',
        executavelConfiguracao: 'StnSetup.exe',
        arquivoDriver: 'StnPorts.inf',
        arquivoConfig: 'readme.txt',
        observacao:
            'Driver de porta serial/PCIe/USB observado com StnSetup.exe e arquivos INF.',
      ),
    ];
  }

  Future<String> defaultDriversRootPath() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory dir =
        Directory(p.join(support.path, 'drivers_laboratoriais'));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir.path;
  }

  Future<void> instalarPerfis({
    required String rootPath,
    String usuario = 'SISTEMA',
  }) async {
    for (final LabDriverProfile profile in perfisOficiais()) {
      await _repo.upsert('equipamentos', profile.toEquipmentMap());
      await _repo.upsert(
        'drivers_equipamentos',
        profile.toDriverMap(rootPath: rootPath),
      );
    }

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'INSTALAR_PERFIS_DRIVERS',
      tabela: 'drivers_equipamentos',
      registroId: rootPath,
      detalhes: 'Perfis de drivers laboratoriais cadastrados.',
    );
  }

  Future<List<Map<String, dynamic>>> listarDrivers() {
    return _repo.all('drivers_equipamentos', orderBy: 'nome ASC');
  }

  Future<Map<String, dynamic>> verificarDriver(
      Map<String, dynamic> driver) async {
    final String root = driver['rootPath']?.toString() ?? '';
    final String relative = driver['pastaRelativa']?.toString() ?? '';
    final String driverFile = driver['arquivoDriver']?.toString() ?? '';
    final String configExe = driver['executavelConfiguracao']?.toString() ?? '';

    final Directory folder = Directory(p.join(root, relative));
    final bool folderExists = await folder.exists();

    final bool driverExists = driverFile.isEmpty
        ? false
        : await File(p.join(folder.path, driverFile)).exists();

    final bool exeExists = configExe.isEmpty
        ? false
        : await File(p.join(folder.path, configExe)).exists();

    return <String, dynamic>{
      ...driver,
      'pastaExiste': folderExists ? 'SIM' : 'NÃO',
      'driverExiste':
          driverFile.isEmpty ? 'NÃO INFORMADO' : (driverExists ? 'SIM' : 'NÃO'),
      'configuradorExiste':
          configExe.isEmpty ? 'NÃO INFORMADO' : (exeExists ? 'SIM' : 'NÃO'),
      'pastaCompleta': folder.path,
    };
  }

  Future<List<Map<String, dynamic>>> verificarTodos() async {
    final List<Map<String, dynamic>> rows = await listarDrivers();
    final List<Map<String, dynamic>> checked = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> row in rows) {
      checked.add(await verificarDriver(row));
    }

    return checked;
  }
}
