import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kristal_laboratorial/services/windows_data_protection_service.dart';

void main() {
  group('WindowsDataProtectionService', () {
    test('rejeita segredo abaixo do tamanho mínimo', () {
      expect(
        () => WindowsDataProtectionService.protectMachineSecret('curta'),
        throwsA(isA<WindowsDataProtectionException>()),
      );
    });

    test('rejeita formato sem prefixo DPAPI', () {
      expect(
        () => WindowsDataProtectionService.decryptMachineSecret('invalido'),
        throwsA(isA<WindowsDataProtectionException>()),
      );
    });

    test('rejeita Base64 corrompido', () {
      expect(
        () => WindowsDataProtectionService.decryptMachineSecret(
          '%%%',
        ),
        throwsA(isA<WindowsDataProtectionException>()),
      );
    });

    test(
      'protege e recupera segredo apenas na mesma máquina',
      () {
        const String secret = 'teste-corporativo-com-mais-de-32-caracteres';
        final String protectedValue =
            WindowsDataProtectionService.protectMachineSecret(secret);
        expect(
          protectedValue,
          startsWith(WindowsDataProtectionService.prefix),
        );
        expect(
          WindowsDataProtectionService.decryptMachineSecret(protectedValue),
          secret,
        );
      },
      skip: !Platform.isWindows,
    );
  });
}
