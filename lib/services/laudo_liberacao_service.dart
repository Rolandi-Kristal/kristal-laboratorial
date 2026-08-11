import 'audit_service.dart';
import 'auth_service.dart';
import 'lab_repository.dart';
import 'laudo_hash_service.dart';
import 'pdf_laudo_service.dart';

class LaudoLiberacaoService {
  LaudoLiberacaoService._();

  static final LaudoLiberacaoService instance = LaudoLiberacaoService._();

  final LabRepository _repo = LabRepository();

  Future<void> liberarLaudo({
    required AuthSession session,
    required String laudoId,
  }) async {
    if (!(session.isSuperUser ||
        session.perfil.toUpperCase() == 'RESPONSAVEL_TECNICO')) {
      throw StateError(
        'Somente Superusuário ou Responsável Técnico pode liberar laudo.',
      );
    }

    final Map<String, dynamic>? laudo = await _repo.findById('laudos', laudoId);

    if (laudo == null) {
      throw StateError('Laudo não encontrado.');
    }

    final Map<String, dynamic> atualizado = Map<String, dynamic>.from(laudo);
    atualizado['status'] = 'LIBERADO';
    atualizado['liberadoEm'] = DateTime.now().toIso8601String();
    atualizado['hash'] = LaudoHashService.gerarHash(atualizado);
    atualizado['arquivoPath'] =
        await PdfLaudoService.instance.salvarLaudoPdf(atualizado);
    atualizado['hash'] = LaudoHashService.gerarHash(atualizado);

    await _repo.upsert('laudos', atualizado);

    await AuditService.instance.registrar(
      usuario: session.login,
      acao: 'LIBERAR_LAUDO',
      tabela: 'laudos',
      registroId: laudoId,
      detalhes: 'Laudo liberado com hash de validação.',
    );
  }

  Future<void> cancelarLaudo({
    required AuthSession session,
    required String laudoId,
    required String motivo,
  }) async {
    if (!session.isSuperUser) {
      throw StateError('Somente Superusuário pode cancelar laudo.');
    }

    final Map<String, dynamic>? laudo = await _repo.findById('laudos', laudoId);

    if (laudo == null) {
      throw StateError('Laudo não encontrado.');
    }

    final Map<String, dynamic> atualizado = Map<String, dynamic>.from(laudo);
    atualizado['status'] = 'CANCELADO';
    atualizado['observacao'] = motivo;
    atualizado['hash'] = LaudoHashService.gerarHash(atualizado);
    atualizado['arquivoPath'] =
        await PdfLaudoService.instance.salvarLaudoPdf(atualizado);
    atualizado['hash'] = LaudoHashService.gerarHash(atualizado);

    await _repo.upsert('laudos', atualizado);

    await AuditService.instance.registrar(
      usuario: session.login,
      acao: 'CANCELAR_LAUDO',
      tabela: 'laudos',
      registroId: laudoId,
      detalhes: motivo,
    );
  }
}
