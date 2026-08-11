import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/lab_repository.dart';

class DashboardScreen extends StatefulWidget {
  final AuthSession session;
  final bool embedded;

  const DashboardScreen(
      {super.key, required this.session, this.embedded = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LabRepository repo = LabRepository();
  final Map<String, int> counters = <String, int>{};
  bool loading = true;

  static const List<_DashboardMetric> metrics = <_DashboardMetric>[
    _DashboardMetric(
        label: 'Pacientes',
        table: 'pacientes',
        icon: Icons.groups_rounded,
        color: Color(0xFF4EA3FF)),
    _DashboardMetric(
        label: 'Atendimentos',
        table: 'pedidos',
        icon: Icons.assignment_rounded,
        color: Color(0xFF79D7FF)),
    _DashboardMetric(
        label: 'Amostras',
        table: 'amostras',
        icon: Icons.qr_code_2_rounded,
        color: Color(0xFFFFD166)),
    _DashboardMetric(
        label: 'Resultados',
        table: 'resultados',
        icon: Icons.fact_check_rounded,
        color: Color(0xFF34D399)),
    _DashboardMetric(
        label: 'Exames',
        table: 'exames',
        icon: Icons.biotech_rounded,
        color: Color(0xFF60A5FA)),
    _DashboardMetric(
        label: 'Equipamentos',
        table: 'equipamentos',
        icon: Icons.precision_manufacturing_rounded,
        color: Color(0xFFC4B5FD)),
    _DashboardMetric(
        label: 'Estoque',
        table: 'estoque',
        icon: Icons.inventory_2_rounded,
        color: Color(0xFFFDBA74)),
    _DashboardMetric(
        label: 'CQ',
        table: 'qualidade',
        icon: Icons.verified_rounded,
        color: Color(0xFF93C5FD)),
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    for (final _DashboardMetric metric in metrics) {
      counters[metric.table] = await repo.count(metric.table);
    }
    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          _DashboardTopBar(session: widget.session, onRefresh: load),
          const SizedBox(height: 16),
          _MetricGrid(metrics: metrics, counters: counters, loading: loading),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 6,
                child: _PipelineCard(counters: counters),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _AlertsCard(counters: counters),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 6,
                child: _ActivityTable(counters: counters),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _DistributionCard(counters: counters),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SystemStatusCard(counters: counters),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Laboratorial'),
        actions: <Widget>[
          IconButton(
              tooltip: 'Atualizar',
              onPressed: load,
              icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: content,
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  final AuthSession session;
  final VoidCallback onRefresh;

  const _DashboardTopBar({required this.session, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF4EA3FF).withOpacity(.14),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: const Color(0xFF4EA3FF).withOpacity(.5)),
              ),
              child: const Icon(Icons.monitor_heart_rounded,
                  color: Color(0xFF79D7FF), size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('DASHBOARD OPERACIONAL',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                      'Bem-vindo, ${session.nome} • Sessão protegida • Indicadores em tempo real do banco local',
                      style: const TextStyle(color: Color(0xFFBFD7EA))),
                ],
              ),
            ),
            ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Atualizar')),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<_DashboardMetric> metrics;
  final Map<String, int> counters;
  final bool loading;

  const _MetricGrid(
      {required this.metrics, required this.counters, required this.loading});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 700
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 128,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: metrics.length,
          itemBuilder: (BuildContext context, int index) {
            final _DashboardMetric metric = metrics[index];
            return _MetricCard(
                metric: metric,
                value: counters[metric.table] ?? 0,
                loading: loading);
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _DashboardMetric metric;
  final int value;
  final bool loading;

  const _MetricCard(
      {required this.metric, required this.value, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: metric.color.withOpacity(.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: metric.color.withOpacity(.42)),
              ),
              child: Icon(metric.icon, color: metric.color, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE6F4FF))),
                  const SizedBox(height: 8),
                  loading
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(value.toString(),
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: metric.color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PipelineCard extends StatelessWidget {
  final Map<String, int> counters;

  const _PipelineCard({required this.counters});

  @override
  Widget build(BuildContext context) {
    final List<_PipelineStep> steps = <_PipelineStep>[
      _PipelineStep(
          'Pedidos', counters['pedidos'] ?? 0, Icons.assignment_rounded),
      _PipelineStep(
          'Amostras', counters['amostras'] ?? 0, Icons.qr_code_2_rounded),
      _PipelineStep(
          'Análise', counters['resultados'] ?? 0, Icons.science_rounded),
      _PipelineStep(
          'Laudos', counters['resultados'] ?? 0, Icons.picture_as_pdf_rounded),
      _PipelineStep(
          'Histórico',
          (counters['pacientes'] ?? 0) + (counters['resultados'] ?? 0),
          Icons.archive_rounded),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Fluxo operacional das amostras',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                for (int i = 0; i < steps.length; i++) ...<Widget>[
                  Expanded(child: _PipelineBox(step: steps[i], index: i)),
                  if (i < steps.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                          color: Color(0xFF79D7FF)),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PipelineBox extends StatelessWidget {
  final _PipelineStep step;
  final int index;

  const _PipelineBox({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF09233D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1B5E8F)),
      ),
      child: Column(
        children: <Widget>[
          Icon(step.icon, color: const Color(0xFF79D7FF), size: 26),
          const SizedBox(height: 8),
          Text(step.label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 6),
          Text(step.value.toString(),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4EA3FF))),
        ],
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final Map<String, int> counters;

  const _AlertsCard({required this.counters});

  @override
  Widget build(BuildContext context) {
    final int results = counters['resultados'] ?? 0;
    final int equipment = counters['equipamentos'] ?? 0;
    final int stock = counters['estoque'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Alertas críticos e validação',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _AlertLine(
                icon: Icons.warning_rounded,
                color: Colors.amber,
                title: 'Resultados pendentes',
                value: results),
            _AlertLine(
                icon: Icons.precision_manufacturing_rounded,
                color: const Color(0xFF79D7FF),
                title: 'Equipamentos configurados',
                value: equipment),
            _AlertLine(
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFF34D399),
                title: 'Itens em estoque',
                value: stock),
            const Divider(height: 26),
            const Text(
                'Status operacional: sistema pronto para rotina local, portal, laudos, exportações e conexão com equipamentos.',
                style: TextStyle(color: Color(0xFFBFD7EA))),
          ],
        ),
      ),
    );
  }
}

class _AlertLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int value;

  const _AlertLine(
      {required this.icon,
      required this.color,
      required this.title,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          Text(value.toString(),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }
}

class _ActivityTable extends StatelessWidget {
  final Map<String, int> counters;

  const _ActivityTable({required this.counters});

  @override
  Widget build(BuildContext context) {
    final List<_ActivityRow> rows = <_ActivityRow>[
      _ActivityRow('GLI', 'Glicose, Dosagem de', counters['resultados'] ?? 0,
          'Liberado'),
      _ActivityRow(
          'HEM', 'Hemograma completo', counters['pedidos'] ?? 0, 'Em análise'),
      _ActivityRow(
          'URE', 'Ureia, dosagem de', counters['amostras'] ?? 0, 'Coletado'),
      _ActivityRow('CRE', 'Creatinina, dosagem de', counters['qualidade'] ?? 0,
          'Validado'),
      _ActivityRow('TSH', 'Hormônio Tire estimulante', counters['exames'] ?? 0,
          'Cadastrado'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Atividade recente por exame',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFF0A2A4E)),
                dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) =>
                        states.contains(WidgetState.selected)
                            ? const Color(0xFF123D63)
                            : null),
                columns: const <DataColumn>[
                  DataColumn(label: Text('MNE')),
                  DataColumn(label: Text('Exame')),
                  DataColumn(label: Text('Qtd.')),
                  DataColumn(label: Text('Status')),
                ],
                rows: rows.map((_ActivityRow row) {
                  return DataRow(
                    cells: <DataCell>[
                      DataCell(Text(row.code,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF79D7FF)))),
                      DataCell(Text(row.name)),
                      DataCell(Text(row.quantity.toString())),
                      DataCell(Text(row.status,
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  final Map<String, int> counters;

  const _DistributionCard({required this.counters});

  @override
  Widget build(BuildContext context) {
    final List<int> values = <int>[
      counters['pacientes'] ?? 0,
      counters['pedidos'] ?? 0,
      counters['amostras'] ?? 0,
      counters['resultados'] ?? 0,
      counters['exames'] ?? 0,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Distribuição operacional',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            SizedBox(
                height: 210,
                child: CustomPaint(
                    painter: _DonutPainter(values: values),
                    child: const SizedBox.expand())),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                _Legend(color: Color(0xFF4EA3FF), label: 'Pacientes'),
                _Legend(color: Color(0xFF79D7FF), label: 'Pedidos'),
                _Legend(color: Color(0xFFFFD166), label: 'Amostras'),
                _Legend(color: Color(0xFF34D399), label: 'Resultados'),
                _Legend(color: Color(0xFFC4B5FD), label: 'Exames'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemStatusCard extends StatelessWidget {
  final Map<String, int> counters;

  const _SystemStatusCard({required this.counters});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Status da infraestrutura KRISTAL',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const <Widget>[
                _StatusBox(
                    icon: Icons.folder_rounded,
                    title: 'Caminhos reais',
                    subtitle: 'data • drivers • reports • exports'),
                _StatusBox(
                    icon: Icons.router_rounded,
                    title: 'Servidor/Portal',
                    subtitle: 'Local • Nuvem • rede interna'),
                _StatusBox(
                    icon: Icons.usb_rounded,
                    title: 'Equipamentos',
                    subtitle: 'Serial • TCP/IP • ASTM • HL7'),
                _StatusBox(
                    icon: Icons.security_rounded,
                    title: 'Blindagem',
                    subtitle: 'LGPD • auditoria • criptografia'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StatusBox(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF09233D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1B5E8F)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: const Color(0xFF79D7FF), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFFBFD7EA), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFFBFD7EA))),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<int> values;

  const _DonutPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final List<Color> colors = <Color>[
      const Color(0xFF4EA3FF),
      const Color(0xFF79D7FF),
      const Color(0xFFFFD166),
      const Color(0xFF34D399),
      const Color(0xFFC4B5FD),
    ];
    final double total =
        values.fold<int>(0, (int a, int b) => a + b).toDouble();
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) * .32;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round;

    if (total <= 0) {
      paint.color = const Color(0xFF173A5E);
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final double sweep = (values[i] / total) * math.pi * 2;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect, start, sweep.clamp(.05, math.pi * 2), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _DashboardMetric {
  final String label;
  final String table;
  final IconData icon;
  final Color color;

  const _DashboardMetric(
      {required this.label,
      required this.table,
      required this.icon,
      required this.color});
}

class _PipelineStep {
  final String label;
  final int value;
  final IconData icon;

  const _PipelineStep(this.label, this.value, this.icon);
}

class _ActivityRow {
  final String code;
  final String name;
  final int quantity;
  final String status;

  const _ActivityRow(this.code, this.name, this.quantity, this.status);
}
