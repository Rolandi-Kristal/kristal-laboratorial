import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../models/lab_exam_definition.dart';
import '../services/lab_exam_catalog_service.dart';
import '../services/sire_integration_service.dart';
import '../widgets/kristal_shell.dart';

class FinanceiroSireScreen extends StatefulWidget {
  const FinanceiroSireScreen({super.key});

  @override
  State<FinanceiroSireScreen> createState() => _FinanceiroSireScreenState();
}

class _FinanceiroSireScreenState extends State<FinanceiroSireScreen> {
  final SireIntegrationService _sireService = const SireIntegrationService();

  final TextEditingController _patientCodeController = TextEditingController();
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _orderCodeController = TextEditingController();
  final TextEditingController _exportDirectoryController =
      TextEditingController(text: r'D:\kristal_laboratorial\exports\sire');
  final TextEditingController _sirePathController =
      TextEditingController(text: AppConstants.sireExecutablePath);
  final TextEditingController _sireBaseUrlController =
      TextEditingController(text: SireIntegrationService.productionBaseUrl);
  final TextEditingController _sireUserController = TextEditingController();
  final TextEditingController _sirePasswordController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _beneficiarioIdController =
      TextEditingController();
  final TextEditingController _planoInternoIdController =
      TextEditingController();
  final TextEditingController _percentualDescontoController =
      TextEditingController(text: '20');
  final TextEditingController _subGrupoCbhpmController =
      TextEditingController();
  final TextEditingController _valorUnitarioController =
      TextEditingController();

  final Set<String> _selectedExamCodes = <String>{};
  List<LabExamDefinition> _availableExams = <LabExamDefinition>[];
  String _status = 'Pronto para comunicação com o SIRE.';

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final List<LabExamDefinition> exams =
        await LabExamCatalogService.instance.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _availableExams = exams;
    });
  }

  @override
  void dispose() {
    _patientCodeController.dispose();
    _patientNameController.dispose();
    _orderCodeController.dispose();
    _exportDirectoryController.dispose();
    _sirePathController.dispose();
    _sireBaseUrlController.dispose();
    _sireUserController.dispose();
    _sirePasswordController.dispose();
    _cpfController.dispose();
    _beneficiarioIdController.dispose();
    _planoInternoIdController.dispose();
    _percentualDescontoController.dispose();
    _subGrupoCbhpmController.dispose();
    _valorUnitarioController.dispose();
    super.dispose();
  }

  List<SireBillingItem> _buildItems() {
    return _availableExams
        .where(
            (LabExamDefinition exam) => _selectedExamCodes.contains(exam.code))
        .map(
          (LabExamDefinition exam) => SireBillingItem(
            patientCode: _patientCodeController.text.trim(),
            patientName: _patientNameController.text.trim(),
            orderCode: _orderCodeController.text.trim(),
            examCode: exam.code,
            examName: exam.name,
            sireCode: exam.sireCode,
            quantity: 1,
            performedAt: DateTime.now(),
            codigoCbhpm: exam.sireCode,
            codigoSubGrupoCbhpm: exam.sireSubgroupCode,
          ),
        )
        .toList(growable: false);
  }

  double _money(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
  }

  Future<void> _consultarCpfSire() async {
    try {
      setState(() => _status = 'Consultando beneficiário no SIRE...');
      final SireBeneficiarioResult result =
          await _sireService.getBeneficiarioByCpf(
        cpf: _cpfController.text,
        username: _sireUserController.text,
        password: _sirePasswordController.text,
        baseUrl: _sireBaseUrlController.text,
      );
      _beneficiarioIdController.text = result.beneficiarioId;
      if (result.planosInternos.isNotEmpty) {
        _planoInternoIdController.text = result.planosInternos.first.id;
      }
      setState(() {
        _status = 'Beneficiário SIRE ${result.beneficiarioId} localizado. '
            'PIs: ${result.planosInternos.map((SirePlanoInterno pi) => '${pi.id}/${pi.sigla}').join(', ')}';
      });
    } catch (error) {
      setState(() => _status = 'Erro na consulta SIRE: $error');
    }
  }

  Future<void> _enviarCdmSire() async {
    try {
      setState(() => _status = 'Enviando CDM real ao SIRE...');
      final SirePostCdmResult result = await _sireService.postCdm(
        beneficiarioId: _beneficiarioIdController.text,
        planoInternoId: _planoInternoIdController.text,
        percentualDesconto:
            int.tryParse(_percentualDescontoController.text.trim()) ?? 20,
        items: _buildItems(),
        username: _sireUserController.text,
        password: _sirePasswordController.text,
        fallbackSubGrupoCbhpm: _subGrupoCbhpmController.text,
        fallbackValorUnitario: _money(_valorUnitarioController),
        baseUrl: _sireBaseUrlController.text,
      );
      setState(() {
        _status = 'CDM SIRE retornado. ID: ${result.cdmId}. '
            'Sucesso: ${result.success}. ${result.message}';
      });
    } catch (error) {
      setState(() => _status = 'Erro ao enviar CDM ao SIRE: $error');
    }
  }

  Future<void> _exportCsv() async {
    try {
      final File file = await _sireService.exportCsv(
        items: _buildItems(),
        directoryPath: _exportDirectoryController.text.trim(),
      );
      setState(() {
        _status = 'CSV SIRE gerado: ${file.path}';
      });
    } on FileSystemException catch (error) {
      setState(() {
        _status = 'Erro ao gerar CSV: ${error.message}';
      });
    }
  }

  Future<void> _exportTxt() async {
    try {
      final File file = await _sireService.exportTxt(
        items: _buildItems(),
        directoryPath: _exportDirectoryController.text.trim(),
      );
      setState(() {
        _status = 'TXT SIRE gerado: ${file.path}';
      });
    } on FileSystemException catch (error) {
      setState(() {
        _status = 'Erro ao gerar TXT: ${error.message}';
      });
    }
  }

  Future<void> _openSire() async {
    try {
      await _sireService.openSire(_sirePathController.text.trim());
      setState(() {
        _status = 'SIRE iniciado com sucesso.';
      });
    } on FileSystemException catch (error) {
      setState(() {
        _status = 'Erro ao abrir SIRE: ${error.message} ${error.path ?? ''}';
      });
    }
  }

  Future<void> _openFolder() async {
    await _sireService.openDirectory(_exportDirectoryController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return KristalShell(
      title: 'Financeiro SIRE',
      subtitle: 'Faturamento, exportação e comunicação direta com SIRE',
      icon: Icons.account_balance_wallet,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    _field(_patientCodeController, 'Código do paciente'),
                    _field(_patientNameController, 'Nome do paciente'),
                    _field(_orderCodeController, 'Pedido / Atendimento'),
                    _field(_cpfController, 'CPF para GetBeneficiarioByCPF'),
                    _field(_sireBaseUrlController, 'Base URL REST SIRE'),
                    _field(_sireUserController, 'Usuário SIRE'),
                    _field(
                      _sirePasswordController,
                      'Senha SIRE',
                      obscureText: true,
                    ),
                    _field(_beneficiarioIdController, 'BeneficiarioId SIRE'),
                    _field(_planoInternoIdController, 'PlanoInternoId / PI_Id'),
                    _field(
                      _percentualDescontoController,
                      'PercentualDesconto (0, 20 ou 100)',
                      keyboardType: TextInputType.number,
                    ),
                    _field(
                      _subGrupoCbhpmController,
                      'Codigo_SubGrupoCBHMP',
                      keyboardType: TextInputType.number,
                    ),
                    _field(
                      _valorUnitarioController,
                      'ValorUnitario padrão',
                      keyboardType: TextInputType.number,
                    ),
                    _field(
                        _exportDirectoryController, 'Pasta de exportação SIRE'),
                    _field(_sirePathController, 'Executável SIRE'),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _consultarCpfSire,
                            icon: const Icon(Icons.search),
                            label: const Text('Consultar CPF'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _enviarCdmSire,
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text('PostCDM'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _exportCsv,
                            icon: const Icon(Icons.table_chart),
                            label: const Text('CSV'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _exportTxt,
                            icon: const Icon(Icons.description),
                            label: const Text('TXT'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _openSire,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Abrir SIRE'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _openFolder,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Abrir pasta SIRE'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _status,
                      style: const TextStyle(
                        color: Color(0xFFFFC857),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(child: _examSelector()),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFF071827),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _examSelector() {
    final List<LabExamDefinition> exams = _availableExams;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2033),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF244B6D)),
      ),
      child: ListView.separated(
        itemCount: exams.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          final LabExamDefinition exam = exams[index];
          final bool selected = _selectedExamCodes.contains(exam.code);
          return CheckboxListTile(
            value: selected,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedExamCodes.add(exam.code);
                } else {
                  _selectedExamCodes.remove(exam.code);
                }
              });
            },
            title: Text(
              '${exam.code} • ${exam.name}',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '${exam.sector} • ${exam.material} • SIRE: ${exam.sireCode}',
              style: const TextStyle(color: Color(0xFFB7D7F1)),
            ),
            activeColor: const Color(0xFF4EA3FF),
          );
        },
      ),
    );
  }
}
