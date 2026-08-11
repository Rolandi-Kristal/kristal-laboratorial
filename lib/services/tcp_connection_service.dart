import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/equipment_connection_config.dart';

class TcpConnectionResult {
  final bool ok;
  final String message;
  const TcpConnectionResult({required this.ok, required this.message});
}

class TcpConnectionService {
  TcpConnectionService._();
  static final TcpConnectionService instance = TcpConnectionService._();

  Future<TcpConnectionResult> testar(EquipmentConnectionConfig config) async {
    if (config.ip.trim().isEmpty || config.portaTcpInt <= 0) {
      return const TcpConnectionResult(
          ok: false, message: 'Informe IP e porta TCP válidos.');
    }
    Socket? socket;
    try {
      socket = await Socket.connect(config.ip.trim(), config.portaTcpInt,
          timeout: Duration(seconds: config.timeoutInt));
      return TcpConnectionResult(
          ok: true,
          message: 'Conexão TCP/IP OK em ${config.ip}:${config.portaTcp}.');
    } on SocketException catch (error) {
      return TcpConnectionResult(
        ok: false,
        message:
            'Falha TCP/IP em ${config.ip}:${config.portaTcp}: ${error.message}',
      );
    } on TimeoutException catch (error) {
      return TcpConnectionResult(
        ok: false,
        message: 'Tempo esgotado na conexão TCP/IP: ${error.message ?? error}',
      );
    } finally {
      await socket?.close();
    }
  }

  Future<TcpConnectionResult> enviarMensagem(
      {required EquipmentConnectionConfig config,
      required String mensagem}) async {
    Socket? socket;
    try {
      socket = await Socket.connect(config.ip.trim(), config.portaTcpInt,
          timeout: Duration(seconds: config.timeoutInt));
      socket.add(utf8.encode(mensagem));
      await socket.flush();
      return TcpConnectionResult(
          ok: true,
          message: 'Mensagem enviada para ${config.ip}:${config.portaTcp}.');
    } on SocketException catch (error) {
      return TcpConnectionResult(
        ok: false,
        message: 'Falha ao enviar mensagem TCP/IP: ${error.message}',
      );
    } on TimeoutException catch (error) {
      return TcpConnectionResult(
        ok: false,
        message: 'Tempo esgotado ao enviar mensagem: ${error.message ?? error}',
      );
    } finally {
      await socket?.close();
    }
  }
}
