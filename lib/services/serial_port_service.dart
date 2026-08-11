import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../models/equipment_connection_config.dart';

class SerialPortResult {
  final bool ok;
  final String message;
  final int bytesTransferred;
  final String data;

  const SerialPortResult({
    required this.ok,
    required this.message,
    this.bytesTransferred = 0,
    this.data = '',
  });
}

class SerialPortService {
  SerialPortService._();

  static final SerialPortService instance = SerialPortService._();

  String dcbDefinition(EquipmentConnectionConfig config) {
    final String port = _normalizedPort(config.portaCom);
    final int baudRate = _positiveInt(config.baudRate, 'baud rate');
    final int dataBits = _positiveInt(config.dataBits, 'data bits');
    if (dataBits < 5 || dataBits > 8) {
      throw ArgumentError.value(
          dataBits, 'dataBits', 'Deve estar entre 5 e 8.');
    }
    final String stopBits = config.stopBits.trim();
    if (stopBits != '1' && stopBits != '1.5' && stopBits != '2') {
      throw ArgumentError.value(stopBits, 'stopBits', 'Use 1, 1.5 ou 2.');
    }
    final String parity = switch (config.paridade.trim().toUpperCase()) {
      'NONE' => 'n',
      'ODD' => 'o',
      'EVEN' => 'e',
      'MARK' => 'm',
      'SPACE' => 's',
      final String invalid => throw ArgumentError.value(
          invalid,
          'paridade',
          'Use NONE, ODD, EVEN, MARK ou SPACE.',
        ),
    };
    return '$port baud=$baudRate parity=$parity data=$dataBits stop=$stopBits';
  }

  Future<SerialPortResult> testar(EquipmentConnectionConfig config) async {
    if (!Platform.isWindows) {
      return const SerialPortResult(
        ok: false,
        message: 'Comunicação COM direta é suportada somente no Windows.',
      );
    }
    final _SerialHandle opened = _openConfigured(config);
    CloseHandle(opened.handle);
    return SerialPortResult(
      ok: true,
      message: 'Porta ${opened.port} aberta e configurada com sucesso.',
    );
  }

  Future<SerialPortResult> enviarMensagem({
    required EquipmentConnectionConfig config,
    required String mensagem,
  }) async {
    if (mensagem.isEmpty) {
      throw ArgumentError.value(
          mensagem, 'mensagem', 'A mensagem não pode estar vazia.');
    }
    if (!Platform.isWindows) {
      return const SerialPortResult(
        ok: false,
        message: 'Comunicação COM direta é suportada somente no Windows.',
      );
    }

    final _SerialHandle opened = _openConfigured(config);
    final Uint8List bytes = Uint8List.fromList(latin1.encode(mensagem));
    final Pointer<Uint8> buffer = calloc<Uint8>(bytes.length);
    final Pointer<Uint32> written = calloc<Uint32>();
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      final int success = WriteFile(
        opened.handle,
        buffer,
        bytes.length,
        written,
        nullptr,
      );
      if (success == 0 || written.value != bytes.length) {
        return SerialPortResult(
          ok: false,
          message: _failure('Falha ao escrever em ${opened.port}'),
          bytesTransferred: written.value,
        );
      }
      return SerialPortResult(
        ok: true,
        message: '${written.value} bytes enviados para ${opened.port}.',
        bytesTransferred: written.value,
      );
    } finally {
      calloc.free(written);
      calloc.free(buffer);
      CloseHandle(opened.handle);
    }
  }

  Future<SerialPortResult> receberMensagem({
    required EquipmentConnectionConfig config,
    int maxBytes = 65536,
  }) async {
    if (maxBytes < 1 || maxBytes > 16 * 1024 * 1024) {
      throw RangeError.range(maxBytes, 1, 16 * 1024 * 1024, 'maxBytes');
    }
    if (!Platform.isWindows) {
      return const SerialPortResult(
        ok: false,
        message: 'Comunicação COM direta é suportada somente no Windows.',
      );
    }

    final _SerialHandle opened = _openConfigured(config);
    final Pointer<Uint8> buffer = calloc<Uint8>(maxBytes);
    final Pointer<Uint32> read = calloc<Uint32>();
    try {
      final int success = ReadFile(
        opened.handle,
        buffer,
        maxBytes,
        read,
        nullptr,
      );
      if (success == 0) {
        return SerialPortResult(
          ok: false,
          message: _failure('Falha ao ler ${opened.port}'),
        );
      }
      final Uint8List bytes =
          Uint8List.fromList(buffer.asTypedList(read.value));
      return SerialPortResult(
        ok: true,
        message: '${read.value} bytes recebidos de ${opened.port}.',
        bytesTransferred: read.value,
        data: latin1.decode(bytes),
      );
    } finally {
      calloc.free(read);
      calloc.free(buffer);
      CloseHandle(opened.handle);
    }
  }

  _SerialHandle _openConfigured(EquipmentConnectionConfig config) {
    final String port = _normalizedPort(config.portaCom);
    final String devicePath = r'\\.\' + port;
    final Pointer<Utf16> nativePath = devicePath.toNativeUtf16();
    final int handle = CreateFile(
      nativePath,
      GENERIC_READ | GENERIC_WRITE,
      0,
      nullptr,
      OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL,
      0,
    );
    calloc.free(nativePath);
    if (handle == INVALID_HANDLE_VALUE) {
      throw StateError(_failure('Não foi possível abrir $port'));
    }

    final Pointer<DCB> dcb = calloc<DCB>();
    final Pointer<COMMTIMEOUTS> timeouts = calloc<COMMTIMEOUTS>();
    try {
      dcb.ref.DCBlength = sizeOf<DCB>();
      if (GetCommState(handle, dcb) == 0) {
        throw StateError(_failure('GetCommState falhou em $port'));
      }
      final String definition =
          dcbDefinition(config).replaceFirst('$port ', '');
      final Pointer<Utf16> nativeDefinition = definition.toNativeUtf16();
      final int built = BuildCommDCB(nativeDefinition, dcb);
      calloc.free(nativeDefinition);
      if (built == 0) {
        throw StateError(_failure('Configuração serial inválida para $port'));
      }
      if (SetCommState(handle, dcb) == 0) {
        throw StateError(_failure('SetCommState falhou em $port'));
      }

      final int timeoutMs = config.timeoutInt * 1000;
      timeouts.ref
        ..ReadIntervalTimeout = 50
        ..ReadTotalTimeoutMultiplier = 0
        ..ReadTotalTimeoutConstant = timeoutMs
        ..WriteTotalTimeoutMultiplier = 0
        ..WriteTotalTimeoutConstant = timeoutMs;
      if (SetCommTimeouts(handle, timeouts) == 0) {
        throw StateError(_failure('SetCommTimeouts falhou em $port'));
      }
      return _SerialHandle(handle: handle, port: port);
    } on StateError {
      CloseHandle(handle);
      rethrow;
    } finally {
      calloc.free(timeouts);
      calloc.free(dcb);
    }
  }

  String _normalizedPort(String value) {
    final String port = value.trim().toUpperCase();
    if (!RegExp(r'^COM[1-9][0-9]{0,2}$').hasMatch(port)) {
      throw ArgumentError.value(value, 'portaCom', 'Use COM1 até COM999.');
    }
    return port;
  }

  int _positiveInt(String value, String field) {
    final int? parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      throw ArgumentError.value(value, field, 'Informe um inteiro positivo.');
    }
    return parsed;
  }

  String _failure(String operation) {
    return '$operation. Erro Win32: ${GetLastError()}.';
  }
}

class _SerialHandle {
  final int handle;
  final String port;

  const _SerialHandle({required this.handle, required this.port});
}
