import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import '../core/app_constants.dart';
import '../services/windows_data_protection_service.dart';

class KristalCryptoService {
  KristalCryptoService._();

  static final KristalCryptoService instance = KristalCryptoService._();

  final AesGcm _algorithm = AesGcm.with256bits();
  SecretKey? _cachedKey;

  Future<SecretKey> _key() async {
    if (_cachedKey != null) return _cachedKey!;

    final Directory dir = Directory(AppConstants.appDataDirectoryPath());
    if (!await dir.exists()) await dir.create(recursive: true);
    final File keyFile = File(
      dir.path + Platform.pathSeparator + AppConstants.masterKeyFile,
    );

    if (!await keyFile.exists()) {
      final Uint8List keyBytes = Uint8List.fromList(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await _writeProtectedKey(keyFile, keyBytes);
      _cachedKey = SecretKey(keyBytes);
      return _cachedKey!;
    }

    final String stored = (await keyFile.readAsString()).trim();
    final String encoded;
    if (stored.startsWith(WindowsDataProtectionService.prefix)) {
      encoded = WindowsDataProtectionService.decryptMachineSecret(stored);
    } else {
      encoded = stored;
    }
    final Uint8List keyBytes;
    try {
      keyBytes = Uint8List.fromList(base64Decode(encoded));
    } on FormatException {
      throw StateError('Arquivo de chave AES da KRISTAL está corrompido.');
    }
    if (keyBytes.length != 32) {
      throw StateError(
          'A chave AES da KRISTAL deve possuir exatamente 256 bits.');
    }
    if (!stored.startsWith(WindowsDataProtectionService.prefix)) {
      await _writeProtectedKey(keyFile, keyBytes);
    }
    _cachedKey = SecretKey(keyBytes);
    return _cachedKey!;
  }

  Future<void> _writeProtectedKey(File keyFile, Uint8List keyBytes) async {
    if (!Platform.isWindows) {
      throw StateError('A proteção da chave AES requer Windows DPAPI.');
    }
    final String encoded = base64Encode(keyBytes);
    final String protected =
        WindowsDataProtectionService.protectMachineSecret(encoded);
    await keyFile.writeAsString(protected, flush: true);
  }

  Future<String> encryptString(String plainText) async {
    if (plainText.isEmpty) return '';
    if (plainText.startsWith(AppConstants.cryptoPrefix)) return plainText;

    final List<int> nonce = List<int>.generate(
      12,
      (_) => Random.secure().nextInt(256),
    );
    final SecretBox box = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: await _key(),
      nonce: nonce,
    );
    final Map<String, String> payload = <String, String>{
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    };
    return AppConstants.cryptoPrefix +
        base64Encode(utf8.encode(jsonEncode(payload)));
  }

  Future<String> decryptString(String encryptedText) async {
    if (encryptedText.isEmpty) return '';
    if (!encryptedText.startsWith(AppConstants.cryptoPrefix)) {
      return encryptedText;
    }

    final String raw =
        encryptedText.substring(AppConstants.cryptoPrefix.length);
    final Map<String, dynamic>? payload = _decodeAesPayload(raw);
    if (payload == null) {
      return _decryptLegacyXor(raw);
    }
    final String? cipher = payload['c']?.toString();
    final String? nonce = payload['n']?.toString();
    final String? mac = payload['m']?.toString();
    if (cipher == null || nonce == null || mac == null) {
      throw const FormatException('Payload AES-GCM incompleto.');
    }

    final SecretBox box;
    try {
      box = SecretBox(
        base64Decode(cipher),
        nonce: base64Decode(nonce),
        mac: Mac(base64Decode(mac)),
      );
    } on FormatException {
      throw const FormatException('Payload AES-GCM contém Base64 inválido.');
    }
    final List<int> clear = await _algorithm.decrypt(
      box,
      secretKey: await _key(),
    );
    return utf8.decode(clear);
  }

  Map<String, dynamic>? _decodeAesPayload(String raw) {
    try {
      final Object? decoded = jsonDecode(utf8.decode(base64Decode(raw)));
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('n') &&
          decoded.containsKey('c') &&
          decoded.containsKey('m')) {
        return decoded;
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  String _decryptLegacyXor(String raw) {
    final Uint8List input;
    try {
      input = base64Url.decode(raw);
    } on FormatException {
      throw const FormatException(
          'Campo criptografado possui formato inválido.');
    }
    final List<int> key =
        sha256.convert(utf8.encode(AppConstants.masterPassword)).bytes;
    final Uint8List output = Uint8List(input.length);
    for (int index = 0; index < input.length; index++) {
      output[index] = input[index] ^ key[index % key.length];
    }
    try {
      return utf8.decode(output);
    } on FormatException {
      throw const FormatException(
          'Campo legado não pôde ser descriptografado.');
    }
  }

  Future<Map<String, dynamic>> encryptSensitiveFields(
    Map<String, dynamic> data,
  ) async {
    final Map<String, dynamic> output = Map<String, dynamic>.from(data);
    for (final String key in output.keys.toList()) {
      if (_isSensitive(key)) {
        output[key] = await encryptString(output[key]?.toString() ?? '');
      }
    }
    return output;
  }

  Future<Map<String, dynamic>> decryptSensitiveFields(
    Map<String, dynamic> data,
  ) async {
    final Map<String, dynamic> output = Map<String, dynamic>.from(data);
    for (final String key in output.keys.toList()) {
      if (_isSensitive(key)) {
        output[key] = await decryptString(output[key]?.toString() ?? '');
      }
    }
    return output;
  }

  bool _isSensitive(String key) {
    final String normalized = key.toLowerCase();
    return normalized.contains('cpf') ||
        normalized.contains('cns') ||
        normalized.contains('telefone') ||
        normalized.contains('endereco') ||
        normalized.contains('nascimento') ||
        normalized.contains('senha') ||
        normalized.contains('email') ||
        normalized.contains('preccp') ||
        normalized.contains('valor') ||
        normalized.contains('resultado') ||
        normalized.contains('payload') ||
        normalized.contains('mensagembruta');
  }
}
