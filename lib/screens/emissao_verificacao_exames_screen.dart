import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/lab_repository.dart';
import '../services/laudo_hash_service.dart';
import '../services/pdf_laudo_service.dart';

class EmissaoVerificacaoExamesScreen extends StatefulWidget {
  final AuthSession session;

  const EmissaoVerificacaoExamesScreen({
    super.key,
    required this.session,
  });

  @override
  State<EmissaoVerificacaoExamesScreen> createState() =>
      _EmissaoVerificacaoExamesScreenState();
}

class _EmissaoVerificacaoExamesScreenState
    extends State<EmissaoVerificacaoExamesScreen> {
  final LabRepository repo = LabRepository();
  final TextEditingController guia = TextEditingController();
  final TextEditingController senha = TextEditingController();
  final TextEditingController pesquisa = TextEditingController();

  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  bool loading = true;
  String status = 'Carregando exames.';
  DateTime emissao = DateTime.now();
  DateTime validade = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    guia.dispose();
    senha.dispose();
    pesquisa.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> resultados =
        await repo.all('resultados', orderBy: 'criadoEm DESC');
    final List<Map<String, dynamic>> laudos =
        await repo.all('laudos', orderBy: 'criadoEm DESC');
    rows = <Map<String, dynamic>>[
      ...resultados.map((Map<String, dynamic> row) => <String, dynamic>{
            ...row,
            'origem': 'resultado',
          }),
      ...laudos.map((Map<String, dynamic> row) => <String, dynamic>{
            ...row,
            'origem': 'laudo',
          }),
    ];
    if (!mounted) return;
    setState(() {
      loading = false;
      status = '${rows.length} exame(s)/laudo(s) carregado(s).';
    });
  }

  Future<void> _selecionarData(bool isEmissao) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isEmissao ? emissao : validade,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;
    setState(() {
      if (isEmissao) {
        emissao = picked;
      } else {
        validade = picked;
      }
    });
  }

  Future<void> _pdf(Map<String, dynamic> row) {
    return PdfLaudoService.instance.gerarLaudoPdf(row);
  }

  void _verificar(Map<String, dynamic> row) {
    final String codigo = LaudoHashService.gerarCodigoValidacao(row);
    setState(() => status = 'Codigo de verificacao: $codigo');
  }

  Future<void> _cancelar(Map<String, dynamic> row) async {
    final String id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final Map<String, dynamic> updated = Map<String, dynamic>.from(row);
    updated['status'] = 'CANCELADO';
    updated['observacao'] = 'Cancelado pela tela de emissao/verificacao.';
    await repo.upsert(row['origem'] == 'laudo' ? 'laudos' : 'resultados', updated);
    await _load();
  }

  List<Map<String, dynamic>> get _filtered {
    final String q = pesquisa.text.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((Map<String, dynamic> row) {
      return row.values.any(
        (dynamic value) => value.toString().toLowerCase().contains(q),
      );
    }).toList();
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _leftBar() {
    return SizedBox(
      width: 120,
      child: Container(
        color: const Color(0xFF009A9A),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 12),
            _barButton('Confirmar', Icons.check_circle, _load),
            _barButton('Cancelar', Icons.cancel, () {
              setState(() => status = 'Operacao cancelada.');
            }),
            const Divider(color: Colors.white70),
            _barButton('Servicos', Icons.medical_services, _load),
            _barButton('Anexos', Icons.attach_file, _load),
            const Spacer(),
            _barButton('Ajuda', Icons.help, () {
              setState(() => status = 'Selecione um exame para PDF ou verificacao.');
            }),
          ],
        ),
      ),
    );
  }

  Widget _barButton(String label, IconData icon, VoidCallback action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: OutlinedButton.icon(
        onPressed: action,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF00A8A8),
      child: const Text(
        'Atendimento do paciente - Emissao e Verificacao de Exames',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 180,
            child: TextField(
              controller: guia,
              decoration: const InputDecoration(
                labelText: 'Guia',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _selecionarData(false),
            icon: const Icon(Icons.calendar_month),
            label: Text('Validade ${_date(validade)}'),
          ),
          SizedBox(
            width: 160,
            child: TextField(
              controller: senha,
              decoration: const InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _selecionarData(true),
            icon: const Icon(Icons.event),
            label: Text('Emissao ${_date(emissao)}'),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: pesquisa,
              decoration: const InputDecoration(
                labelText: 'Pesquisar exame/paciente/pedido',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _table() {
    final List<Map<String, dynamic>> data = _filtered;
    return loading
        ? const Center(child: CircularProgressIndicator())
        : data.isEmpty
            ? const Center(child: Text('Nenhum exame para emissao/verificacao.'))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Guia')),
                    DataColumn(label: Text('Exame')),
                    DataColumn(label: Text('Paciente/Pedido')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Valor')),
                    DataColumn(label: Text('Acoes')),
                  ],
                  rows: data.map((Map<String, dynamic> row) {
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(Text(guia.text.isEmpty ? '-' : guia.text)),
                        DataCell(Text(row['exameId']?.toString().isNotEmpty == true
                            ? row['exameId'].toString()
                            : row['id']?.toString() ?? '')),
                        DataCell(Text(
                          '${row['pacienteId'] ?? ''} ${row['pedidoId'] ?? ''}',
                        )),
                        DataCell(Text(row['status']?.toString() ?? '')),
                        DataCell(Text(row['valor']?.toString() ?? row['valorCheio']?.toString() ?? '')),
                        DataCell(
                          Wrap(
                            spacing: 6,
                            children: <Widget>[
                              IconButton(
                                tooltip: 'PDF',
                                onPressed: () => _pdf(row),
                                icon: const Icon(Icons.picture_as_pdf),
                              ),
                              IconButton(
                                tooltip: 'Verificar',
                                onPressed: () => _verificar(row),
                                icon: const Icon(Icons.verified),
                              ),
                              IconButton(
                                tooltip: 'Cancelar',
                                onPressed: () => _cancelar(row),
                                icon: const Icon(Icons.cancel),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Emissao e Verificacao de Exames')),
        body: Row(
          children: <Widget>[
            _leftBar(),
            Expanded(
              child: Column(
                children: <Widget>[
                  _header(),
                  const TabBar(
                    tabs: <Widget>[
                      Tab(text: 'Habilitacao do paciente'),
                      Tab(text: 'Guias e Exames'),
                      Tab(text: 'Paciente'),
                    ],
                  ),
                  _controls(),
                  Expanded(child: _table()),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(status),
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
