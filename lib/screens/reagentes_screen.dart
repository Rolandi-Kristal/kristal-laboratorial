import 'package:flutter/material.dart';
import '../widgets/simple_crud_screen.dart';
class ReagentesScreen extends StatelessWidget { const ReagentesScreen({super.key}); @override Widget build(BuildContext context)=> const SimpleCrudScreen(title:'Reagentes e Lotes', table:'reagentes', fields:['id','nome','fabricante','lote','validade','abertoEm','quantidade','status'], visibleFields:['nome','lote','validade']); }
