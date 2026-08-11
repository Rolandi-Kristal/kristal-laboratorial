import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/historico_exame_paciente.dart';
import '../services/auth_service.dart';
import '../services/historico_exames_service.dart';
import '../services/log_service.dart';

class ConsultaExamesPacienteScreen extends StatefulWidget {
  final AuthSession session;

  const ConsultaExamesPacienteScreen({
    super.key,
    required this.session,
  });

  @override
  State<ConsultaExamesPacienteScreen> createState() =>
      _ConsultaExamesPacienteScreenState();
}

class _ConsultaExamesPacienteScreenState
    extends State<ConsultaExamesPacienteScreen> {
  final TextEditingController buscaController = TextEditingController();
  final TextEditingController cpfController = TextEditingController();
  final TextEditingController preccpController = TextEditingController();
  final TextEditingController inicioController = TextEditingController();
  final TextEditingController fimController = TextEditingController();

  List<HistoricoExamePaciente> exames = <HistoricoExamePaciente>[];
  bool loading = true;
  bool incluirRecentes = false;
  String status = 'Carregando histórico permanente de exames...';

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  @override
  void dispose() {
    buscaController.dispose();
    cpfController.dispose();
    preccpController.dispose();
    inicioController.dispose();
    fimController.dispose();
    super.dispose();
  }

  Future<void> _consultar() async {
    setState(() {
      loading = true;
      status = 'Consultando histórico permanente...';
    });

    try {
      final List<HistoricoExamePaciente> result =
          await HistoricoExamesService.instance.consultar(
        query: buscaController.text,
        cpf: cpfController.text,
        preccp: preccpController.text,
        dataInicioIso: inicioController.text,
        dataFimIso: fimController.text,
        incluirRecentes: incluirRecentes,
      );

      if (!mounted) return;

      setState(() {
        exames = result;
        loading = false;
        status = '${result.length} exame(s) encontrado(s) no histórico.';
      });
    } on DatabaseException catch (e, stackTrace) {
      await LogService.instance.error(
        'HISTORICO_EXAMES_CONSULTA',
        e,
        stackTrace,
      );
      if (!mounted) return;

      setState(() {
        loading = false;
        status =
            'Erro ao consultar histórico. Verifique a tabela historico_exames_pacientes no banco. Detalhe: $e';
      });
    }
  }

  Future<void> _limparFiltros() async {
    buscaController.clear();
    cpfController.clear();
    preccpController.clear();
    inicioController.clear();
    fimController.clear();
    incluirRecentes = false;
    await _consultar();
  }

  Future<void> _detalhes(HistoricoExamePaciente item) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(item.exameNome.isEmpty ? 'Exame' : item.exameNome),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: SelectableText(
              <String>[
                'Paciente: ${item.pacienteNome}',
                'CPF: ${item.cpf}',
                'PREC-CP: ${item.preccp}',
                'CNS: ${item.cns}',
                'Pedido: ${item.pedidoId}',
                'Amostra: ${item.amostraId}',
                'Exame: ${item.exameNome}',
                'Valor: ${item.valor} ${item.unidade}',
                'Referência: ${item.referencia}',
                'Crítico: ${item.critico}',
                'Status laudo: ${item.statusLaudo}',
                'Coletado em: ${item.coletadoEm}',
                'Liberado em: ${item.liberadoEm}',
                'Profissional: ${item.profissionalResponsavel}',
                'Médico: ${item.medicoResponsavel}',
                'Equipamento: ${item.equipamento}',
                'Origem: ${item.origem}',
                'Registro: ${item.tipoRegistro}',
                'Arquivado: ${item.isArquivado ? 'SIM' : 'NÃO'}',
                'Observação: ${item.observacao}',
              ].join('\n'),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _filtros() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 320,
              child: TextField(
                controller: buscaController,
                decoration: const InputDecoration(
                  labelText: 'Buscar por paciente, exame, pedido ou amostra',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _consultar(),
              ),
            ),
            SizedBox(
              width: 190,
              child: TextField(
                controller: cpfController,
                decoration: const InputDecoration(
                  labelText: 'CPF',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _consultar(),
              ),
            ),
            SizedBox(
              width: 190,
              child: TextField(
                controller: preccpController,
                decoration: const InputDecoration(
                  labelText: 'PREC-CP',
                  prefixIcon: Icon(Icons.assignment_ind),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _consultar(),
              ),
            ),
            SizedBox(
              width: 190,
              child: TextField(
                controller: inicioController,
                decoration: const InputDecoration(
                  labelText: 'Início ISO',
                  hintText: '2026-01-01',
                  prefixIcon: Icon(Icons.date_range),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _consultar(),
              ),
            ),
            SizedBox(
              width: 190,
              child: TextField(
                controller: fimController,
                decoration: const InputDecoration(
                  labelText: 'Fim ISO',
                  hintText: '2026-12-31',
                  prefixIcon: Icon(Icons.event),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _consultar(),
              ),
            ),
            FilterChip(
              label: const Text('Incluir recentes'),
              selected: incluirRecentes,
              onSelected: (bool value) {
                setState(() => incluirRecentes = value);
                _consultar();
              },
            ),
            ElevatedButton.icon(
              onPressed: _consultar,
              icon: const Icon(Icons.search),
              label: const Text('Consultar'),
            ),
            TextButton.icon(
              onPressed: _limparFiltros,
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Limpar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista() {
    if (loading) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (exames.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text('Nenhum exame localizado no histórico permanente.'),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: exames.length,
        itemBuilder: (BuildContext context, int index) {
          final HistoricoExamePaciente item = exames[index];

          return Card(
            child: ListTile(
              leading: Icon(
                item.isCritico ? Icons.warning_amber : Icons.science,
                color: item.isCritico ? Colors.amber : null,
              ),
              title: Text(
                '${item.pacienteNome.isEmpty ? 'Paciente não informado' : item.pacienteNome} • ${item.exameNome}',
              ),
              subtitle: Text(
                'CPF: ${item.cpf} | PREC-CP: ${item.preccp} | Pedido: ${item.pedidoId} | '
                'Valor: ${item.valor} ${item.unidade} | Liberado: ${item.liberadoEm}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _detalhes(item),
            ),
          );
        },
      ),
    );
  }

  Widget _status() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            const Icon(Icons.archive),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                status,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulta de Exames dos Pacientes'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _consultar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const Card(
            margin: EdgeInsets.all(12),
            child: ListTile(
              leading: Icon(Icons.lock_clock),
              title: Text('Histórico permanente'),
              subtitle: Text(
                'Dados antigos ficam preservados para consulta e separados dos exames recentes.',
              ),
            ),
          ),
          _filtros(),
          _status(),
          const SizedBox(height: 8),
          _lista(),
        ],
      ),
    );
  }
}
