import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kristal_laboratorial/services/server_config_service.dart';
import 'package:kristal_laboratorial/services/windows_data_protection_service.dart';

void main() {
  group('ServerConfigService.buildPersistedPayload', () {
    final ServerConfigService service = ServerConfigService.instance;

    test('não persiste chave quando o segredo está vazio', () {
      final Map<String, Object> payload =
          service.buildPersistedPayload(ServerConfig.defaults);

      expect(payload['cloudApiToken'], '');
      expect(payload['nuvemApiKey'], '');
      expect(payload.containsKey('apiKeyProtegida'), isFalse);
    });

    test(
      'protege a chave e remove todas as cópias em texto legível',
      () {
        const String secret = 'api-key-producao-com-mais-de-32-caracteres';
        final Map<String, Object> payload = service.buildPersistedPayload(
          ServerConfig.defaults.copyWith(
            cloudApiToken: secret,
            nuvemApiKey: secret,
          ),
        );

        expect(payload['cloudApiToken'], '');
        expect(payload['nuvemApiKey'], '');
        expect(payload.values, isNot(contains(secret)));
        expect(
          payload['apiKeyProtegida'],
          isA<String>().having(
            (String value) => value,
            'prefixo',
            startsWith(WindowsDataProtectionService.prefix),
          ),
        );
      },
      skip: !Platform.isWindows,
    );

    test(
      'prioriza cloudApiToken quando os dois campos divergem',
      () {
        const String primary = 'chave-principal-com-mais-de-32-caracteres';
        const String legacy = 'chave-legada-com-mais-de-32-caracteres-xyz';
        final Map<String, Object> payload = service.buildPersistedPayload(
          ServerConfig.defaults.copyWith(
            cloudApiToken: primary,
            nuvemApiKey: legacy,
          ),
        );

        expect(
          WindowsDataProtectionService.decryptMachineSecret(
            payload['apiKeyProtegida']! as String,
          ),
          primary,
        );
      },
      skip: !Platform.isWindows,
    );

    test('rejeita chave abaixo do comprimento mínimo', () {
      expect(
        () => service.buildPersistedPayload(
          ServerConfig.defaults.copyWith(cloudApiToken: 'curta'),
        ),
        throwsA(isA<WindowsDataProtectionException>()),
      );
    });
  });
}
