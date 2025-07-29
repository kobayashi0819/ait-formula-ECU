// udp_handler.dart
import 'dart:convert';
import 'dart:io';
import 'setting_page.dart';
import 'main.dart';

class UDPReceiver {
  // final String '192.168.0.16';
  // final int '8080';
  final String localIp;
  final int port;
  final Function(String) onDataReceived;

  UDPReceiver(
      {required this.localIp,
      required this.port,
      required this.onDataReceived});

  Future<void> start() async {
    try {
      var socket = await RawDatagramSocket.bind(InternetAddress(localIp), port);
      print('Listening for UDP packets on $localIp:$port');

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = socket.receive();
          if (dg != null) {
            String receivedDataStr = String.fromCharCodes(dg.data);
            onDataReceived(receivedDataStr);
          }
        }
      });
    } catch (e) {
      print('Error: $e');
    }
  }
}
