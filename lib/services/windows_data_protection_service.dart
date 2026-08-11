import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowsDataProtectionException implements Exception {
  const WindowsDataProtectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WindowsDataProtectionService {
  WindowsDataProtectionService._();

  static const String prefix = 'DPAPI_LOCAL_MACHINE_V1:';
  static const int _cryptProtectUiForbidden = 0x1;
  static const int _cryptProtectLocalMachine = 0x4;

  static String protectMachineSecret(String clearValue) {
    if (!Platform.isWindows) {
      throw const WindowsDataProtectionException(
        'A credencial corporativa requer Windows DPAPI.',
      );
    }
    if (clearValue.trim().length < 32) {
      throw const WindowsDataProtectionException(
        'Credencial corporativa não atende ao tamanho mínimo.',
      );
    }

    final Uint8List clearBytes = Uint8List.fromList(utf8.encode(clearValue));
    final Pointer<Uint8> inputBytes = calloc<Uint8>(clearBytes.length);
    final Pointer<CRYPT_INTEGER_BLOB> input = calloc<CRYPT_INTEGER_BLOB>();
    final Pointer<CRYPT_INTEGER_BLOB> output = calloc<CRYPT_INTEGER_BLOB>();
    inputBytes.asTypedList(clearBytes.length).setAll(0, clearBytes);
    input.ref
      ..cbData = clearBytes.length
      ..pbData = inputBytes;

    try {
      final int success = CryptProtectData(
        input,
        nullptr.cast<Utf16>(),
        nullptr.cast<CRYPT_INTEGER_BLOB>(),
        nullptr,
        nullptr.cast<CRYPTPROTECT_PROMPTSTRUCT>(),
        _cryptProtectUiForbidden | _cryptProtectLocalMachine,
        output,
      );
      if (success == 0) {
        throw WindowsDataProtectionException(
          'Windows DPAPI não protegeu a credencial. Código: ${GetLastError()}.',
        );
      }
      if (output.ref.cbData <= 0 || output.ref.pbData.address == 0) {
        throw const WindowsDataProtectionException(
          'Windows DPAPI retornou um blob vazio.',
        );
      }
      final Uint8List protectedBytes = Uint8List.fromList(
        output.ref.pbData.asTypedList(output.ref.cbData),
      );
      return prefix + base64Encode(protectedBytes);
    } finally {
      clearBytes.fillRange(0, clearBytes.length, 0);
      if (output.ref.pbData.address != 0) {
        LocalFree(output.ref.pbData);
      }
      calloc
        ..free(output)
        ..free(input)
        ..free(inputBytes);
    }
  }

  static String decryptMachineSecret(String protectedValue) {
    if (!Platform.isWindows) {
      throw const WindowsDataProtectionException(
        'A credencial corporativa requer Windows DPAPI.',
      );
    }
    if (!protectedValue.startsWith(prefix)) {
      throw const WindowsDataProtectionException(
        'Formato da credencial corporativa inválido.',
      );
    }

    final Uint8List encrypted;
    try {
      encrypted = base64Decode(protectedValue.substring(prefix.length));
    } on FormatException {
      throw const WindowsDataProtectionException(
        'Credencial corporativa corrompida.',
      );
    }
    if (encrypted.isEmpty) {
      throw const WindowsDataProtectionException(
        'Credencial corporativa vazia.',
      );
    }

    final Pointer<Uint8> inputBytes = calloc<Uint8>(encrypted.length);
    final Pointer<CRYPT_INTEGER_BLOB> input = calloc<CRYPT_INTEGER_BLOB>();
    final Pointer<CRYPT_INTEGER_BLOB> output = calloc<CRYPT_INTEGER_BLOB>();
    inputBytes.asTypedList(encrypted.length).setAll(0, encrypted);
    input.ref
      ..cbData = encrypted.length
      ..pbData = inputBytes;

    try {
      final int success = CryptUnprotectData(
        input,
        nullptr.cast<Pointer<Utf16>>(),
        nullptr.cast<CRYPT_INTEGER_BLOB>(),
        nullptr,
        nullptr.cast<CRYPTPROTECT_PROMPTSTRUCT>(),
        _cryptProtectUiForbidden,
        output,
      );
      if (success == 0) {
        throw WindowsDataProtectionException(
          'Windows DPAPI recusou a credencial corporativa. Código: ${GetLastError()}.',
        );
      }
      if (output.ref.cbData <= 0 || output.ref.pbData.address == 0) {
        throw const WindowsDataProtectionException(
          'Windows DPAPI retornou uma credencial vazia.',
        );
      }
      final Uint8List clearBytes = Uint8List.fromList(
        output.ref.pbData.asTypedList(output.ref.cbData),
      );
      final String clearValue;
      try {
        clearValue = utf8.decode(clearBytes);
      } on FormatException {
        throw const WindowsDataProtectionException(
          'Credencial corporativa descriptografada inválida.',
        );
      }
      if (clearValue.trim().length < 32) {
        throw const WindowsDataProtectionException(
          'Credencial corporativa não atende ao tamanho mínimo.',
        );
      }
      return clearValue;
    } finally {
      if (output.ref.pbData.address != 0) {
        LocalFree(output.ref.pbData);
      }
      calloc
        ..free(output)
        ..free(input)
        ..free(inputBytes);
    }
  }
}
