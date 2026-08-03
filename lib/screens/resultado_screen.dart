import 'package:flutter/material.dart';
import '../widgets/simple_crud_screen.dart';
class ResultadoScreen extends StatelessWidget { const ResultadoScreen({super.key}); @override Widget build(BuildContext context)=> const SimpleCrudScreen(title:'Resultados Laboratoriais', table:'resultados', fields:['id','pedidoId','exameId','amostraId','valor','unidade','referencia','status','critico','liberadoPor','liberadoEm'], visibleFields:['exameId','valor','critico']); }
