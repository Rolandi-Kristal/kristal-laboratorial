import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../services/kristal_operational_store_service.dart';
import 'amostras_screen.dart';
import 'atendimento_screen.dart';
import 'auditoria_screen.dart';
import 'catalogo_exames_completo_screen.dart';
import 'codigo_barras_etiquetas_screen.dart';
import 'controle_qualidade_screen.dart';
import 'equipamentos_screen.dart';
import 'estoque_screen.dart';
import 'financeiro_sire_screen.dart';
import 'laudos_pdf_screen.dart';
import 'pacientes_screen.dart';
import 'reagentes_lotes_screen.dart';
import 'relatorios_gerenciais_screen.dart';
import 'resultados_screen.dart';
import 'servidor_nuvem_screen.dart';
import 'usuarios_screen.dart';
import 'worklist_astm_hl7_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.session,
  });

  final Object? session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final List<_ModuleItem> _modules = <_ModuleItem>[
    _ModuleItem(
      group: 'PAINEL',
      title: 'Dashboard',
      subtitle: 'Visão geral laboratorial',
      icon: Icons.dashboard_rounded,
      builder: (_) => _DashboardContent(onOpenModule: _selectModuleByTitle),
    ),
    _ModuleItem(
      group: 'ATENDIMENTO',
      title: 'Pacientes',
      subtitle: 'Cadastro, documentos e histórico permanente',
      icon: Icons.groups_rounded,
      builder: (_) => const PacientesScreen(),
      moduleKey: 'pacientes',
    ),
    _ModuleItem(
      group: 'ATENDIMENTO',
      title: 'Atendimento',
      subtitle: 'Pedidos, guias, convênio e prioridade',
      icon: Icons.assignment_rounded,
      builder: (_) => const AtendimentoScreen(),
      moduleKey: 'atendimento',
    ),
    _ModuleItem(
      group: 'TÉCNICO',
      title: 'Catálogo de Exames',
      subtitle: 'MNE, código SIRE, setor, material e regras',
      icon: Icons.biotech_rounded,
      builder: (_) => const CatalogoExamesCompletoScreen(),
      moduleKey: 'catalogo_exames',
    ),
    _ModuleItem(
      group: 'TÉCNICO',
      title: 'Amostras',
      subtitle: 'Coleta, tubo, etiquetas, remessa e recebimento',
      icon: Icons.qr_code_2_rounded,
      builder: (_) => const AmostrasScreen(),
      moduleKey: 'amostras',
    ),
    _ModuleItem(
      group: 'TÉCNICO',
      title: 'Resultados',
      subtitle: 'Digitação, análise, crítica e liberação',
      icon: Icons.fact_check_rounded,
      builder: (_) => const ResultadosScreen(),
      moduleKey: 'resultados',
    ),
    _ModuleItem(
      group: 'TÉCNICO',
      title: 'Laudos PDF',
      subtitle: 'Impressão, assinatura, hash e portal',
      icon: Icons.picture_as_pdf_rounded,
      builder: (_) => const LaudosPdfScreen(),
      moduleKey: 'laudos_pdf',
    ),
    _ModuleItem(
      group: 'INTEGRAÇÕES',
      title: 'Código de Barras / Etiquetas',
      subtitle: 'Leitura real por leitor USB tipo teclado',
      icon: Icons.qr_code_scanner_rounded,
      builder: (_) => const CodigoBarrasEtiquetasScreen(),
    ),
    _ModuleItem(
      group: 'INTEGRAÇÕES',
      title: 'Worklist ASTM/HL7',
      subtitle: 'Fila de comunicação para equipamentos via servidor',
      icon: Icons.sync_alt_rounded,
      builder: (_) => const WorklistAstmHl7Screen(),
      moduleKey: 'worklist_astm_hl7',
    ),
    _ModuleItem(
      group: 'EQUIPAMENTOS',
      title: 'Equipamentos',
      subtitle: 'Máquinas conectadas via servidor, IP e porta',
      icon: Icons.precision_manufacturing_rounded,
      builder: (_) => const EquipamentosScreen(),
      moduleKey: 'equipamentos',
    ),
    _ModuleItem(
      group: 'EQUIPAMENTOS',
      title: 'Controle de Qualidade',
      subtitle: 'CQ, regras, lotes e rastreabilidade',
      icon: Icons.verified_rounded,
      builder: (_) => const ControleQualidadeScreen(),
      moduleKey: 'controle_qualidade',
    ),
    _ModuleItem(
      group: 'GESTÃO',
      title: 'Estoque',
      subtitle: 'Itens, consumo, validade e rastreabilidade',
      icon: Icons.inventory_2_rounded,
      builder: (_) => const EstoqueScreen(),
      moduleKey: 'estoque',
    ),
    _ModuleItem(
      group: 'GESTÃO',
      title: 'Reagentes e Lotes',
      subtitle: 'Validade, rastreabilidade e consumo',
      icon: Icons.science_rounded,
      builder: (_) => const ReagentesLotesScreen(),
      moduleKey: 'reagentes_lotes',
    ),
    _ModuleItem(
      group: 'GESTÃO',
      title: 'Financeiro SIRE',
      subtitle: 'Exportação, faturamento e comunicação KRISTAL SIRE',
      icon: Icons.account_balance_wallet_rounded,
      builder: (_) => const FinanceiroSireScreen(),
    ),
    _ModuleItem(
      group: 'GESTÃO',
      title: 'Relatórios Gerenciais',
      subtitle: 'Indicadores, estatística e exportações',
      icon: Icons.bar_chart_rounded,
      builder: (_) => const RelatoriosGerenciaisScreen(),
      moduleKey: 'relatorios_gerenciais',
    ),
    _ModuleItem(
      group: 'SISTEMA',
      title: 'Servidor / Nuvem',
      subtitle: 'Todas as máquinas conectadas via servidor',
      icon: Icons.cloud_sync_rounded,
      builder: (_) => const ServidorNuvemScreen(),
    ),
    _ModuleItem(
      group: 'SEGURANÇA',
      title: 'Usuários',
      subtitle: 'Operadores, perfis e permissões',
      icon: Icons.admin_panel_settings_rounded,
      builder: (_) => const UsuariosScreen(),
      moduleKey: 'usuarios',
    ),
    _ModuleItem(
      group: 'SEGURANÇA',
      title: 'Auditoria',
      subtitle: 'Logs, trilha LGPD e eventos',
      icon: Icons.manage_search_rounded,
      builder: (_) => const AuditoriaScreen(),
      moduleKey: 'auditoria',
    ),
  ];

  int _selectedIndex = 0;

  void _selectModule(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _selectModuleByTitle(String title) {
    final int index =
        _modules.indexWhere((_ModuleItem item) => item.title == title);
    if (index >= 0) {
      _selectModule(index);
    }
  }

  Future<void> _exitSystem() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D2033),
          title: const Text(
            'Sair do sistema',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Deseja encerrar a sessão atual do KRISTAL LABORATORIAL?',
            style: TextStyle(color: Color(0xFFB7D7F1)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ModuleItem selected = _modules[_selectedIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF06111D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF142B42),
        elevation: 0,
        title: const Text(
          AppConstants.developerCredit,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: <Widget>[
          const Center(
            child: Text(
              'Super Usuário • SUPER_USUARIO',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          IconButton(
            tooltip: 'Sair do sistema',
            onPressed: _exitSystem,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: <Widget>[
          _Sidebar(
            modules: _modules,
            selectedIndex: _selectedIndex,
            onSelected: _selectModule,
          ),
          Expanded(
            child: selected.builder(context),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.modules,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ModuleItem> modules;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final List<String> groups = modules
        .map((_ModuleItem item) => item.group)
        .toSet()
        .toList(growable: false);

    return Container(
      width: 268,
      decoration: const BoxDecoration(
        color: Color(0xFF0D2033),
        border: Border(
          right: BorderSide(color: Color(0xFF244B6D)),
        ),
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              children: <Widget>[
                for (final String group in groups) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Text(
                      group,
                      style: const TextStyle(
                        color: Color(0xFF73D7FF),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  for (int i = 0; i < modules.length; i++)
                    if (modules[i].group == group)
                      _SidebarTile(
                        module: modules[i],
                        selected: selectedIndex == i,
                        onTap: () => onSelected(i),
                      ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF244B6D)),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFFC857),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.module,
    required this.selected,
    required this.onTap,
  });

  final _ModuleItem module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1F527C) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(
          module.icon,
          color: const Color(0xFFB7D7F1),
          size: 22,
        ),
        title: Text(
          module.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          module.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFB7D7F1),
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent({required this.onOpenModule});

  final ValueChanged<String> onOpenModule;

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  final KristalOperationalStoreService _store =
      KristalOperationalStoreService.instance;

  Map<String, int> _counts = <String, int>{};

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final Map<String, int> counts = await _store.countsByModule(<String>[
      'pacientes',
      'atendimento',
      'amostras',
      'resultados',
      'equipamentos',
      'estoque',
      'controle_qualidade',
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _counts = counts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF06111D),
      child: Column(
        children: <Widget>[
          const _InstitutionHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: Column(
                children: <Widget>[
                  _WelcomePanel(onRefresh: _loadCounts),
                  const SizedBox(height: 26),
                  _IndicatorGrid(
                      counts: _counts, onOpenModule: widget.onOpenModule),
                  const SizedBox(height: 26),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      Expanded(flex: 3, child: _SampleFlowPanel()),
                      SizedBox(width: 26),
                      Expanded(flex: 2, child: _AlertsPanel()),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      Expanded(flex: 3, child: _RecentExamTable()),
                      SizedBox(width: 26),
                      Expanded(flex: 2, child: _DistributionPanel()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstitutionHeader extends StatelessWidget {
  const _InstitutionHeader();

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
          Image.asset(
            AppConstants.hmrLogoPath,
            width: 60,
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.local_hospital,
              size: 52,
              color: Color(0xFF73D7FF),
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppConstants.institutionName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: Color(0xFFB7D7F1),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const _ProtectedBadge(),
        ],
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: <Widget>[
          const _IconBox(
            icon: Icons.monitor_heart_rounded,
            color: Color(0xFF73D7FF),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'DASHBOARD OPERACIONAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Bem-vindo, Super Usuário • Sessão protegida • Indicadores carregados dos módulos locais',
                  style: TextStyle(
                    color: Color(0xFFB7D7F1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }
}

class _IndicatorGrid extends StatelessWidget {
  const _IndicatorGrid({
    required this.counts,
    required this.onOpenModule,
  });

  final Map<String, int> counts;
  final ValueChanged<String> onOpenModule;

  @override
  Widget build(BuildContext context) {
    final List<_IndicatorData> indicators = <_IndicatorData>[
      _IndicatorData('Pacientes', '${counts['pacientes'] ?? 0}',
          Icons.groups_rounded, const Color(0xFF4EA3FF), 'Pacientes'),
      _IndicatorData('Atendimentos', '${counts['atendimento'] ?? 0}',
          Icons.assignment_rounded, const Color(0xFF73D7FF), 'Atendimento'),
      _IndicatorData('Amostras', '${counts['amostras'] ?? 0}',
          Icons.qr_code_2_rounded, const Color(0xFFFFC857), 'Amostras'),
      _IndicatorData('Resultados', '${counts['resultados'] ?? 0}',
          Icons.fact_check_rounded, const Color(0xFF34D399), 'Resultados'),
      _IndicatorData('Exames', 'Catálogo', Icons.biotech_rounded,
          const Color(0xFF4EA3FF), 'Catálogo de Exames'),
      _IndicatorData(
          'Equipamentos',
          '${counts['equipamentos'] ?? 0}',
          Icons.precision_manufacturing_rounded,
          const Color(0xFFBBA7FF),
          'Equipamentos'),
      _IndicatorData('Estoque', '${counts['estoque'] ?? 0}',
          Icons.inventory_2_rounded, const Color(0xFFFFB86B), 'Estoque'),
      _IndicatorData(
          'CQ',
          '${counts['controle_qualidade'] ?? 0}',
          Icons.verified_rounded,
          const Color(0xFF9CCBFF),
          'Controle de Qualidade'),
    ];

    return GridView.builder(
      itemCount: indicators.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 112,
        mainAxisSpacing: 26,
        crossAxisSpacing: 26,
      ),
      itemBuilder: (BuildContext context, int index) {
        final _IndicatorData item = indicators[index];

        return InkWell(
          onTap: () => onOpenModule(item.target),
          child: _Panel(
            child: Row(
              children: <Widget>[
                _IconBox(icon: item.icon, color: item.color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.value,
                        style: TextStyle(
                          color: item.color,
                          fontSize: item.value.length > 4 ? 16 : 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProtectedBadge extends StatelessWidget {
  const _ProtectedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2033),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2D91D0)),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.verified_user_rounded, color: Color(0xFF73D7FF), size: 18),
          SizedBox(width: 8),
          Text(
            'Sessão protegida',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SampleFlowPanel extends StatelessWidget {
  const _SampleFlowPanel();

  @override
  Widget build(BuildContext context) {
    const List<_FlowStep> steps = <_FlowStep>[
      _FlowStep('Pedidos', Icons.assignment_rounded),
      _FlowStep('Amostras', Icons.qr_code_2_rounded),
      _FlowStep('Análise', Icons.science_rounded),
      _FlowStep('Laudos', Icons.picture_as_pdf_rounded),
      _FlowStep('Histórico', Icons.archive_rounded),
    ];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Fluxo operacional das amostras',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              for (int i = 0; i < steps.length; i++) ...<Widget>[
                Expanded(
                  child: Container(
                    height: 114,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2B49),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF2373AA)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          steps[i].icon,
                          color: const Color(0xFF73D7FF),
                          size: 28,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          steps[i].label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '0',
                          style: TextStyle(
                            color: Color(0xFF4EA3FF),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < steps.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF73D7FF),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          Text(
            'Alertas críticos e validação',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 18),
          _AlertLine('Resultados pendentes', '0', Icons.warning_rounded,
              Color(0xFFFFC857)),
          _AlertLine('Equipamentos configurados', '0',
              Icons.precision_manufacturing_rounded, Color(0xFF73D7FF)),
          _AlertLine('Itens em estoque', '0', Icons.inventory_2_rounded,
              Color(0xFF34D399)),
          Divider(color: Color(0xFF244B6D), height: 30),
          Text(
            'Status operacional: sistema pronto para rotina local, portal, laudos, exportações e conexão com equipamentos via servidor.',
            style: TextStyle(color: Color(0xFFB7D7F1), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _RecentExamTable extends StatelessWidget {
  const _RecentExamTable();

  @override
  Widget build(BuildContext context) {
    const List<List<String>> rows = <List<String>>[
      <String>['GLI', 'Glicose, Dosagem de', 'Catálogo', 'Ativo'],
      <String>['HEM', 'Hemograma completo', 'Catálogo', 'Ativo'],
      <String>['URE', 'Ureia, dosagem de', 'Catálogo', 'Ativo'],
      <String>['CRE', 'Creatinina, dosagem de', 'Catálogo', 'Ativo'],
      <String>['TSH', 'Hormônio Tireoestimulante', 'Catálogo', 'Ativo'],
    ];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Atividade recente por exame',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 14),
          Table(
            columnWidths: const <int, TableColumnWidth>{
              0: FixedColumnWidth(90),
              1: FlexColumnWidth(),
              2: FixedColumnWidth(100),
              3: FixedColumnWidth(100),
            },
            children: <TableRow>[
              const TableRow(
                decoration: BoxDecoration(color: Color(0xFF12355A)),
                children: <Widget>[
                  _Cell('MNE', header: true),
                  _Cell('Exame', header: true),
                  _Cell('Origem', header: true),
                  _Cell('Status', header: true),
                ],
              ),
              for (final List<String> row in rows)
                TableRow(
                  decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Color(0xFF334B63))),
                  ),
                  children: <Widget>[
                    _Cell(row[0], accent: true),
                    _Cell(row[1]),
                    _Cell(row[2]),
                    _Cell(row[3], bold: true),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistributionPanel extends StatelessWidget {
  const _DistributionPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Distribuição operacional',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 28,
                color: const Color(0xFFBBA7FF),
                backgroundColor: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 12,
            runSpacing: 10,
            children: <Widget>[
              _Legend('Pacientes', Color(0xFF4EA3FF)),
              _Legend('Pedidos', Color(0xFF73D7FF)),
              _Legend('Amostras', Color(0xFFFFC857)),
              _Legend('Resultados', Color(0xFF34D399)),
              _Legend('Exames', Color(0xFFBBA7FF)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2033),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.85)),
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }
}

class _AlertLine extends StatelessWidget {
  const _AlertLine(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
    this.text, {
    this.header = false,
    this.accent = false,
    this.bold = false,
  });

  final String text;
  final bool header;
  final bool accent;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(
          color: accent ? const Color(0xFF73D7FF) : Colors.white,
          fontWeight:
              header || bold || accent ? FontWeight.w900 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

class _IndicatorData {
  const _IndicatorData(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.target,
  );

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String target;
}

class _FlowStep {
  const _FlowStep(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _ModuleItem {
  const _ModuleItem({
    required this.group,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
    this.moduleKey,
  });

  final String group;
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
  final String? moduleKey;
}
