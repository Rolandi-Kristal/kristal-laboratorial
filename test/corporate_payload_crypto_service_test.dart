import 'package:flutter_test/flutter_test.dart';
import 'package:kristal_laboratorial/services/corporate_payload_crypto_service.dart';

void main() {
  const String key = 'api-key-corporativa-kristal-com-mais-de-32-caracteres';
  const String otherKey = 'outra-chave-corporativa-com-mais-de-32-caracteres';

  test('sela e abre payload corporativo sem alterar campos', () async {
    final Map<String, Object?> original = <String, Object?>{
      'id': 'PAC-1',
      'nome': 'Paciente',
      'valor': '5.30',
      'observacao': 'Não detectado',
    };
    final Map<String, Object?> sealed =
        await CorporatePayloadCryptoService.instance.seal(
      recordId: 'PAC-1',
      payload: original,
      apiKey: key,
    );

    expect(sealed['id'], 'PAC-1');
    expect(sealed['_sealed'], startsWith(CorporatePayloadCryptoService.prefix));
    expect(sealed.containsKey('nome'), isFalse);
    expect(
      await CorporatePayloadCryptoService.instance.open(
        recordId: 'PAC-1',
        payload: sealed,
        apiKey: key,
      ),
      original,
    );
  });

  test('recusa chave corporativa diferente', () async {
    final Map<String, Object?> sealed =
        await CorporatePayloadCryptoService.instance.seal(
      recordId: 'RES-1',
      payload: const <String, Object?>{'id': 'RES-1', 'valor': 'NEGATIVO'},
      apiKey: key,
    );
    expect(
      () => CorporatePayloadCryptoService.instance.open(
        recordId: 'RES-1',
        payload: sealed,
        apiKey: otherKey,
      ),
      throwsA(anything),
    );
  });

  test('recusa ID divergente e chave curta', () async {
    expect(
      () => CorporatePayloadCryptoService.instance.seal(
        recordId: 'PAC-2',
        payload: const <String, Object?>{'id': 'PAC-3'},
        apiKey: key,
      ),
      throwsArgumentError,
    );
    expect(
      () => CorporatePayloadCryptoService.instance.seal(
        recordId: 'PAC-2',
        payload: const <String, Object?>{'id': 'PAC-2'},
        apiKey: 'curta',
      ),
      throwsArgumentError,
    );
  });

  test('aceita payload inicial não selado para migração do servidor', () async {
    const Map<String, Object?> plain = <String, Object?>{
      'id': 'EXA-1',
      'codigo': 'GLI',
    };
    expect(
      await CorporatePayloadCryptoService.instance.open(
        recordId: 'EXA-1',
        payload: plain,
        apiKey: key,
      ),
      plain,
    );
  });
}
