import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

class CorporatePayloadCryptoService {
  CorporatePayloadCryptoService._();

  static final CorporatePayloadCryptoService instance =
      CorporatePayloadCryptoService._();

  static const String prefix = 'KRISTAL_SYNC_AES_GCM_V1:';
  final AesGcm _algorithm = AesGcm.with256bits();

  Future<Map<String, Object?>> seal({
    required String recordId,
    required Map<String, Object?> payload,
    required String apiKey,
  }) async {
    final String id = recordId.trim();
    final String key = apiKey.trim();
    if (id.isEmpty) throw ArgumentError('ID corporativo vazio.');
    if (key.length < 32) {
      throw ArgumentError(
          'Chave API corporativa deve possuir ao menos 32 caracteres.');
    }
    if (payload['id']?.toString() != id) {
      throw ArgumentError('ID do payload corporativo divergente.');
    }
    final List<int> nonce = List<int>.generate(
      12,
      (_) => Random.secure().nextInt(256),
    );
    final SecretBox box = await _algorithm.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: await _secretKey(key),
      nonce: nonce,
    );
    final Map<String, String> envelope = <String, String>{
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    };
    return <String, Object?>{
      'id': id,
      '_sealed': prefix + base64Encode(utf8.encode(jsonEncode(envelope))),
    };
  }

  Future<Map<String, Object?>> open({
    required String recordId,
    required Map<String, Object?> payload,
    required String apiKey,
  }) async {
    final Object? sealedValue = payload['_sealed'];
    if (sealedValue == null) return payload;
    final String sealed = sealedValue.toString();
    if (!sealed.startsWith(prefix)) {
      throw const FormatException(
          'Envelope corporativo possui versão inválida.');
    }
    final Map<String, dynamic> envelope;
    try {
      final Object? decoded = jsonDecode(
        utf8.decode(base64Decode(sealed.substring(prefix.length))),
      );
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Envelope corporativo não é um objeto.');
      }
      envelope = decoded;
    } on FormatException {
      throw const FormatException('Envelope corporativo corrompido.');
    }
    final SecretBox box;
    try {
      box = SecretBox(
        base64Decode(envelope['c']?.toString() ?? ''),
        nonce: base64Decode(envelope['n']?.toString() ?? ''),
        mac: Mac(base64Decode(envelope['m']?.toString() ?? '')),
      );
    } on FormatException {
      throw const FormatException(
          'Envelope corporativo contém Base64 inválido.');
    }
    final List<int> clear = await _algorithm.decrypt(
      box,
      secretKey: await _secretKey(apiKey.trim()),
    );
    final Object? decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map) {
      throw const FormatException(
          'Payload corporativo descriptografado inválido.');
    }
    final Map<String, Object?> opened = Map<String, Object?>.from(decoded);
    if (opened['id']?.toString() != recordId) {
      throw const FormatException(
          'ID do payload corporativo descriptografado divergente.');
    }
    return opened;
  }

  Future<SecretKey> _secretKey(String apiKey) async {
    if (apiKey.length < 32) {
      throw ArgumentError(
          'Chave API corporativa deve possuir ao menos 32 caracteres.');
    }
    final List<int> bytes =
        sha256.convert(utf8.encode('KRISTAL-LAB-SYNC-DATA-V1|$apiKey')).bytes;
    return SecretKey(bytes);
  }
}
