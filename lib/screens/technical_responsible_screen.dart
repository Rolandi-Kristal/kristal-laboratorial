import 'package:flutter/material.dart';

import '../models/technical_responsible_model.dart';
import '../services/technical_responsible_service.dart';
import '../widgets/military_rank_dropdown.dart';

class TechnicalResponsibleScreen extends StatefulWidget {
  const TechnicalResponsibleScreen({super.key});

  @override
  State<TechnicalResponsibleScreen> createState() =>
      _TechnicalResponsibleScreenState();
}

class _TechnicalResponsibleScreenState
    extends State<TechnicalResponsibleScreen> {
  final TechnicalResponsibleService _service =
      TechnicalResponsibleService.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rankController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _councilController = TextEditingController();
  final TextEditingController _councilNumberController =
      TextEditingController();

  bool _loading = true;
  String _status = 'Carregando responsável técnico...';

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
    super.dispose();
  }

  Future<void> _load() async {
    final TechnicalResponsibleModel model = await _service.load();

    if (!mounted) {
      return;
    }

    setState(() {
      _nameController.text = model.name;
      _rankController.text = model.rankOrGrade;
      _specialtyController.text = model.specialty;
      _councilController.text = model.council;
      _councilNumberController.text = model.councilNumber;
      _loading = false;
      _status = 'Dados carregados.';
    });
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _status = 'Informe o nome do responsável técnico.';
      });
      return;
    }

    final TechnicalResponsibleModel model = TechnicalResponsibleModel(
      name: _nameController.text.trim(),
      rankOrGrade: _rankController.text.trim(),
      specialty: _specialtyController.text.trim(),
      council: _councilController.text.trim(),
      councilNumber: _councilNumberController.text.trim(),
      updatedAt: DateTime.now(),
    );

    await _service.save(model);

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Responsável técnico salvo para emissão de laudos.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final String preview = TechnicalResponsibleModel(
      name: _nameController.text.trim(),
      rankOrGrade: _rankController.text.trim(),
      specialty: _specialtyController.text.trim(),
      council: _councilController.text.trim(),
      councilNumber: _councilNumberController.text.trim(),
      updatedAt: DateTime.now(),
    ).printableLine;

    return Scaffold(
      backgroundColor: const Color(0xFF06111D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF142B42),
        title: const Text('Cadastro do Responsável Técnico'),
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
                            label: 'Nome do responsável técnico *',
                            icon: Icons.person_rounded,
                            onChanged: (_) => setState(() {}),
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
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                          _field(
                            controller: _councilController,
                            label: 'Conselho conforme especialidade',
                            icon: Icons.badge_rounded,
                            hint: 'Ex.: CRF-RJ, CRBM, CRM, COREN, CFF, CRO...',
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                          _field(
                            controller: _councilNumberController,
                            label: 'Número do conselho',
                            icon: Icons.confirmation_number_rounded,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Salvar responsável técnico'),
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
                            'Pré-visualização no rodapé do laudo',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              preview,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
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
