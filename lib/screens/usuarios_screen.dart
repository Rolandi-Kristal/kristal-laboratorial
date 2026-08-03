import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../models/kristal_operational_record.dart';
import '../models/professional_signature_model.dart';
import '../models/technical_responsible_model.dart';
import '../services/kristal_operational_store_service.dart';
import '../services/professional_signature_service.dart';
import '../services/technical_responsible_service.dart';
import '../widgets/military_rank_dropdown.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  static const String _module = 'usuarios';

  final KristalOperationalStoreService _store =
      KristalOperationalStoreService.instance;
  final ProfessionalSignatureService _signatureService =
      ProfessionalSignatureService.instance;
  final TechnicalResponsibleService _technicalService =
      TechnicalResponsibleService.instance;

  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _userController = TextEditingController();

  final TextEditingController _professionalNameController =
      TextEditingController();
  final TextEditingController _professionalRankController =
      TextEditingController();
  final TextEditingController _professionalSpecialtyController =
      TextEditingController();
  final TextEditingController _professionalCouncilController =
      TextEditingController();
  final TextEditingController _professionalCouncilNumberController =
      TextEditingController();
  final TextEditingController _signaturePathController =
      TextEditingController();

  final TextEditingController _technicalNameController =
      TextEditingController();
  final TextEditingController _technicalRankController =
      TextEditingController();
  final TextEditingController _technicalSpecialtyController =
      TextEditingController();
  final TextEditingController _technicalCouncilController =
      TextEditingController();
  final TextEditingController _technicalCouncilNumberController =
      TextEditingController();

  final List<String> _profiles = const <String>[
    'SUPER_USUARIO',
    'ADMINISTRADOR',
    'RESPONSAVEL_TECNICO',
    'BIOQUIMICO',
    'FARMACEUTICO',
    'BIOMEDICO',
    'MEDICO',
    'ENFERMAGEM',
    'TECNICO_LABORATORIO',
    'RECEPCAO',
    'COLETA',
    'FATURAMENTO_SIRE',
    'AUDITORIA',
    'CONSULTA',
  ];

  final List<String> _statuses = const <String>[
    'ATIVO',
    'INATIVO',
    'BLOQUEADO',
    'SUSPENSO',
    'AGUARDANDO_LIBERACAO',
  ];

  String _selectedProfile = 'CONSULTA';
  String _selectedStatus = 'ATIVO';

  bool _loading = true;
  String _status = 'Carregando usuários...';

  List<KristalOperationalRecord> _records = <KristalOperationalRecord>[];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _userController.dispose();
    _professionalNameController.dispose();
    _professionalRankController.dispose();
    _professionalSpecialtyController.dispose();
    _professionalCouncilController.dispose();
    _professionalCouncilNumberController.dispose();
    _signaturePathController.dispose();
    _technicalNameController.dispose();
    _technicalRankController.dispose();
    _technicalSpecialtyController.dispose();
    _technicalCouncilController.dispose();
    _technicalCouncilNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
    });

    try {
      final List<KristalOperationalRecord> records = await _store.load(_module);
      final ProfessionalSignatureModel signature =
          await _signatureService.load();
      final TechnicalResponsibleModel technical =
          await _technicalService.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _records = records;
        _professionalNameController.text = signature.professionalName;
        _professionalRankController.text = signature.rankOrGrade;
        _professionalSpecialtyController.text = signature.specialty;
        _professionalCouncilController.text = signature.council;
        _professionalCouncilNumberController.text = signature.councilNumber;
        _signaturePathController.text = signature.signatureImagePath;

        _technicalNameController.text = technical.name;
        _technicalRankController.text = technical.rankOrGrade;
        _technicalSpecialtyController.text = technical.specialty;
        _technicalCouncilController.text = technical.council;
        _technicalCouncilNumberController.text = technical.councilNumber;

        _status = 'Dados carregados com sucesso.';
      });
    } on FileSystemException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Erro de arquivo: ${error.message}';
      });
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Dados inválidos: ${error.message}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveUser() async {
    final String name = _nameController.text.trim();
    final String username = _userController.text.trim();

    if (name.isEmpty || username.isEmpty) {
      setState(() {
        _status = 'Informe nome e usuário.';
      });
      return;
    }

    await _store.create(
      module: _module,
      data: <String, String>{
        'nome': name,
        'usuario': username,
        'perfil': _selectedProfile,
        'status': _selectedStatus,
      },
    );

    _nameController.clear();
    _userController.clear();
    _selectedProfile = 'CONSULTA';
    _selectedStatus = 'ATIVO';

    await _loadAll();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Usuário salvo com retenção permanente.';
    });
  }

  Future<void> _archiveUser(String id) async {
    await _store.archive(
      module: _module,
      id: id,
      reason: 'Registro preservado permanentemente para consulta histórica.',
    );

    await _loadAll();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Usuário arquivado sem exclusão física.';
    });
  }

  Future<void> _saveProfessionalSignature() async {
    final String professionalName = _professionalNameController.text.trim();

    if (professionalName.isEmpty) {
      setState(() {
        _status = 'Informe o nome do profissional da assinatura.';
      });
      return;
    }

    final ProfessionalSignatureModel model = ProfessionalSignatureModel(
      professionalName: professionalName,
      rankOrGrade: _professionalRankController.text.trim(),
      specialty: _professionalSpecialtyController.text.trim(),
      council: _professionalCouncilController.text.trim(),
      councilNumber: _professionalCouncilNumberController.text.trim(),
      signatureImagePath: _signaturePathController.text.trim(),
      updatedAt: DateTime.now(),
    );

    await _signatureService.save(model);

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Assinatura profissional salva para emissão de laudos.';
    });
  }

  Future<void> _saveTechnicalResponsible() async {
    final String name = _technicalNameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _status = 'Informe o nome do responsável técnico.';
      });
      return;
    }

    final TechnicalResponsibleModel model = TechnicalResponsibleModel(
      name: name,
      rankOrGrade: _technicalRankController.text.trim(),
      specialty: _technicalSpecialtyController.text.trim(),
      council: _technicalCouncilController.text.trim(),
      councilNumber: _technicalCouncilNumberController.text.trim(),
      updatedAt: DateTime.now(),
    );

    await _technicalService.save(model);

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Responsável técnico salvo para emissão de laudos.';
    });
  }

  Future<void> _pickSignatureFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecionar assinatura profissional',
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      lockParentWindow: true,
    );

    final String? sourcePath = result?.files.single.path;

    if (sourcePath == null || sourcePath.trim().isEmpty) {
      setState(() {
        _status = 'Importação de assinatura cancelada.';
      });
      return;
    }

    try {
      final String importedPath =
          await _signatureService.importSignatureFile(sourcePath);

      if (!mounted) {
        return;
      }

      setState(() {
        _signaturePathController.text = importedPath;
        _status = 'Assinatura importada com sucesso.';
      });

      await _saveProfessionalSignature();
    } on FileSystemException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = error.message;
      });
    }
  }

  Future<void> _exportUsers() async {
    final File file = await _store.exportJson(_module);

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Usuários exportados para ${file.path}';
    });
  }

  List<KristalOperationalRecord> get _filteredRecords {
    final String query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _records;
    }

    return _records.where((KristalOperationalRecord record) {
      return record.data.values.any(
        (String value) => value.toLowerCase().contains(query),
      );
    }).toList(growable: false);
  }

  int get _recentCount {
    return _records
        .where(
          (KristalOperationalRecord record) =>
              record.activeRecent && !record.archived,
        )
        .length;
  }

  int get _historyCount {
    return _records
        .where((KristalOperationalRecord record) => record.archived)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF06111D),
      child: Column(
        children: <Widget>[
          _Header(
            title: 'Usuários / Responsável Técnico',
            subtitle:
                'Perfis, status, assinatura profissional e responsável técnico',
            icon: Icons.admin_panel_settings_rounded,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      final bool narrow = constraints.maxWidth < 1060;

                      if (narrow) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: <Widget>[
                              _buildLeftPanel(),
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 560,
                                child: _buildRecordsPanel(),
                              ),
                            ],
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            SizedBox(width: 430, child: _buildLeftPanel()),
                            const SizedBox(width: 18),
                            Expanded(child: _buildRecordsPanel()),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          _Footer(status: _status),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            _sectionTitle(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Cadastro de usuário',
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _CountCard(
                    title: 'Consulta recente',
                    value: _recentCount.toString(),
                    color: const Color(0xFF4EA3FF),
                    icon: Icons.history_toggle_off_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CountCard(
                    title: 'Histórico',
                    value: _historyCount.toString(),
                    color: const Color(0xFFFFC857),
                    icon: Icons.archive_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field(
              controller: _nameController,
              label: 'Nome *',
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 10),
            _field(
              controller: _userController,
              label: 'Usuário *',
              icon: Icons.account_circle_rounded,
            ),
            const SizedBox(height: 10),
            _dropdown(
              label: 'Perfil *',
              icon: Icons.security_rounded,
              value: _selectedProfile,
              values: _profiles,
              onChanged: (String value) {
                setState(() {
                  _selectedProfile = value;
                });
              },
            ),
            const SizedBox(height: 10),
            _dropdown(
              label: 'Status *',
              icon: Icons.verified_user_rounded,
              value: _selectedStatus,
              values: _statuses,
              onChanged: (String value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saveUser,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salvar usuário'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFF244B6D)),
            const SizedBox(height: 14),
            _sectionTitle(
              icon: Icons.draw_rounded,
              title: 'Assinatura profissional',
            ),
            const SizedBox(height: 12),
            _field(
              controller: _professionalNameController,
              label: 'Nome do profissional *',
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 10),
            MilitaryRankDropdown(controller: _professionalRankController),
            const SizedBox(height: 10),
            _field(
              controller: _professionalSpecialtyController,
              label: 'Especialidade',
              icon: Icons.biotech_rounded,
            ),
            const SizedBox(height: 10),
            _field(
              controller: _professionalCouncilController,
              label: 'Conselho conforme especialidade',
              icon: Icons.badge_rounded,
              hint: 'Ex.: CRF-RJ, CRBM, CRM, COREN, CRO...',
            ),
            const SizedBox(height: 10),
            _field(
              controller: _professionalCouncilNumberController,
              label: 'Número do conselho',
              icon: Icons.confirmation_number_rounded,
            ),
            const SizedBox(height: 10),
            _field(
              controller: _signaturePathController,
              label: 'Arquivo da assinatura',
              icon: Icons.attach_file_rounded,
              readOnly: true,
              hint: 'PDF, JPG, JPEG ou PNG',
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickSignatureFile,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Adicionar assinatura'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveProfessionalSignature,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Salvar assinatura'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _signaturePreview(),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFF244B6D)),
            const SizedBox(height: 14),
            _sectionTitle(
              icon: Icons.verified_user_rounded,
              title: 'Responsável técnico',
            ),
            const SizedBox(height: 12),
            _field(
              controller: _technicalNameController,
              label: 'Nome do responsável técnico *',
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 10),
            MilitaryRankDropdown(controller: _technicalRankController),
            const SizedBox(height: 10),
            _field(
              controller: _technicalSpecialtyController,
              label: 'Especialidade',
              icon: Icons.biotech_rounded,
            ),
            const SizedBox(height: 10),
            _field(
              controller: _technicalCouncilController,
              label: 'Conselho conforme especialidade',
              icon: Icons.badge_rounded,
              hint: 'Ex.: CRF-RJ, CRBM, CRM, COREN, CRO...',
            ),
            const SizedBox(height: 10),
            _field(
              controller: _technicalCouncilNumberController,
              label: 'Número do conselho',
              icon: Icons.confirmation_number_rounded,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saveTechnicalResponsible,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salvar responsável técnico'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsPanel() {
    final List<KristalOperationalRecord> records = _filteredRecords;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Pesquisar usuários',
              prefixIcon: Icon(Icons.search_rounded),
              filled: true,
              fillColor: Color(0xFF071827),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Atualizar'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _exportUsers,
                icon: const Icon(Icons.file_download_rounded),
                label: const Text('Exportar usuários'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: records.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum registro encontrado.',
                      style: TextStyle(
                        color: Color(0xFFB7D7F1),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      return _userTile(records[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _userTile(KristalOperationalRecord record) {
    final bool archived = record.archived;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: archived ? const Color(0xFF182536) : const Color(0xFF071827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: archived ? const Color(0xFFFFC857) : const Color(0xFF244B6D),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            archived
                ? Icons.archive_rounded
                : Icons.admin_panel_settings_rounded,
            color: archived ? const Color(0xFFFFC857) : const Color(0xFF73D7FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              children: <Widget>[
                _chip('Nome', record.data['nome'] ?? ''),
                _chip('Usuário', record.data['usuario'] ?? ''),
                _chip('Perfil', record.data['perfil'] ?? ''),
                _chip('Status', record.data['status'] ?? ''),
              ],
            ),
          ),
          const SizedBox(width: 10),
          archived
              ? const Text(
                  'Histórico',
                  style: TextStyle(
                    color: Color(0xFFFFC857),
                    fontWeight: FontWeight.w900,
                  ),
                )
              : IconButton(
                  tooltip: 'Arquivar sem excluir',
                  onPressed: () => _archiveUser(record.id),
                  icon: const Icon(Icons.archive_outlined),
                  color: const Color(0xFFFFC857),
                ),
        ],
      ),
    );
  }

  Widget _signaturePreview() {
    final String path = _signaturePathController.text.trim();

    if (path.isEmpty) {
      return const Text(
        'Nenhuma assinatura importada.',
        style: TextStyle(
          color: Color(0xFFB7D7F1),
          fontWeight: FontWeight.w700,
        ),
      );
    }

    if (_signatureService.isImage(path) && File(path).existsSync()) {
      return Container(
        height: 120,
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Image.file(File(path), fit: BoxFit.contain),
      );
    }

    if (_signatureService.isPdf(path) && File(path).existsSync()) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF071827),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF244B6D)),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFFC857)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Assinatura em PDF importada e vinculada ao laudo.',
                style: TextStyle(
                  color: Color(0xFFB7D7F1),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const Text(
      'Arquivo de assinatura não encontrado.',
      style: TextStyle(
        color: Color(0xFFFFC857),
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      menuMaxHeight: 320,
      isExpanded: true,
      dropdownColor: const Color(0xFF0D2033),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF071827),
        border: const OutlineInputBorder(),
      ),
      items: values
          .map(
            (String item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
          .toList(growable: false),
      onChanged: (String? item) {
        if (item == null) {
          return;
        }

        onChanged(item);
      },
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF071827),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, color: const Color(0xFF73D7FF)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return SizedBox(
      width: 205,
      child: RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFF73D7FF),
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: const Color(0xFF0D2033),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF244B6D)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF18344F),
        border: Border(bottom: BorderSide(color: Color(0xFF26577D))),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF0E88C6).withOpacity(0.24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3EC6FF)),
            ),
            child: Icon(icon, color: const Color(0xFF73D7FF), size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFB7D7F1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Image.asset(
            AppConstants.hmrLogoPath,
            width: 52,
            height: 52,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.local_hospital_rounded,
              color: Color(0xFF73D7FF),
              size: 42,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF071827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.85)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              style: const TextStyle(
                color: Color(0xFFB7D7F1),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: const Color(0xFF06111D),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFFFC857),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
