import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kristal_laboratorial/core/app_constants.dart';
import 'package:kristal_laboratorial/security/kristal_crypto_service.dart';
import 'package:kristal_laboratorial/services/windows_data_protection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AES-GCM preserva texto Unicode e usa nonce aleatório', () async {
    const String value = 'Paciente • valor 5.30 • Não detectado';
    final String first =
        await KristalCryptoService.instance.encryptString(value);
    final String second =
        await KristalCryptoService.instance.encryptString(value);

    expect(first, startsWith(AppConstants.cryptoPrefix));
    expect(second, startsWith(AppConstants.cryptoPrefix));
    expect(first, isNot(second));
    expect(await KristalCryptoService.instance.decryptString(first), value);
    expect(await KristalCryptoService.instance.decryptString(second), value);
  });

  test('AES-GCM rejeita ciphertext adulterado', () async {
    final String encrypted =
        await KristalCryptoService.instance.encryptString('resultado íntegro');
    final String tampered = '${encrypted.substring(0, encrypted.length - 2)}AA';
    expect(
      () => KristalCryptoService.instance.decryptString(tampered),
      throwsA(anything),
    );
  });

  test('lê campo XOR legado somente para migração', () async {
    const String value = 'registro legado';
    final Uint8List input = Uint8List.fromList(utf8.encode(value));
    final List<int> key =
        sha256.convert(utf8.encode(AppConstants.masterPassword)).bytes;
    final Uint8List output = Uint8List(input.length);
    for (int index = 0; index < input.length; index++) {
      output[index] = input[index] ^ key[index % key.length];
    }
    final String legacy =
        '${AppConstants.cryptoPrefix}${base64UrlEncode(output)}';
    expect(await KristalCryptoService.instance.decryptString(legacy), value);
  });

  test(
    'arquivo de chave AES fica protegido por DPAPI',
    () async {
      await KristalCryptoService.instance
          .encryptString('forçar criação da chave');
      final Directory support = Directory(AppConstants.appDataDirectoryPath());
      final File keyFile = File(
        support.path + Platform.pathSeparator + AppConstants.masterKeyFile,
      );
      expect(await keyFile.exists(), isTrue);
      expect(
        (await keyFile.readAsString()).trim(),
        startsWith(WindowsDataProtectionService.prefix),
      );
    },
    skip: !Platform.isWindows,
  );
}
