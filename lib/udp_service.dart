// // import 'dart:async';
// // import 'dart:io';
// // import 'dart:convert';

// // class UdpService {
// //   final String esp32Address; // ESP32のIPアドレス
// //   final int udpPort; // ESP32のUDPポート
// //   late RawDatagramSocket _socket;

// //   UdpService({required this.esp32Address, required this.udpPort});

// //   /// 初期化
// //   Future<void> initialize() async {
// //     _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
// //     print('UDP client initialized.');
// //   }

// //   /// メッセージ送信
// //   void sendMessage(String message) {
// //     final data = utf8.encode(message);
// //     _socket.send(data, InternetAddress(esp32Address), udpPort);
// //     print('Message sent to $esp32Address:$udpPort: $message');
// //   }

// //   /// メッセージ受信
// //   Stream<String> receiveMessages() async* {
// //     await for (RawSocketEvent event in _socket) {
// //       if (event == RawSocketEvent.read) {
// //         final datagram = _socket.receive();
// //         if (datagram != null) {
// //           final message = utf8.decode(datagram.data);
// //           yield message;
// //         }
// //       }
// //     }
// //   }
// // }


// // import 'dart:async';
// // import 'dart:convert';
// // import 'dart:io';
// // import 'package:udp/udp.dart';
// // import 'udp_service.dart';

// // class UdpService {
// //   final String esp32Address; // ESP32のIPアドレス
// //   final int udpPort; // ESP32のUDPポート
// //   late UDP _udp;

// //   UdpService({required this.esp32Address, required this.udpPort});

// //   /// 初期化
// //   Future<void> initialize() async {
// //     _udp = await UDP.bind(Endpoint.any());
// //     print('UDP client initialized.');
// //   }

// //   /// メッセージ送信
// //   void sendMessage(String message) async {
// //     final data = utf8.encode(message);
// //     final endpoint = Endpoint.unicast(InternetAddress(esp32Address), port: Port(udpPort));
// //     await _udp.send(data, endpoint);
// //     print('Message sent to $esp32Address:$udpPort: $message');
// //   }

// //   /// メッセージ受信
// //   Stream<String> receiveMessages() async* {
// //     final endpoint = Endpoint.unicast(InternetAddress(esp32Address), port: Port(udpPort));
// //     _udp.listen((datagram) {
// //       if (datagram != null) {
// //         final message = utf8.decode(datagram.data);
// //         print('Received message: $message');
// //         yield message;
// //       }
// //     }, endpoint: endpoint);
// //   }

// //   /// クローズ
// //   void close() {
// //     _udp.close();
// //   }
// // }

// // import 'dart:io';  // dart:ioをインポート
// // import 'dart:convert';
// // import 'dart:async';
// // import 'package:udp/udp.dart';

// // class UdpService {
// //   final String esp32Address; // ESP32のIPアドレス
// //   final int udpPort; // ESP32のUDPポート
// //   late UDP _udp;

// //   UdpService({required this.esp32Address, required this.udpPort});

// //   // 初期化
// //   Future<void> initialize() async {
// //     _udp = await UDP.bind(Endpoint.any());
// //     print('UDP client initialized.');
// //   }

// //   // メッセージ送信
// //   void sendMessage(String message) async {
// //     final data = utf8.encode(message);
// //     final endpoint = Endpoint.unicast(InternetAddress(esp32Address), port: Port(udpPort)); 
// //     await _udp.send(data, endpoint);
// //     print('Message sent to $esp32Address:$udpPort: $message');
// //   }

// //   // メッセージ受信 (非同期ジェネレーター関数として修正)
// //   Stream<String> receiveMessages() async* {
// //     final endpoint = Endpoint.unicast(InternetAddress(esp32Address), port: Port(udpPort));
    
// //     // 受信したデータを非同期でストリームとして発行
// //     await for (var datagram in _udp.asStream()) {
// //       if (datagram != null && datagram.data.isNotEmpty) {
// //         final message = utf8.decode(datagram.data);
// //         print('Received message: $message');
// //         yield message; // データをストリームで発行
// //       }
// //     }
// //   }

// //   // クローズ
// //   void close() {
// //     _udp.close();
// //   }
// // }


// import 'dart:convert';
// import 'dart:io';
// import 'dart:async';
// import 'package:udp/udp.dart';

// class UdpService {
//   final String esp32Address; // ESP32のIPアドレス
//   final int udpPort; // UDPポート番号
//   late UDP _udp;

//   UdpService({required this.esp32Address, required this.udpPort});

//   // 初期化
//   Future<void> initialize() async {
//     _udp = await UDP.bind(Endpoint.any());
//     print('UDP client initialized.');
//   }

//   // メッセージ送信
//   void sendMessage(String message) async {
//     final data = utf8.encode(message);
//     final endpoint = Endpoint.unicast(InternetAddress(esp32Address), port: Port(udpPort));
//     await _udp.send(data, endpoint);
//     print('Message sent to $esp32Address:$udpPort: $message');
//   }

//   // メッセージ受信 (非同期ジェネレーター関数として修正)
//   Stream<Map<String, dynamic>> receiveMessages() async* {
//     final endpoint = Endpoint.unicast(InternetAddress(esp32Address), port: Port(udpPort));
    
//     // 受信したデータを非同期でストリームとして発行
//     await for (var datagram in _udp.asStream()) {
//       if (datagram != null && datagram.data.isNotEmpty) {
//         // 受け取ったデータをJSONとして解析
//         final message = utf8.decode(datagram.data);
//         try {
//           final Map<String, dynamic> jsonData = jsonDecode(message);
//           print('Received data: $jsonData');
//           yield jsonData; // JSONデータをストリームで発行
//         } catch (e) {
//           print('Failed to decode JSON: $e');
//         }
//       }
//     }
//   }

//   // クローズ
//   void close() {
//     _udp.close();
//   }
// }
