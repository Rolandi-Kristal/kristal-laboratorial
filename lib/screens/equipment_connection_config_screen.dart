import 'package:flutter/material.dart';
import '../models/equipment_connection_config.dart';
import '../services/auth_service.dart';
import '../services/equipment_connection_service.dart';

class EquipmentConnectionConfigScreen extends StatefulWidget {
  final AuthSession session;
  const EquipmentConnectionConfigScreen({super.key, required this.session});
  @override State<EquipmentConnectionConfigScreen> createState() => _EquipmentConnectionConfigScreenState();
}

class _EquipmentConnectionConfigScreenState extends State<EquipmentConnectionConfigScreen> {
  final EquipmentConnectionService service = EquipmentConnectionService.instance;
  final TextEditingController filtro = TextEditingController();
  List<EquipmentConnectionConfig> todos = <EquipmentConnectionConfig>[];
  List<EquipmentConnectionConfig> filtrados = <EquipmentConnectionConfig>[];
  bool loading = true;
  String status = 'Carregando comunicação dos equipamentos...';
  bool get canEdit => widget.session.isAdmin;

  @override void initState(){ super.initState(); filtro.addListener(_aplicarFiltro); _carregar(); }
  @override void dispose(){ filtro.dispose(); super.dispose(); }

  Future<void> _carregar() async {
    setState(() { loading = true; status = 'Carregando comunicação dos equipamentos...'; });
    try {
      final rows = await service.listar();
      if (!mounted) return;
      setState(() { todos = rows; loading = false; status = '${rows.length} configuração(ões) carregada(s).'; });
      _aplicarFiltro();
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; status = 'Erro ao carregar. Verifique se a tabela equipment_connections foi criada no DatabaseService. Detalhe: $e'; });
    }
  }

  void _aplicarFiltro(){
    final q = filtro.text.trim().toLowerCase();
    filtrados = q.isEmpty ? List.of(todos) : todos.where((i) => [i.nome,i.fabricante,i.modelo,i.setor,i.tipoConexao,i.protocolo,i.ip,i.portaCom].join(' ').toLowerCase().contains(q)).toList();
    if (mounted) setState((){});
  }

  Future<void> _novo() => _abrirFormulario(EquipmentConnectionConfig.empty());
  Future<void> _editar(EquipmentConnectionConfig config) => _abrirFormulario(config);

  Future<void> _abrirFormulario(EquipmentConnectionConfig original) async {
    final nome = TextEditingController(text: original.nome);
    final fabricante = TextEditingController(text: original.fabricante);
    final modelo = TextEditingController(text: original.modelo);
    final setor = TextEditingController(text: original.setor);
    final ip = TextEditingController(text: original.ip);
    final portaTcp = TextEditingController(text: original.portaTcp);
    final portaCom = TextEditingController(text: original.portaCom);
    final baudRate = TextEditingController(text: original.baudRate);
    final dataBits = TextEditingController(text: original.dataBits);
    final stopBits = TextEditingController(text: original.stopBits);
    final pastaEntrada = TextEditingController(text: original.pastaEntrada);
    final pastaSaida = TextEditingController(text: original.pastaSaida);
    final extensoes = TextEditingController(text: original.extensoesMonitoradas);
    final driver = TextEditingController(text: original.driverPath);
    final executavel = TextEditingController(text: original.executavelPath);
    final timeout = TextEditingController(text: original.timeoutSegundos);
    final observacao = TextEditingController(text: original.observacao);
    String tipoConexao = original.tipoConexao;
    String protocolo = original.protocolo;
    String paridade = original.paridade;
    String handshake = original.handshake;
    bool ativo = original.isAtivo;

    final ok = await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      Widget field(TextEditingController c, String l, IconData i, {TextInputType? k, int max=1}) => SizedBox(width: 330, child: TextField(controller: c, keyboardType: k, maxLines: max, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), border: const OutlineInputBorder())));
      return AlertDialog(
        title: const Text('Configuração de comunicação'),
        content: SizedBox(width: 760, child: SingleChildScrollView(child: Wrap(spacing: 12, runSpacing: 12, children: [
          field(nome,'Nome do equipamento',Icons.biotech), field(fabricante,'Fabricante',Icons.factory), field(modelo,'Modelo',Icons.precision_manufacturing), field(setor,'Setor',Icons.apartment),
          SizedBox(width:330, child: DropdownButtonFormField<String>(value: tipoConexao, decoration: const InputDecoration(labelText:'Tipo de conexão', prefixIcon: Icon(Icons.settings_input_component), border: OutlineInputBorder()), items: const [DropdownMenuItem(value:'TCP_IP', child: Text('TCP/IP - Rede')), DropdownMenuItem(value:'SERIAL_USB', child: Text('Serial / USB-COM')), DropdownMenuItem(value:'PASTA_ARQUIVO', child: Text('Pasta / Arquivo')), DropdownMenuItem(value:'DRIVER_EXTERNO', child: Text('Driver / Interface externa'))], onChanged: (v){ if(v!=null) setDialogState(()=>tipoConexao=v); })),
          SizedBox(width:330, child: DropdownButtonFormField<String>(value: protocolo, decoration: const InputDecoration(labelText:'Protocolo', prefixIcon: Icon(Icons.hub), border: OutlineInputBorder()), items: const [DropdownMenuItem(value:'ASTM', child: Text('ASTM')), DropdownMenuItem(value:'HL7', child: Text('HL7')), DropdownMenuItem(value:'CSV', child: Text('CSV')), DropdownMenuItem(value:'TXT', child: Text('TXT')), DropdownMenuItem(value:'XML', child: Text('XML')), DropdownMenuItem(value:'PROPRIETARIO', child: Text('Proprietário'))], onChanged: (v){ if(v!=null) setDialogState(()=>protocolo=v); })),
          if(tipoConexao=='TCP_IP') ...[field(ip,'IP do equipamento',Icons.language), field(portaTcp,'Porta TCP',Icons.settings_ethernet,k:TextInputType.number), field(timeout,'Timeout em segundos',Icons.timer,k:TextInputType.number)],
          if(tipoConexao=='SERIAL_USB') ...[field(portaCom,'Porta COM',Icons.cable), field(baudRate,'Baud rate',Icons.speed,k:TextInputType.number), field(dataBits,'Data bits',Icons.pin,k:TextInputType.number), field(stopBits,'Stop bits',Icons.stop,k:TextInputType.number), SizedBox(width:330, child: DropdownButtonFormField<String>(value: paridade, decoration: const InputDecoration(labelText:'Paridade', prefixIcon: Icon(Icons.compare_arrows), border: OutlineInputBorder()), items: const [DropdownMenuItem(value:'NONE', child: Text('NONE')), DropdownMenuItem(value:'ODD', child: Text('ODD')), DropdownMenuItem(value:'EVEN', child: Text('EVEN'))], onChanged:(v){if(v!=null)setDialogState(()=>paridade=v); })), SizedBox(width:330, child: DropdownButtonFormField<String>(value: handshake, decoration: const InputDecoration(labelText:'Handshake', prefixIcon: Icon(Icons.handshake), border: OutlineInputBorder()), items: const [DropdownMenuItem(value:'NONE', child: Text('NONE')), DropdownMenuItem(value:'RTS_CTS', child: Text('RTS/CTS')), DropdownMenuItem(value:'XON_XOFF', child: Text('XON/XOFF'))], onChanged:(v){if(v!=null)setDialogState(()=>handshake=v); }))],
          if(tipoConexao=='PASTA_ARQUIVO') ...[field(pastaEntrada,'Pasta de entrada',Icons.folder_open), field(pastaSaida,'Pasta de saída/processados',Icons.folder_copy), field(extensoes,'Extensões monitoradas',Icons.file_copy)],
          if(tipoConexao=='DRIVER_EXTERNO') ...[field(driver,'Arquivo driver .drv/.dll',Icons.memory), field(executavel,'Executável/interface externa',Icons.terminal)],
          SizedBox(width:330, child: SwitchListTile(title: const Text('Ativo'), value: ativo, onChanged:(v)=>setDialogState(()=>ativo=v))),
          SizedBox(width:672, child: TextField(controller: observacao, maxLines:3, decoration: const InputDecoration(labelText:'Observações técnicas', prefixIcon: Icon(Icons.notes), border: OutlineInputBorder()))),
        ]))),
        actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false), child: const Text('Cancelar')), ElevatedButton.icon(onPressed:()=>Navigator.pop(ctx,true), icon: const Icon(Icons.save), label: const Text('Salvar'))],
      );
    }));
    if(ok != true) return;
    final now = DateTime.now().toIso8601String();
    final config = original.copyWith(nome:nome.text.trim(), fabricante:fabricante.text.trim(), modelo:modelo.text.trim(), setor:setor.text.trim(), tipoConexao:tipoConexao, protocolo:protocolo, ip:ip.text.trim(), portaTcp:portaTcp.text.trim(), portaCom:portaCom.text.trim(), baudRate:baudRate.text.trim(), dataBits:dataBits.text.trim(), stopBits:stopBits.text.trim(), paridade:paridade, handshake:handshake, pastaEntrada:pastaEntrada.text.trim(), pastaSaida:pastaSaida.text.trim(), extensoesMonitoradas:extensoes.text.trim(), driverPath:driver.text.trim(), executavelPath:executavel.text.trim(), timeoutSegundos:timeout.text.trim().isEmpty?'8':timeout.text.trim(), ativo:ativo?'1':'0', observacao:observacao.text.trim(), criadoEm: original.criadoEm.isEmpty ? now : original.criadoEm, atualizadoEm: now);
    try { await service.salvar(session: widget.session, config: config); await _carregar(); } catch(e){ if(mounted) setState(()=>status='Erro ao salvar: $e'); }
  }

  Future<void> _testar(EquipmentConnectionConfig config) async { final result = await service.testarConexao(config); if(mounted) setState(()=>status=result); }
  Future<void> _enviarWorklistTeste(EquipmentConnectionConfig config) async { final result = await service.enviarWorklist(config: config, sampleId: 'AMOSTRA_TESTE', patientId: 'PACIENTE_TESTE', patientName: 'PACIENTE^TESTE', exames: ['HEMOGRAMA','GLICOSE']); if(mounted) setState(()=>status=result); }
  Future<void> _importarPasta(EquipmentConnectionConfig config) async { try { final parsed = await service.importarResultadosPasta(config); if(mounted) setState(()=>status='${parsed.length} resultado(s) importado(s) da pasta.'); } catch(e){ if(mounted) setState(()=>status='Erro ao importar pasta: $e'); } }
  Future<void> _excluir(EquipmentConnectionConfig config) async { if(!canEdit) return; await service.excluir(session: widget.session, id: config.id); await _carregar(); }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Comunicação dos Equipamentos'), actions: [IconButton(tooltip:'Atualizar', onPressed:_carregar, icon: const Icon(Icons.refresh)), IconButton(tooltip:'Novo equipamento', onPressed: canEdit ? _novo : null, icon: const Icon(Icons.add))]),
    body: Column(children: [
      Card(margin: const EdgeInsets.all(12), child: ListTile(leading: const Icon(Icons.settings_input_component), title: const Text('Configuração por IP, Serial/USB, Pasta ou Driver'), subtitle: Text(canEdit ? 'Acesso administrativo liberado.' : 'Somente Superusuário ou Administrador pode alterar configurações.'))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: TextField(controller:filtro, decoration: const InputDecoration(labelText:'Pesquisar equipamento', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
      Card(margin: const EdgeInsets.all(12), child: Padding(padding: const EdgeInsets.all(12), child: Align(alignment: Alignment.centerLeft, child: Text(status, style: const TextStyle(fontWeight: FontWeight.bold))))),
      Expanded(child: loading ? const Center(child:CircularProgressIndicator()) : filtrados.isEmpty ? const Center(child: Text('Nenhuma comunicação cadastrada.')) : ListView.builder(itemCount: filtrados.length, itemBuilder: (context,index){ final item=filtrados[index]; return Card(child: ListTile(leading: Icon(item.isTcpIp ? Icons.language : item.isSerialUsb ? Icons.cable : item.isPastaArquivo ? Icons.folder : Icons.memory), title: Text('${item.nome.isEmpty ? 'Sem nome' : item.nome} • ${item.tipoConexao}'), subtitle: Text('Modelo: ${item.modelo} | Protocolo: ${item.protocolo} | IP: ${item.ip}:${item.portaTcp} | COM: ${item.portaCom} | Ativo: ${item.isAtivo ? 'SIM' : 'NÃO'}'), onTap:()=>_editar(item), trailing: Wrap(spacing:4, children: [IconButton(tooltip:'Testar conexão', onPressed:()=>_testar(item), icon: const Icon(Icons.check_circle_outline)), IconButton(tooltip:'Enviar worklist teste', onPressed:()=>_enviarWorklistTeste(item), icon: const Icon(Icons.send)), IconButton(tooltip:'Importar pasta', onPressed: item.isPastaArquivo ? ()=>_importarPasta(item) : null, icon: const Icon(Icons.file_upload)), IconButton(tooltip:'Excluir', onPressed: canEdit ? ()=>_excluir(item) : null, icon: const Icon(Icons.delete_outline))]))); })),
    ]),
  );
}
