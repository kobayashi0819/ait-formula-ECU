import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'second_page.dart';
import 'setting_page.dart';
import 'udp_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart'; // CSV操作用
import 'package:path_provider/path_provider.dart'; // 保存先取得用
import 'package:share_plus/share_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(DashboardApp());
}

class DashboardApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Dashboard',
      theme: ThemeData.light(),
      home: DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late UDPReceiver udpReceiver;
  late RawDatagramSocket _socket;
  List<List<String>> _bufferedRows = [];
  Timer? _collectTimer;
  Timer? _sendTimer;

  double _rpm = 0;
  // double _apps = 0;
  int _apps = 0;
  int _torque = 0;
  double _brake = 0;
  int _itemp = 0;
  int _mtemp = 0;
  double _battery = 0;
  double _voltage = 0;
  double _speed = 0;
  int _state = 0;
  late Timer _timer;
  double speed2 = 0;
  double apps2 = 0;
  int torque2 = 0;
  double brake2 = 0;
  double baseX = 0;
  double baseY = 0;
  double baseZ = 0;
  double x = 0.0;
  double y = 0.0;
  double z = 0.0;
  double gX = 0.0;
  double gY = 0.0;
  double gZ = 0.0;
  double gyroX = 0.0;
  double gyroY = 0.0;
  double gyroZ = 0.0;
  int ERROR = 0;
  int current = 0;
  int OUTPUTtorque = 0;
  int _sequenceNumber = 1; // データ番号用の変数
// List<Map<String, dynamic>> _buffer = []; // データバッファ

  bool _isWritingCSV = false; // CSV書き込み中かどうかを管理するフラグ

  // 🔹 localIp の管理
  // String? _localIp;
  // String _localIp = '192.168.0.8';
  // String _localIp = '10.119.244.22';
  String _localIp = '10.160.128.252'; //VPN
  // String _localIp = '192.168.45.218';
  TextEditingController _ipController = TextEditingController();

  // Google Sheets送信用
  bool _isSendingToSheet = false;
  Timer? _sheetTimer;
  final String sheetEndpoint =
      'https://script.google.com/macros/s/AKfycbxQk1TE-Fqc8vT-zaoqrTiaQsWJLMBjH3SDE06gE1BIwmX_5v2w-t4jnl9LZZBNNGnfig/exec';

  @override
  void initState() {
    _loadLocalIp(); // IP`読み込み
    // udpReceiver = UDPReceiver(
    //   localIp: _localIp,
    //   port: 8080,
    //   onDataReceived: _parseData,
    // );

    // udpReceiver.start();
    super.initState();
    _startSpeedIncrement();
    // _initializeSocket();
  }

  /// 🔸 SharedPreferences から IP を読み込み
  Future<void> _loadLocalIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('localIp');

    if (savedIp != null && savedIp.isNotEmpty) {
      setState(() {
        _localIp = savedIp;
      });

      // UDPReceiverはここで初期化・開始！
      udpReceiver = UDPReceiver(
        localIp: _localIp,
        port: 8080,
        onDataReceived: _parseData,
      );
      udpReceiver.start();

      print('Loaded localIp: $_localIp');
    } else {
      print('保存されたIPが見つかりません。');
    }
  }

  Future<void> sendAppsToGoogleSheet() async {
    //使っていない
    final now = DateTime.now().toIso8601String();
    final payload = {
      'rows': [
        // [now, _apps.toString()],
        [now, speed2.toString()],
      ]
    };

    try {
      final response = await http.post(
        Uri.parse(sheetEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        print('✅ apps送信成功');
      } else {
        print('❌ apps送信失敗: \${response.statusCode}');
      }
    } catch (e) {
      print('❌ 通信エラー: \$e');
    }
  }

  Future<void> sendBufferedDataToGoogleSheet(List<List<String>> rows) async {
    final payload = {
      'rows': rows,
    };

    try {
      final response = await http.post(
        Uri.parse(sheetEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        print('✅ データ送信成功（${rows.length}件）');
      } else {
        print('❌ 送信失敗: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 通信エラー: $e');
    }
  }

  void startSendingApps() {
    if (_isSendingToSheet) return;
    _isSendingToSheet = true;
    _sheetTimer = Timer.periodic(Duration(seconds: 1), (_) {
      sendAppsToGoogleSheet();
    });
  }

  void stopSendingApps() {
    _isSendingToSheet = false;
    _sheetTimer?.cancel();
    print('🛑 apps送信停止');
  }

  void startBufferedSending() {
    if (_isSendingToSheet) return;
    setState(() {
      _isSendingToSheet = true;
    });
    // 0.1秒ごとにデータを収集
    _collectTimer = Timer.periodic(Duration(milliseconds: 90), (_) {
      final now = DateTime.now().toIso8601String();
      _bufferedRows.add([
        /*1 */ now,
        /*2 */ _sequenceNumber.toString(),
        /*3 */ _apps.toString(),
        /*4 */ _brake.toString(),
        /*5 */ _rpm.toString(),
        /*6 */ _speed.toString(),
        /*7 */ _torque.toString(),
        /*8 */ _itemp.toString(),
        /*9 */ _mtemp.toString(),
        /*10*/ _voltage.toString(),
        /*11*/ gX.toString(),
        /*12*/ gY.toString(),
        /*13*/ gZ.toString(),
        // /*14*/gyroX.toString(),
        // /*15*/gyroY.toString(),
        // /*16*/gyroZ.toString(),
        /*17*/ ERROR.toString(),
        /*18*/ current.toString(),
      ]);
      _sequenceNumber++;
    });

    // 2秒ごとに送信
    _sendTimer = Timer.periodic(Duration(seconds: 2), (_) {
      if (_bufferedRows.isNotEmpty) {
        sendBufferedDataToGoogleSheet(List.from(_bufferedRows));
        _bufferedRows.clear();
      }
    });
  }

  void stopBufferedSending() {
    setState(() {
      _isSendingToSheet = false;
    });
    _collectTimer?.cancel();
    _sendTimer?.cancel();
    print('🛑 バッファ送信停止');
  }

  // Future<void> _loadLocalIp() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   setState(() {
  //     // _localIp = prefs.getString('localIp') ?? '192.168.0.8'; //デフォルトで??の後の値
  //     _localIp = prefs.getString('localIp')!;
  //   });

  //   udpReceiver = UDPReceiver(
  //     localIp: _localIp,
  //     port: 8080,
  //     onDataReceived: _parseData,
  //   );
  //   udpReceiver.start();

  //   print('Loaded localIp: $_localIp');
  // }

  /// 🔸 SharedPreferences に IP を保存
  Future<void> _saveLocalIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('localIp', ip);
    print('Saved IP: $ip');
  }

  /////////////////////////////////////////////////
  ///CSVテスト
  /// ログの記録を開始
  ///
  bool _isLogging = false;
  late File _file;
  void startLogging() {
    if (_isLogging) return;
    setState(() {
      _isLogging = true;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      String now = DateTime.now().toIso8601String();
      await _file.writeAsString('$now\n', mode: FileMode.append);
      print('Saved: $now');

      if (timer.tick >= 10) {
        stopLogging();
      }
    });

    print('Logging started.');
  }

  /// ログの記録を停止
  void stopLogging() {
    _timer?.cancel();
    setState(() {
      _isLogging = false;
    });
    print('Logging stopped.');
  }

  // Future<void> shareCSV() async {
  //   Directory dir = await getApplicationDocumentsDirectory();
  //   String filePath = '${dir.path}/data.csv';

  //   Share.shareFiles([filePath], text: 'CSV データを共有');
  // }
  void shareCSV() async {
    // //ファイルを保存する場所を取得
    // Directory dir = await getApplicationDocumentsDirectory();
    // //ファイルパスを作成
    // String filePath = '${dir.path}/data.csv';

    // Share.shareFiles([filePath], text: 'CSV データを共有');
    try {
      // ファイルを保存する場所を取得
      Directory dir = await getApplicationDocumentsDirectory();
      // ファイルパスを作成
      String filePath = '${dir.path}/data.csv';

      // ファイルが存在するか確認
      if (await File(filePath).exists()) {
        // ファイルが存在すれば共有を開始
        await Share.shareFiles([filePath], text: 'CSV データを共有');
      } else {
        // ファイルが存在しない場合
        print("ファイルが存在しません: $filePath");
      }
    } catch (e) {
      // エラーが発生した場合
      print("エラー: $e");
    }
  }
  /////////////////////////////////////////////////

  // void _initializeSocket() async {
  //   _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _udpPort);
  //   _socket.listen((RawSocketEvent event) {
  //     if (event == RawSocketEvent.read) {
  //       final datagram = _socket.receive();
  //       if (datagram != null) {
  //         final data = utf8.decode(datagram.data);
  //         _parseData(data);
  //       }
  //     }
  //   });
  // }

  // final wifiIP = await info.localIp(); // 192.168.1.43
  // print (localIp);

  void _parseData(String data) {
    //ここでESP32からのjsondataを処理する
    try {
      final parsed = jsonDecode(data);
      setState(() {
        _apps = parsed['apps'] ?? _apps;
        // _apps = parsed['apps']?.toDouble() ?? _apps;
        _brake = parsed['brake']?.toDouble() ?? _brake;
        _torque = parsed['torque'] ?? _torque;
        _rpm = parsed['rpm']?.toDouble() ?? _rpm;
        // _itemp = parsed['itemp'] ?? _itemp;
        // _mtemp = parsed['mtemp'] ?? _mtemp;
        _itemp = parsed['invTmp'] ?? _itemp;
        _mtemp = parsed['mtTmp'] ?? _mtemp;
        _voltage = parsed['volt'].toDouble() ?? _voltage;
        _state = parsed['state'] ?? _state;
        gX = parsed['gX'].toDouble() ?? gX;
        gY = parsed['gY'].toDouble() ?? gY;
        gZ = parsed['gZ'].toDouble() ?? gZ;
        gyroX = parsed['gyroX'].toDouble() ?? gyroX;
        gyroY = parsed['gyroY'].toDouble() ?? gyroY;
        gyroZ = parsed['gyroZ'].toDouble() ?? gyroZ;
        ERROR = parsed['ERROR'] ?? ERROR;
        current = parsed['current'] ?? current;
      });
    } catch (e) {
      print('Error parsing data: $e');
    }
  }

  @override
  void dispose() {
    // 必要ならソケットを閉じる処理をここに記述
    super.dispose();
  }

  void _startSpeedIncrement() {
    _timer = Timer.periodic(Duration(milliseconds: 1), (timer) {
      setState(() {
        speed2 = (_rpm * 60 * 1.67362) / (1000 * 11.9);
        // _voltage = (_voltage - 300) * (96.3 / 100);
        // if (_voltage < 0) {
        //   _voltage = 0;
        // }

        // speed2 += 0.01;
        // _rpm += 1;
        // torque2 += 0.02;
        // _itemp += 1;
        // _mtemp += 1;

        // if (speed2 >= 80) {
        //   speed2 = 0;
        // }
        // if (torque2 >= 100) {
        //   torque2 = 0;
        // }
        // if (_rpm >= 10000) {
        //   _rpm = 0;
        // }
        // if (_itemp >= 100) {
        //   _itemp = 0;
        // }
        // if (_mtemp >= 100) {
        //   _mtemp = 0;
        // }
      });
    });

    // accelerometerEvents.listen((AccelerometerEvent event) {
    //   setState(() {
    //     x = event.x * -1; // 加速度のx成分（左右）
    //     y = event.y; // 加速度のy成分（上下）
    //     z = event.z;
    //     // 画面外に出ないように制限
    //     x = x.clamp(-100.0, 100.0);
    //     y = y.clamp(-200.0, 200.0);
    //     print('X');
    //     print(x);
    //     print('Y');
    //     print(y);
    //     print('Z');
    //     print(z);
    //   });
    // });
  }

  // CSV書き込みを開始する
  void _startCSVWriting({required bool start}) {
    setState(() {
      _isWritingCSV = true;
    });
    print('CSV書き込み開始');
    // ここで、データをCSVに書き込む処理を追加します
  }

  // CSV書き込みを停止する
  void _stopCSVWriting() {
    setState(() {
      _isWritingCSV = false;
    });
    print('CSV書き込み停止');
    // ここで、CSV書き込みの停止処理を追加します
  }

  @override
  Widget build(BuildContext context) {
    backgroundColor:
    const Color.fromARGB(255, 255, 255, 255); // ← ここを追加！
    //ここで配置をいじる
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // _buildRPMGauge(),
                    Text('$_rpm rpm',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        )),
                    SizedBox(height: 40),
                    Text('Itemp',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        )),
                    Text('$_itemp ℃',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        )),
                    SizedBox(height: 40),
                    Text('Mtemp',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        )),
                    Text('$_mtemp ℃',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        )),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: _buildSpeedGauge(),
                ),
              ),
              Expanded(
                child: _buildDataPanel(),
              ),
            ],
          ),
          // 左上のボタンを配置
          Positioned(
            top: 60,
            left: 20,
            child: Row(
              children: [
                ElevatedButton(
                    onPressed: startBufferedSending,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSendingToSheet ? Colors.red : null,
                    ),
                    child: Text('Start')),
                SizedBox(height: 10),
                ElevatedButton(
                    onPressed: stopBufferedSending, child: Text('Stop')),
              ],
            ),
          ),

          Positioned(
            // 位置を直接指定？　重ねて配置するときに使うらしい
            top: 325,
            left: 30,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SecondPage(
                        // startLogging: startLogging,  // 🔹 必須パラメータを渡す
                        // stopLogging: stopLogging,
                        // shareCSV: shareCSV,
                        ),
                  ),
                );
              },
              child: Text('設定'),
            ),
          ),

          // Positioned(
          //   bottom: 20,
          //   left: 150,
          //   child: Container(
          //     width: 100,
          //     height: 100,
          //     decoration: BoxDecoration(
          //       color: Colors.grey.shade300,
          //       border: Border.all(color: Colors.black),
          //     ),
          //     child: Stack(
          //       children: [
          //         Positioned(
          //           left: 45 + (-x * 2), // 中央 = 45, スケール調整
          //           top: 45 + (y * 2),
          //           child: Container(
          //             width: 10,
          //             height: 10,
          //             decoration: BoxDecoration(
          //               color: Colors.red,
          //               shape: BoxShape.circle,
          //             ),
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  // Widget _mainReft() {

  // }

  Widget _buildSpeedGauge() {
    return SfRadialGauge(
      axes: [
        RadialAxis(
          minimum: 0,
          maximum: 80,
          ranges: [
            GaugeRange(startValue: 0, endValue: 25, color: Colors.green),
            GaugeRange(startValue: 25, endValue: 55, color: Colors.orange),
            GaugeRange(startValue: 55, endValue: 80, color: Colors.red),
          ],
          pointers: [
            // NeedlePointer(value: speed2),
            NeedlePointer(
              value: speed2,
              needleLength: 0.8, // 針の長さを設定
              needleEndWidth: 10, // 針の幅を大きくして棒状に
              knobStyle: KnobStyle(
                knobRadius: 0.1, // 中央のノブサイズ
                color: Colors.black,
              ),
              needleColor: Colors.black, // 棒の色
            ),
          ],
          annotations: [
            GaugeAnnotation(
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'state $_state',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5), // 適度なスペースを追加
                  Text(
                    'ERROR $ERROR',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5), // 適度なスペースを追加
                  Text(
                    'gx $gX',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],

          // annotations: [
          //   GaugeAnnotation(
          //     widget: Text(
          //       'state $_state',
          //       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          //     ),
          //     angle: 90,
          //     positionFactor: 0.5,
          //   ),
          // ],
        ),
      ],
    );
  }

  Widget _buildRPMGauge() {
    return SfRadialGauge(
      axes: [
        RadialAxis(
          minimum: 0,
          maximum: 10000,
          ranges: [
            GaugeRange(startValue: 0, endValue: 3000, color: Colors.green),
            GaugeRange(startValue: 3000, endValue: 6000, color: Colors.orange),
            GaugeRange(startValue: 6000, endValue: 10000, color: Colors.red),
          ],
          pointers: [
            // NeedlePointer(value: speed2),
            NeedlePointer(
              value: _rpm,
              needleLength: 0.6, // 針の長さを設定
              needleEndWidth: 6, // 針の幅を大きくして棒状に
              knobStyle: KnobStyle(
                knobRadius: 0.1, // 中央のノブサイズ
                color: Colors.black,
              ),
              needleColor: Colors.black, // 棒の色
            ),
          ],
          annotations: [
            GaugeAnnotation(
              widget: Text(
                'rpm $_rpm',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataPanel() {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Container(color: Colors.red, width: 100, height: 100),
          Container(
            height: 90,
            width: 140,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Stack(
              children: [
                // 横向きのゲージを追加
                FractionallySizedBox(
                  widthFactor: _voltage / 396, // 値に応じて幅を調整
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getGaugeColor(_voltage), // ゲージの色
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                // テキスト表示
                Center(
                  child: Text(
                    '${_voltage.toStringAsFixed(1)}V', // 現在の値を表示
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Flexible(
                child: _buildVerticalMeter('apps', _apps * 1, 100, Colors.blue),
              ),
              Flexible(
                child: _buildVerticalMeter(
                    // 'torque', OUTPUTtorque * 1, 100, Colors.green),
                    'torque',
                    _torque * 1,
                    60,
                    Colors.green),
              ),
              Flexible(
                child:
                    _buildVerticalMeter('brake', _brake * 1, 3000, Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 値に応じてゲージの色を決定する関数
  Color _getGaugeColor(double value) {
    if (value < 20) {
      return Colors.red; // 低い値
    } else if (value < 50) {
      return Colors.yellow; // 中程度の値
    } else {
      return Colors.green; // 高い値
    }
  }

  Widget _buildVerticalMeter(
      //右下のapps等のゲージの枠の設計
      String label,
      double value,
      double maxValue,
      Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          height: 140,
          width: 30,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: (value / maxValue) * 140,
              width: 30,
              color: color,
            ),
          ),
        ),
        SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 14)),
        Text(value.toInt().toString(), style: TextStyle(fontSize: 16)),
      ],
    );
  }
}
