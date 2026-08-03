import 'lab_repository.dart';
class CalibracaoService { final _repo=LabRepository(); Future<List<Map<String,dynamic>>> listar()=>_repo.all('calibracoes'); Future<void> salvar(Map<String,dynamic> m)=>_repo.upsert('calibracoes', m); }
