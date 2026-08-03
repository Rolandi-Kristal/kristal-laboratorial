import 'lab_repository.dart';
class ReagenteService { final _repo=LabRepository(); Future<List<Map<String,dynamic>>> listar()=>_repo.all('reagentes'); Future<void> salvar(Map<String,dynamic> m)=>_repo.upsert('reagentes', m); }
