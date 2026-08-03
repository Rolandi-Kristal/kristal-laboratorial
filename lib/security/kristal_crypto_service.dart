import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_constants.dart';

class KristalCryptoService {
  KristalCryptoService._();

  static final KristalCryptoService instance = KristalCryptoService._();

  final AesGcm _algorithm = AesGcm.with256bits();
  SecretKey? _cachedKey;

  Future<SecretKey> _key() async {
    if (_cachedKey != null) return _cachedKey!;

    final Directory dir = await getApplicationSupportDirectory();
    final File keyFile = File(p.join(dir.path, AppConstants.masterKeyFile));

    if (!await keyFile.exists()) {
      final List<int> keyBytes = List<int>.generate(
        32,
        (_) => Random.secure().nextInt(256),
      );
      await keyFile.writeAsString(base64Encode(keyBytes), flush: true);
      _cachedKey = SecretKey(keyBytes);
      return _cachedKey!;
    }

    final String encoded = await keyFile.readAsString();
    _cachedKey = SecretKey(base64Decode(encoded.trim()));
    return _cachedKey!;
  }

  Future<String> encryptString(String plainText) async {
    if (plainText.isEmpty) return '';

    if (plainText.startsWith(AppConstants.cryptoPrefix)) {
      return plainText;
    }

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

    final String raw = encryptedText.substring(AppConstants.cryptoPrefix.length);
    final Map<String, dynamic> payload =
        jsonDecode(utf8.decode(base64Decode(raw))) as Map<String, dynamic>;

    final SecretBox box = SecretBox(
      base64Decode(payload['c'].toString()),
      nonce: base64Decode(payload['n'].toString()),
      mac: Mac(base64Decode(payload['m'].toString())),
    );

    final List<int> clear = await _algorithm.decrypt(
      box,
      secretKey: await _key(),
    );

    return utf8.decode(clear);
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
    final String k = key.toLowerCase();
    return k.contains('cpf') ||
        k.contains('cns') ||
        k.contains('telefone') ||
        k.contains('endereco') ||
        k.contains('nascimento') ||
        k.contains('senha') ||
        k.contains('email') ||
        k.contains('preccp');
  }
}
