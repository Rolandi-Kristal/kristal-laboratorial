import 'package:flutter/material.dart';

import '../services/atendimento_service.dart';
import '../services/auth_service.dart';
import '../services/lab_repository.dart';

class NovoAtendimentoScreen extends StatefulWidget {
  final AuthSession session;
  final Map<String, dynamic> initialData;

  const NovoAtendimentoScreen({
    super.key,
    required this.session,
    this.initialData = const <String, dynamic>{},
  });

  @override
  State<NovoAtendimentoScreen> createState() => _NovoAtendimentoScreenState();
}

class _NovoAtendimentoScreenState extends State<NovoAtendimentoScreen> {
  final Map<String, TextEditingController> c =
      <String, TextEditingController>{};

  final LabRepository _repo = LabRepository();
  final FocusNode _pacienteFocusNode = FocusNode();

  bool saving = false;
  List<Map<String, dynamic>> pacientes = <Map<String, dynamic>>[];
  String grupoAgenda = 'AGENDAMENTO';
  String statusPaciente = 'ATIVO';
  String statusAtendimento = 'AGENDADO';
  String horario = '07:00';
  DateTime dataAtendimento = DateTime.now();
  String autorizaSms = 'NAO';
  String enviaCorreio = 'NAO';
  String internet = 'SIM';

  final List<String> horarios = List<String>.generate(
    15,
    (int index) {
      final int minute = index * 2;
      return '07:${minute.toString().padLeft(2, '0')}';
    },
  );

  @override
  void initState() {
    super.initState();
    for (final String key in _fields) {
      c[key] = TextEditingController();
    }
    c['localColeta']!.text = 'LABORATORIO';
    c['localEntrega']!.text = 'LABORATORIO';
    c['formaEntrega']!.text = 'RETIRADA';
    c['cor']!.text = 'PARDA';
    c['religiao']!.text = 'CATOLICO';
    c['cidade']!.text = 'RESENDE';
    c['uf']!.text = 'RJ';
    for (final MapEntry<String, dynamic> entry in widget.initialData.entries) {
      if (c.containsKey(entry.key)) {
        c[entry.key]!.text = entry.value?.toString() ?? '';
      }
    }
    c['valorCheio']!.addListener(_calcularValores);
    c['peso']!.addListener(_calcularValores);
    c['altura']!.addListener(_calcularValores);
    c['pacienteNome']!.addListener(() {
      if (mounted) setState(() {});
    });
    _carregarPacientes();
  }

  @override
  void dispose() {
    _pacienteFocusNode.dispose();
    for (final TextEditingController controller in c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get _fields => const <String>[
        'pacienteNome',
        'cpf',
        'telefone',
        'celular',
        'email',
        'exames',
        'medicos',
        'convenio',
        'plano',
        'matriculaConvenio',
        'guia',
        'localColeta',
        'localEntrega',
        'formaEntrega',
        'procedenciaPaciente',
        'codigoInternet',
        'cor',
        'religiao',
        'altura',
        'peso',
        'imc',
        'estadoCivil',
        'tratamento',
        'idadeGestacional',
        'localInternacao',
        'quarto',
        'cid',
        'cnes',
        'nomeMae',
        'nomePai',
        'dataTransfusao',
        'dnv',
        'motivoExame',
        'matriculaEmpregado',
        'atividadeProfissional',
        'cep',
        'endereco',
        'bairro',
        'cidade',
        'uf',
        'valorCheio',
        'valorIndenizar20',
        'cadebensNumero',
        'cadebensSituacao',
        'observacao',
      ];

  Future<void> _carregarPacientes() async {
    final List<Map<String, dynamic>> rows = await _repo.all(
      'pacientes',
      orderBy: 'nome ASC',
      limit: 500,
    );
    if (!mounted) return;
    setState(() => pacientes = rows);
  }

  void _aplicarPaciente(Map<String, dynamic> paciente) {
    c['pacienteNome']!.text = paciente['nome']?.toString() ?? '';
    c['cpf']!.text = paciente['cpf']?.toString() ?? '';
    c['telefone']!.text = paciente['telefone']?.toString() ?? '';
    c['celular']!.text = paciente['celular']?.toString() ?? '';
    c['email']!.text = paciente['email']?.toString() ?? '';
    c['peso']!.text = paciente['peso']?.toString() ?? '';
    c['altura']!.text = paciente['altura']?.toString() ?? '';
    c['nomeMae']!.text = paciente['nomeMae']?.toString() ?? '';
    c['nomePai']!.text = paciente['nomePai']?.toString() ?? '';
    c['cep']!.text = paciente['cep']?.toString() ?? '';
    c['endereco']!.text = paciente['endereco']?.toString() ?? '';
    c['bairro']!.text = paciente['bairro']?.toString() ?? '';
    c['cidade']!.text = paciente['cidade']?.toString() ?? c['cidade']!.text;
    c['uf']!.text = paciente['uf']?.toString() ?? c['uf']!.text;
    c['cadebensNumero']!.text = paciente['cadebensNumero']?.toString() ?? '';
    c['cadebensSituacao']!.text =
        paciente['cadebensSituacao']?.toString() ?? '';
    c['matriculaEmpregado']!.text = paciente['matricula']?.toString() ?? '';
    _calcularValores();
  }

  Widget _pacienteAutocomplete() {
    return SizedBox(
      width: 440,
      child: RawAutocomplete<Map<String, dynamic>>(
        textEditingController: c['pacienteNome'],
        focusNode: _pacienteFocusNode,
        displayStringForOption: (Map<String, dynamic> option) =>
            option['nome']?.toString() ?? '',
        optionsBuilder: (TextEditingValue value) {
          final String query = value.text.trim().toLowerCase();
          if (query.isEmpty) return pacientes.take(30);
          return pacientes.where((Map<String, dynamic> paciente) {
            final String nome =
                paciente['nome']?.toString().toLowerCase() ?? '';
            final String cpf = paciente['cpf']?.toString().toLowerCase() ?? '';
            final String preccp =
                paciente['preccp']?.toString().toLowerCase() ?? '';
            return nome.contains(query) ||
                cpf.contains(query) ||
                preccp.contains(query);
          }).take(30);
        },
        onSelected: _aplicarPaciente,
        fieldViewBuilder: (
          BuildContext context,
          TextEditingController controller,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted,
        ) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'Paciente cadastrado',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                tooltip: 'Recarregar pacientes',
                onPressed: _carregarPacientes,
                icon: const Icon(Icons.refresh),
              ),
            ),
          );
        },
        optionsViewBuilder: (
          BuildContext context,
          AutocompleteOnSelected<Map<String, dynamic>> onSelected,
          Iterable<Map<String, dynamic>> options,
        ) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 440, maxHeight: 260),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> paciente =
                        options.elementAt(index);
                    return ListTile(
                      dense: true,
                      title: Text(paciente['nome']?.toString() ?? ''),
                      subtitle: Text(
                        'CPF: ${paciente['cpf'] ?? ''} | PREC-CP: ${paciente['preccp'] ?? ''}',
                      ),
                      onTap: () => onSelected(paciente),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _calcularValores() {
    final double? peso = double.tryParse(
      c['peso']!.text.replaceAll(',', '.'),
    );
    final double? alturaCm = double.tryParse(
      c['altura']!.text.replaceAll(',', '.'),
    );

    if (peso != null && alturaCm != null && alturaCm > 0) {
      final double alturaM = alturaCm > 3 ? alturaCm / 100 : alturaCm;
      c['imc']!.text = (peso / (alturaM * alturaM)).toStringAsFixed(2);
    }

    final String raw = c['valorCheio']!
        .text
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final double? valor = double.tryParse(raw);
    if (valor != null) {
      c['valorIndenizar20']!.text =
          (valor * 0.20).toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  Future<void> _salvar() async {
    if (saving) return;
    if (c['pacienteNome']!.text.trim().isEmpty) {
      _msg('Informe o nome do paciente.');
      return;
    }

    setState(() => saving = true);

    final Map<String, dynamic> data = <String, dynamic>{
      for (final String key in _fields) key: c[key]!.text.trim(),
      'grupoAgenda': grupoAgenda,
      'horario': horario,
      'dataHora': _dataHoraSelecionada(),
      'statusPaciente': statusPaciente,
      'statusAtendimento': statusAtendimento,
      'autorizaSms': autorizaSms,
      'enviaCorreio': enviaCorreio,
      'internet': internet,
    };

    try {
      await AtendimentoService.instance.salvarAtendimento(
        data: data,
        usuario: widget.session.login,
      );
      if (!mounted) return;
      _msg('Atendimento salvo com paciente, agendamento e pedido.');
    } catch (e) {
      if (!mounted) return;
      _msg('Erro ao salvar atendimento: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _limpar() {
    for (final TextEditingController controller in c.values) {
      controller.clear();
    }
    setState(() {
      grupoAgenda = 'AGENDAMENTO';
      statusPaciente = 'ATIVO';
      statusAtendimento = 'AGENDADO';
      horario = '07:00';
      dataAtendimento = DateTime.now();
      autorizaSms = 'NAO';
      enviaCorreio = 'NAO';
      internet = 'SIM';
    });
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Widget _field(
    String key,
    String label, {
    double width = 240,
    bool readOnly = false,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: c[key],
        readOnly: readOnly,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _select({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    double width = 220,
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
            .map(
              (String item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ),
            )
            .toList(),
        onChanged: (String? item) {
          if (item == null) return;
          onChanged(item);
        },
      ),
    );
  }

  Widget _wrap(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: children,
      ),
    );
  }

  Widget _agendaLateral() {
    return SizedBox(
      width: 190,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          color: const Color(0xFF101A25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                grupoAgenda,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _select(
                label: 'Grupo',
                value: grupoAgenda,
                values: const <String>['AGENDAMENTO', 'PRE_AGENDAMENTO'],
                onChanged: (String v) => setState(() => grupoAgenda = v),
                width: 170,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: OutlinedButton.icon(
                onPressed: _selecionarData,
                icon: const Icon(Icons.calendar_month),
                label: Text(_formatDate(dataAtendimento)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: horarios.length,
                itemBuilder: (BuildContext context, int index) {
                  final String item = horarios[index];
                  return ListTile(
                    dense: true,
                    selected: horario == item,
                    leading: Icon(
                      horario == item
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(item),
                    onTap: () => setState(() => horario = item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dataAtendimento,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;
    setState(() => dataAtendimento = picked);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _dataHoraSelecionada() {
    return '${dataAtendimento.year.toString().padLeft(4, '0')}-'
        '${dataAtendimento.month.toString().padLeft(2, '0')}-'
        '${dataAtendimento.day.toString().padLeft(2, '0')} $horario';
  }

  Widget _tabExames() {
    return _wrap(<Widget>[
      _pacienteAutocomplete(),
      _field('exames', 'Exames solicitados', width: 360),
      _field('medicos', 'Medicos', width: 300),
      _field('valorCheio', 'Valor cheio', width: 180),
      _field('valorIndenizar20', 'A indenizar 20%', width: 180, readOnly: true),
      _field('observacao', 'Observacao', width: 720, maxLines: 3),
    ]);
  }

  Widget _tabConvenios() {
    return _wrap(<Widget>[
      _field('convenio', 'Convenio', width: 260),
      _field('plano', 'Plano', width: 220),
      _field('matriculaConvenio', 'Matricula convenio', width: 220),
      _field('guia', 'Guia/autorizacao', width: 220),
      _field('cadebensNumero', 'CADEBENS numero', width: 220),
      _field('cadebensSituacao', 'CADEBENS situacao', width: 220),
      _field('codigoInternet', 'Codigo internet', width: 180),
    ]);
  }

  Widget _tabComplementares() {
    return _wrap(<Widget>[
      _field('localColeta', 'Local de coleta', width: 260),
      _field('procedenciaPaciente', 'Procedencia do paciente', width: 260),
      _field('localEntrega', 'Local de entrega', width: 260),
      _field('formaEntrega', 'Forma de entrega', width: 240),
      _select(
        label: 'Autoriza SMS',
        value: autorizaSms,
        values: const <String>['NAO', 'SIM'],
        onChanged: (String v) => setState(() => autorizaSms = v),
      ),
      _select(
        label: 'Envia correio',
        value: enviaCorreio,
        values: const <String>['NAO', 'SIM'],
        onChanged: (String v) => setState(() => enviaCorreio = v),
      ),
      _select(
        label: 'Internet',
        value: internet,
        values: const <String>['SIM', 'NAO'],
        onChanged: (String v) => setState(() => internet = v),
      ),
      _field('email', 'E-mail', width: 360),
      _field('cor', 'Cor', width: 160),
      _field('religiao', 'Religiao', width: 180),
      _field('altura', 'Altura cm', width: 130),
      _field('peso', 'Peso kg', width: 130),
      _field('imc', 'I.M.C.', width: 130, readOnly: true),
      _field('estadoCivil', 'Estado civil', width: 180),
      _field('tratamento', 'Tratamento', width: 200),
    ]);
  }

  Widget _tabAtendimento() {
    return _wrap(<Widget>[
      _select(
        label: 'Status paciente',
        value: statusPaciente,
        values: const <String>['ATIVO', 'EM_ATENDIMENTO', 'BLOQUEADO'],
        onChanged: (String v) => setState(() => statusPaciente = v),
      ),
      _select(
        label: 'Status atendimento',
        value: statusAtendimento,
        values: const <String>['AGENDADO', 'PRE_AGENDADO', 'ATENDIDO'],
        onChanged: (String v) => setState(() => statusAtendimento = v),
      ),
      _field('idadeGestacional', 'Idade gestacional', width: 180),
      _field('localInternacao', 'Local de internacao', width: 220),
      _field('quarto', 'Quarto', width: 130),
      _field('cid', 'CID', width: 130),
      _field('cnes', 'CNES', width: 160),
      _field('nomeMae', 'Nome da mae', width: 360),
      _field('nomePai', 'Nome do pai', width: 360),
      _field('dataTransfusao', 'Data de transfusao', width: 190),
      _field('dnv', 'DNV', width: 150),
      _field('motivoExame', 'Motivo exame', width: 220),
    ]);
  }

  Widget _tabFuncionais() {
    return _wrap(<Widget>[
      _field('cpf', 'CPF', width: 180),
      _field('telefone', 'Telefone', width: 180),
      _field('celular', 'Celular', width: 180),
      _field('matriculaEmpregado', 'Matr. empregado', width: 200),
      _field('atividadeProfissional', 'Atividade profissional', width: 280),
      _field('cep', 'CEP', width: 150),
      _field('endereco', 'Endereco', width: 420),
      _field('bairro', 'Bairro', width: 220),
      _field('cidade', 'Cidade', width: 220),
      _field('uf', 'UF', width: 100),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Novo Atendimento'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Exames'),
              Tab(text: 'Convenios'),
              Tab(text: 'Dados Complementares'),
              Tab(text: 'Atendimento'),
              Tab(text: 'Dados Funcionais'),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Recarregar pacientes',
              onPressed: _carregarPacientes,
              icon: const Icon(Icons.groups),
            ),
            IconButton(
              tooltip: 'Limpar campos',
              onPressed: saving ? null : _limpar,
              icon: const Icon(Icons.cleaning_services),
            ),
            IconButton(
              tooltip: 'Salvar atendimento',
              onPressed: saving ? null : _salvar,
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: Row(
          children: <Widget>[
            _agendaLateral(),
            Expanded(
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFF102235),
                    child: Text(
                      '${c['pacienteNome']!.text.isEmpty ? 'PACIENTE NAO INFORMADO' : c['pacienteNome']!.text} | $grupoAgenda | ${_formatDate(dataAtendimento)} $horario',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _tabExames(),
                        _tabConvenios(),
                        _tabComplementares(),
                        _tabAtendimento(),
                        _tabFuncionais(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: saving ? null : _limpar,
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpar Campos'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: saving ? null : _salvar,
                          icon: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.event_available),
                          label: Text(saving ? 'Salvando...' : 'Agendar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
