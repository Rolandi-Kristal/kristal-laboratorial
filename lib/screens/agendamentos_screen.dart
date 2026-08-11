import 'package:flutter/material.dart';

import '../services/lab_repository.dart';

class AgendamentosScreen extends StatefulWidget {
  const AgendamentosScreen({super.key});

  @override
  State<AgendamentosScreen> createState() => _AgendamentosScreenState();
}

class _AgendamentosScreenState extends State<AgendamentosScreen> {
  final LabRepository repo = LabRepository();
  final TextEditingController paciente = TextEditingController();
  final TextEditingController cpf = TextEditingController();
  final TextEditingController telefone = TextEditingController();
  final TextEditingController exame = TextEditingController();
  final TextEditingController observacao = TextEditingController();

  DateTime data = DateTime.now();
  String horario = '07:00';
  String tipo = 'AGENDAMENTO';
  String status = 'AGENDADO';
  bool loading = false;
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

  final List<String> horarios = List<String>.generate(
    25,
    (int index) {
      final int totalMinutes = 7 * 60 + index * 15;
      final int hour = totalMinutes ~/ 60;
      final int minute = totalMinutes % 60;
      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';
    },
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    paciente.dispose();
    cpf.dispose();
    telefone.dispose();
    exame.dispose();
    observacao.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    rows = await repo.all('agendamentos', orderBy: 'dataHora ASC');
    if (mounted) setState(() => loading = false);
  }

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: data,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;
    setState(() => data = picked);
  }

  Future<void> _salvar() async {
    if (paciente.text.trim().isEmpty) {
      _msg('Informe o paciente.');
      return;
    }

    final String now = DateTime.now().toIso8601String();
    await repo.upsert('agendamentos', <String, dynamic>{
      'id': 'AGE-${DateTime.now().microsecondsSinceEpoch}',
      'tipo': tipo,
      'pacienteId': '',
      'pacienteNome': paciente.text.trim(),
      'cpf': cpf.text.trim(),
      'telefone': telefone.text.trim(),
      'exameId': '',
      'exameNome': exame.text.trim(),
      'dataHora': '${_isoDate(data)} $horario',
      'origem': 'AGENDA',
      'status': status,
      'prioridade': 'NORMAL',
      'cadebensNumero': '',
      'cadebensSituacao': '',
      'peso': '',
      'altura': '',
      'observacao': observacao.text.trim(),
      'criadoEm': now,
      'atualizadoEm': now,
    });
    paciente.clear();
    cpf.clear();
    telefone.clear();
    exame.clear();
    observacao.clear();
    await _load();
    _msg('Agendamento salvo.');
  }

  String _isoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _brDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    double width = 220,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _combo({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    double width = 180,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: values
            .map((String item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ))
            .toList(),
        onChanged: (String? item) {
          if (item != null) onChanged(item);
        },
      ),
    );
  }

  Widget _form() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _selecionarData,
              icon: const Icon(Icons.calendar_month),
              label: Text(_brDate(data)),
            ),
            _combo(
              label: 'Horario',
              value: horario,
              values: horarios,
              onChanged: (String v) => setState(() => horario = v),
            ),
            _combo(
              label: 'Tipo',
              value: tipo,
              values: const <String>['AGENDAMENTO', 'PRE_AGENDAMENTO'],
              onChanged: (String v) => setState(() => tipo = v),
              width: 210,
            ),
            _combo(
              label: 'Status',
              value: status,
              values: const <String>['AGENDADO', 'PRE_AGENDADO', 'ATENDIDO'],
              onChanged: (String v) => setState(() => status = v),
            ),
            _field(paciente, 'Paciente', width: 320),
            _field(cpf, 'CPF', width: 170),
            _field(telefone, 'Telefone', width: 170),
            _field(exame, 'Exames', width: 300),
            _field(observacao, 'Observacao', width: 420),
            ElevatedButton.icon(
              onPressed: _salvar,
              icon: const Icon(Icons.save),
              label: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String filtroDia = _isoDate(data);
    final List<Map<String, dynamic>> doDia = rows.where((row) {
      return (row['dataHora']?.toString() ?? '').startsWith(filtroDia);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendamento de Exames'),
        actions: <Widget>[
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: <Widget>[
          _form(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Agenda de ${_brDate(data)}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : doDia.isEmpty
                    ? const Center(
                        child: Text('Nenhum horario agendado nesta data.'))
                    : ListView.builder(
                        itemCount: doDia.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Map<String, dynamic> row = doDia[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.event_available),
                              title: Text(
                                '${row['dataHora'] ?? ''} - ${row['pacienteNome'] ?? ''}',
                              ),
                              subtitle: Text(
                                '${row['tipo'] ?? ''} | ${row['status'] ?? ''} | ${row['exameNome'] ?? ''}',
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
