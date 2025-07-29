#include <SD.h>
#include <spiram.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_ADXL345_U.h>

#define TIRE 1.67362  // タイヤ円周長
#define GEAR 11.92    // ギア比13.8

// Wi-Fi設定
const char* ssid = "小林翔のiPhone";     // 自分のスマホのWi-Fi SSID
const char* password = "kobayashi0819";  // 自分のスマホのWi-Fiパスワード
// UDP設定
WiFiUDP udp;
// const char* remoteIP = "10.118.152.194";
const char* remoteIP = "10.91.37.74";
const int remotePort = 8080;  // UDPポート番号（iPhone側で設定しているものと一致させてください）
//加速度センサ設定
Adafruit_ADXL345_Unified accel = Adafruit_ADXL345_Unified(12345);

uint8_t readData[15];  // 受信データ用の配列サイズを送信側と一致
bool startReceiving = false;
int dataIndex = 0;
int i = 0;
int apps = 0;
int state = 0;
int rpm = 0;
int volt = 0;
int invTmp = 0;
int mtTmp = 0;
int fail = 0;
int sterterBtn = 0;
int torque = 0;
float kw = 0;
int speed = 0;
int brake = 0;
int current = 0;
float gX = 0;
float gY = 0;
float gZ = 0;
int ERROR = 0;
const int RTDPin = 12;
int count = 0;
int OUTPUTtorque = 0;
int Hvoltage = 0;


unsigned long lastBufferResetTime = 0;           // 最後にバッファをリセットした時刻

const unsigned long bufferResetInterval = 5000;  // バッファをリセットする間隔（例: 5秒）

void setup() {
  Serial.begin(230400);                      // デバッグ用シリアル通信
  Serial2.begin(57600, SERIAL_8N1, 17, 16);  // シリアル通信初期化
  // clearSerialBuffer(Serial2);


  // Wi-Fi接続
  WiFi.begin(ssid, password);
  Serial.println("Connecting to WiFi...");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(count);
    count++;
    if (count > 30) {
      break;
    }
  }
  //加速度センサー初期化
  accel.begin();
  // 範囲の設定（±2G, ±4G, ±8G, ±16G）
  accel.setRange(ADXL345_RANGE_2_G);
  Serial.println("ADXL345 初期化完了");

  pinMode(RTDPin, OUTPUT);
}

void loop() {
  // sensors_event_t event;
  // accel.getEvent(&event);
  // gX = event.acceleration.x;
  // gY = event.acceleration.y;
  // gZ = event.acceleration.z;

  sensors_event_t event;
  accel.getEvent(&event);
  gX = ((int)(event.acceleration.x * 100)) / 100.0;
  gY = ((int)(event.acceleration.y * 100)) / 100.0;
  gZ = ((int)(event.acceleration.z * 100)) / 100.0;

  Serial.print("gX : ");
  Serial.println(gX);
  Serial.print("gY : ");
  Serial.println(gY);
  Serial.print("gZ : ");
  Serial.println(gZ);
  // unsigned long currentMillis = millis();  // 現在の時間を取得
  // if (millis() - lastBufferResetTime >= bufferResetInterval) {
  //   clearSerialBuffer(Serial2);      // Serial2のバッファをリセット
  //   lastBufferResetTime = millis();  // 最後のリセット時間を更新
  // }


  if (Serial2.available()) {
    Serial.println("koko");
    if (Serial2.read() == 0x02) {
      // データが12バイト届くまで待つ
      while (dataIndex < 15) {
        if (Serial2.available()) {
          readData[dataIndex] = Serial2.read();
          dataIndex++;
          Serial.println("++");
        }
      }
    }
  }
  if (dataIndex == 15) {
    processReceivedData();
    dataIndex = 0;
  }

  if(state == 3) {
    digitalWrite(RTDPin, HIGH);
  } else {
    digitalWrite(RTDPin, LOW);
  }
  
  // while (Serial2.available() > 0) {
  //   uint8_t receivedByte = Serial2.read();
  //   Serial.println("Serial2Available");
  //   if (receivedByte == 0x02) {  // スタートビットを検出
  //     startReceiving = true;
  //     Serial.println("2");
  //     dataIndex = 0;
  //   } else if (startReceiving) {
  //     readData[dataIndex] = receivedByte;
  //     dataIndex++;
  //     // Serial.println("3");
  //     // Serial.print("dataIndex : ");
  //     // Serial.println(dataIndex);
  //     if (dataIndex >= 12) {
  //       Serial.println("4");
  //       startReceiving = false;  // 配列を全て受け取ったら終了
  //       processReceivedData();   // データ処理を行う関数を呼び出し
  //     }
  //   }
  // }

  // while (Serial2.available() > 0) {
  //   uint8_t receivedByte = Serial2.read();
  //   // Serial.println("Serial2Available");
  //   if (!startReceiving) {
  //     if (receivedByte == 0x02) {  // スタートビット検出
  //       startReceiving = true;
  //       dataIndex = 0;
  //       Serial.println("Start bit detected (0x02)");
  //     }
  //   } else if (startReceiving && dataIndex < 12) {
  //     readData[dataIndex++] = receivedByte;
  //     // Serial.print("Receiving byte ");
  //     // Serial.print(dataIndex);
  //     // Serial.print(": 0x");
  //     // Serial.println(receivedByte, HEX);

  //     if (dataIndex >= 12) {
  //       startReceiving = false;
  //       Serial.println("Full packet received");
  //       processReceivedData();
  //     }
  //   }
  // }
  JsonSend();
}



// void clearSerialBuffer(HardwareSerial& serialPort) {
//   while (serialPort.available() > 0) {
//     serialPort.read();  // バッファのデータを読み捨て
//   }
//   Serial.println("Serial buffer cleared.");
// }

void processReceivedData() {
  // 受信したデータを変数に格納
  apps = readData[0];
  speed = readData[1];
  // sterterBtn = readData[1];
  state = readData[2];
  rpm = readData[3] + (readData[4] << 8);
  Hvoltage = readData[5];
  // volt = readData[5] + (readData[6] << 8);
  fail = readData[7];
  mtTmp = readData[8];
  invTmp = readData[9];
  torque = readData[10];
  brake = readData[11] + (readData[12] << 8);
  ERROR = readData[13];
  current = readData[14];



  // 画面にデータ表示
  speed = (rpm * 60 * TIRE) / (1000 * GEAR);
  kw = (2 * 3.14 * torque * rpm) / (60 * 1000);
  brake = (int)brake * 100 / 4095;
  volt = Hvoltage + 145;
  
  Serial.print("apps");
  Serial.println(apps);
  Serial.print("sterterBtn");
  Serial.println(sterterBtn);
  Serial.print("state");
  Serial.println(state);
  Serial.print("rpm");
  Serial.println(rpm);
  Serial.print("volt");
  Serial.println(volt);
  Serial.print("fail");
  Serial.println(fail);
  Serial.print("invTmp");
  Serial.println(invTmp);
  Serial.print("torque");
  Serial.println(torque);
  Serial.print("brake");
  Serial.println(brake);
  Serial.print("speed");
  Serial.println(speed);
  Serial.print("kw");
  Serial.println(kw);
  Serial.print("current