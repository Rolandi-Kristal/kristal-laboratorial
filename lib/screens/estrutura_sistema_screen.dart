import 'package:flutter/material.dart';

class EstruturaSistemaScreen extends StatelessWidget { const EstruturaSistemaScreen({super.key}); @override Widget build(BuildContext context)=>Scaffold(appBar: AppBar(title: const Text('Estrutura do Sistema')), body: ListView(padding: const EdgeInsets.all(18), children: const [
  Card(child: ListTile(title: Text('Fluxo laboratorial'), subtitle: Text('Paciente → Pedido → Exame → Etiqueta → Amostra → Resultado → Laudo PDF → Portal do Paciente'))),
  Card(child: ListTile(title: Text('Etiquetas'), subtitle: Text('Código manual, leitura laser/USB, imagem de etiqueta/amostra, bloqueio de duplicidade e auditoria.'))),
  Card(child: ListTile(title: Text('Equipamentos'), subtitle: Text('Perfis para Audmax, BC5380, BH-5390, BS360E, Coagmaster, LabmaxPremium e Urivision720 por ASTM/HL7/CSV/Serial/TCP.'))),
  Card(child: ListTile(title: Text('Backup'), subtitle: Text('Manual e automático, arquivo criptografado, restauração controlada por perfil.'))),
  Card(child: ListTile(title: Text('Segurança'), subtitle: Text('Superusuário, administrador, permissões, auditoria, mascaramento LGPD e hash de laudo.'))),
  Card(child: ListTile(title: Text('Portal Web'), subtitle: Text('Paciente baixa/imprime laudos liberados por CPF + token quando configurado.'))),
])); }
