import 'dart:io';

import 'package:flutter/material.dart';

import '../models/professional_signature_model.dart';
import '../services/professional_signature_service.dart';
import '../widgets/military_rank_dropdown.dart';

class ProfessionalSignatureScreen extends StatefulWidget {
  const ProfessionalSignatureScreen({super.key});

  @override
  State<ProfessionalSignatureScreen> createState() =>
      _ProfessionalSignatureScreenState();
}

class _ProfessionalSignatureScreenState
    extends State<ProfessionalSignatureScreen> {
  final ProfessionalSignatureService _service =
      ProfessionalSignatureService.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rankController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _councilController = TextEditingController();
  final TextEditingController _councilNumberController =
      TextEditingController();
  final TextEditingController _signaturePathController =
      TextEditingController();

  bool _loading = true;
  String _status = 'Carregando assinatura profissional...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rankController.dispose();
    _specialtyController.dispose();
    _councilController.dispose();
    _councilNumberController.dispose();
    _signaturePathController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ProfessionalSignatureModel model = await _service.load();

    if (!mounted) {
      return;
    }

    setState(() {
      _nameController.text = model.professionalName;
      _rankController.text = model.rankOrGrade;
      _specialtyController.text = model.specialty;
      _councilController.text = model.council;
      _councilNumberController.text = model.councilNumber;
      _signaturePathController.text = model.signatureImagePath;
      _loading = false;
      _status = 'Dados carregados.';
    });
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _status = 'Informe o nome do profissional.';
      });
      return;
    }

    final String signaturePath = _signaturePathController.text.trim();

    if (signaturePath.isNotEmpty && !await File(signaturePath).exists()) {
      setState(() {
        _status = 'Arquivo de assinatura não encontrado.';
      });
      return;
    }

    final ProfessionalSignatureModel model = ProfessionalSignatureModel(
      professionalName: name,
      rankOrGrade: _rankController.text.trim(),
      specialty: _specialtyController.text.trim(),
      council: _councilController.text.trim(),
      councilNumber: _councilNumberController.text.trim(),
      signatureImagePath: signaturePath,
      updatedAt: DateTime.now(),
    );

    await _service.save(model);

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Assinatura profissional salva para emissão de laudos.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final String signaturePath = _signaturePathController.text.trim();
    final bool hasSignature =
        signaturePath.isNotEmpty && File(signaturePath).existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFF06111D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF142B42),
        title: const Text('Cadastro de Assinatura Profissional'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 430,
                    child: _panel(
                      child: ListView(
                        children: <Widget>[
                          _field(
                            controller: _nameController,
                            label: 'Nome do profissional *',
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(height: 10),
                          MilitaryRankDropdown(
                            controller: _rankController,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                          _field(
                            controller: _specialtyController,
                            label: 'Especialidade',
                            icon: Icons.biotech_rounded,
                          ),
                          const SizedBox(height: 10),
                          _field(
                            controller: _councilController,
                            label: 'Conselho conforme especialidade',
                            icon: Icons.badge_rounded,
                            hint: 'Ex.: CRF-RJ, CRBM, CRM, COREN, CFF, CRO...',
                          ),
                          const SizedBox(height: 10),
                          _field(
                            controller: _councilNumberController,
                            label: 'Número do conselho',
                            icon: Icons.confirmation_number_rounded,
                          ),
                          const SizedBox(height: 10),
                          _field(
                            controller: _signaturePathController,
                            label: 'Caminho da imagem da assinatura',
                            icon: Icons.draw_rounded,
                            hint:
                                r'Ex.: D:\kristal_laboratorial\assinaturas\assinatura.png',
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Salvar assinatura'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
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
                  Expanded(
                    child: _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'Pré-visualização da assinatura no laudo',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: Center(
                              child: hasSignature
                                  ? Image.file(
                                      File(signaturePath),
                                      fit: BoxFit.contain,
                                    )
                                  : const Text(
                                      'Informe o caminho da imagem da assinatura para visualizar.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFFB7D7F1),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _nameController.text.trim().isEmpty
                                ? 'Profissional não informado'
                                : _nameController.text.trim(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${_rankController.text.trim()} - '
                            '${_specialtyController.text.trim()} - '
                            '${_councilController.text.trim()} '
                            '${_councilNumberController.text.trim()}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFB7D7F1),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
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

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2033),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF244B6D)),
      ),
      child: child,
    );
  }
}
