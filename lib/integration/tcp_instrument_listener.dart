import 'dart:convert';
import 'dart:io';

class TcpInstrumentListener {
  ServerSocket? _server;
  Future<void> start(
      {required int port, required void Function(String data) onData}) async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _server!.listen((socket) {
      socket.cast<List<int>>().transform(utf8.decoder).listen(onData);
    });
  }

  Future<void> stop() async => _server?.close();
}
