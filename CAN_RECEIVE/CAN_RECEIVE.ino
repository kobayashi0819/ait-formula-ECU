//byte Number は　rx_frame.data.u8[0]の　[]の中のこと
//最大トルクは365行付近で変更
#include "ESP32CAN.h"    //ESP32のCAN通信ライブラリのインクルード
#include "CAN_config.h"  //CAN通信の設定ファイルをインクルード
#include <WiFi.h>
#include <WiFiUdp.h>
#include <ArduinoJson.h>
#include <math.h>
// #include <WebSocketsClient.h>
#define TIRE 1.67362    //タイヤ円周長
#define GEAR 11.9       //ギア比, AIT23,24は13.8, AIT25は11.9
#define TX GPIO_NUM_5   //受信用のTXピンの定義5
#define RX GPIO_NUM_4   //送信用のRXピンの定義4
CAN_device_t CAN_cfg;   //CANデバイスの設定を格納する変数を定義
#define STARTER_PIN 25  //ピンの定義


const unsigned long UART_BAUD = 115200;  // UARTのボーレート
const unsigned long CAN_SPEED = 500000;  // CANのボーレート


unsigned long previousMillisCAN = 0;  //最後にCAN通信を行った時間
const long intervalCAN = 10;          //CAN通信のインターバル（ミリ秒）


unsigned long previousMillis = 0;  // データを最後に送信した時間を保存する変数
const long interval = 30;          // データを送信する間隔（300ms） 400だと13loop毎に送信される．


uint8_t sendData[15];



//
//情報の定義
int state = 0;
int rpm = 0;
int Maxrpm = 0;
int current = 0;
int volt = 0;
int invTmp = 0;
int fail = 0;
int maxTorque = 0;
int MaxTorque = 0;
int minTorque = 0;
int torque_seigyo = 0;
int mtTmp = 0;
int sterterBtn = 0;
int speed = 0;
float kw = 0;  //floatは浮動小数点を扱える
int torque = 0;
int seigyo = 0;
int work = 0;
int readings[5];
int readIndex = 0;
int total = 0;
int torquerequest = 0;
int Acceleratoropening = 0;
float torquefloat = 0;
int ERROR = 0;
int OUTPUTtorque = 0;
int Hvoltage = 0; //データ送信用の高電圧

// ピンの定数定義
const int APPS1Pin = 34;  //A0　 白
const int APPS2Pin = 35;  //A1　　青
const int brake = 12;
const int BSPD = 32;
const int minValue = 1500;  //2109-135 =1974  1489 -89 = 1400　誤差を含んだ上での範囲
const int maxValue = 4095;  //
const int CurrentPin = 27;  //電流値が45Aを超えたら，3Vが入力される
const int AIR = 26;
// ブレーキとアクセルの同時踏みがあったかどうかを記憶する変数
bool isBrakeAndAcceleratorPressedPreviously = false;

void setup() {
  Serial.begin(230400);                                   //シリアル通信の速度
  Serial2.begin(57600, SERIAL_8N1, 16, 17, false, 1024);  // 修正済み
  //ピン
  pinMode(25, INPUT);  //StarterButton
  pinMode(APPS1Pin, INPUT);
  pinMode(APPS2Pin, INPUT);
  pinMode(BSPD, INPUT);
  pinMode(brake, INPUT);
  pinMode(CurrentPin, INPUT);
  //INPUTはESP32に入力すること
  //CAN
  CAN_cfg.speed = CAN_SPEED_1000KBPS;
  CAN_cfg.tx_pin_id = TX;
  CAN_cfg.rx_pin_id = RX;
  CAN_cfg.rx_queue = xQueueCreate(10, sizeof(CAN_frame_t));
  ESP32Can.CANInit();
  Serial.println("set up");
  //sendDataの初期化（例として全てのバイトを0x00に設定）
  for (int i = 0; i < 15; i++) {
    sendData[i] = 0x00;
  }

  for (int i = 0; i < 5; i++) {
    readings[i];
  }
}

void loop() {
  unsigned long currentMillis = millis();  // 現在の時間を取得


  int APPS1Value = analogRead(APPS1Pin);
  int APPS2Value = analogRead(APPS2Pin);
  int APPSAve = (APPS1Value + 6204 - APPS2Value) / 2;
  float voltage1 = APPS1Value * (5 / 6204.0);                //(3.3 / 4095)でも一緒
  float voltage2 = APPS2Value * (5 / 6204.0);                //(5 / 6204.0);
  float APPS1opening = map(APPS1Value, 3750, 500, 0, 100);  //白
  float APPS2opening = map(APPS2Value, 980, 4095, 0, 100);  //青
  // float APPS2opening = map(APPS2Value, 2267, 4095, 0, 100);  //青
  // float Acceleratoropening = APPS2opening;  //偏差を考慮しない操作性にするため，1系統でアクセル制御
  float Acceleratoropeningfloat = APPS1opening;  //偏差を考慮しない操作性にするため，1系統でアクセル制御
  int Accelerator = (int)Acceleratoropeningfloat;
  // // float Acceleratoropening = (APPS1opening + APPS2opening) / 2;

  int brakenama = analogRead(brake);
  int CurrentSensor = analogRead(CurrentPin);

  total = total - readings[readIndex];
  readings[readIndex] = Accelerator;
  total = total + readings[readIndex];
  readIndex = (readIndex + 1) % 5;
  Acceleratoropening = (int)(total / 5);


  int bspd = analogRead(BSPD);
  Serial.print("BSPD: ");
  Serial.println(bspd, 0);
  //sterterBtn
  //3V → 3722 else → else if(btnRead < 3722)
  int btnRead = digitalRead(STARTER_PIN);


  // if (btnRead == 1) {
  //   if (brakenama > 50) {
  //     if (sterterBtn < 20) {
  //       sterterBtn++;
  //     }
  //   }
  // } else {
  //   if (sterterBtn > 1) {
  //     sterterBtn--;
  //   }
  //   //sterterBtn = 0;
  // }

  if (btnRead ==  1) {
    if(sterterBtn < 20 ) {
      sterterBtn++;
    }
  } else {
    if (sterterBtn > 1) {
      sterterBtn--;
    }
  }


  // if (brakenama > 900) {
  //   if (btnRead == 4095) {
  //     if (sterterBtn < 20) {
  //       sterterBtn++;
  //     }
  //   } else {
  //     if (sterterBtn > 1) {
  //       sterterBtn--;
  //     }
  //     //sterterBtn = 0;
  //   }
  // }

  //速度
  speed = (rpm * 60 * TIRE) / (1000 * GEAR);
  kw = volt * current;
  // (2 * 3.14 * torque * rpm) / (60 * 1000);
  //エラー時
  if (fail > 3) {
    Serial.println("ERROR!");
  }
  // シリアルモニターに表示
  Serial.println("--------------------------------------------------------");
  Serial.println("--------------------------------------------------------");
  Serial.println("--------------------------------------------------------");
  Serial.print("APPS1 Voltage: ");
  Serial.print(voltage1, 3);  // 3桁までの小数点以下を表示
  Serial.println(" V");
  // Serial.println(APPS1opening, 0);
  Serial.print("APPS2 Voltage: ");
  Serial.print(voltage2, 3);  // 3桁までの小数点以下を表示
  Serial.println(" V");

  // Serial.println(APPS2opening, 0);
  // Serial.println(APPS1Value + APPS2Value, 0);
  // Serial.print("偏差");
  // Serial.println(abs(APPS1opening - APPS2opening));
  Serial.print("Acceleratoropening");
  Serial.println(Acceleratoropening);
  Serial.print("BSPD : ");
  Serial.println(isBrakeAndAcceleratorPressedPreviously);
  Serial.print("ブレーキ生値 : ");
  Serial.println(brakenama);
  Serial.print("btnRead : ");
  Serial.println(btnRead);
  Serial.print("sterterBtn : ");
  Serial.println(sterterBtn);
  
  Serial.print("相電流");
  Serial.println(current);

  //Ready to Driveモードの時、モーターを回す
  //CAN
  CAN_frame_t rx_frame;
  CAN_frame_t tx_frame;
  //receive next CAN frame from queue
  if (xQueueReceive(CAN_cfg.rx_queue, &rx_frame, 3 * portTICK_PERIOD_MS) == pdTRUE) {  //CAN通信ができたかどうか判断する関数
    if (rx_frame.FIR.B.RTR != CAN_RTR) {
      //MG-ECU-1
      if (rx_frame.MsgID == 0x311) {                    //311だとMG-ECU-1
        state = getBitData(rx_frame.data.u8[0], 3, 3);  //8バイトあるうちの，0バイト目の3つ目から3つぶん
        rpm = rx_frame.data.u8[2] << 8;                 //8ビット左にずらす，256倍？
        //CANフレームから受信したデータの3番目のバイトです。
        //<< 8 は、このバイトの値を8ビット左シフトする操作です。8ビット左シフトすることで、このバイトの値を16倍しています。
        rpm += rx_frame.data.u8[1] - 14000;  //-14000はオフセットのこと
        if (rpm < 0) {                       //rpmの絶対値を取る　
          rpm = rpm * -1;
        }
        current = getBitData(rx_frame.data.u8[4], 0, 2) << 8;
        //getBitData(rx_frame.data.u8[4], 0, 2) は、rx_frame.data.u8[4] から0ビット目から始まる2ビットのデータを抽出することを意味します。
        current += rx_frame.data.u8[3];
        volt = getBitData(rx_frame.data.u8[5], 0, 4) << 6;
        volt += getBitData(rx_frame.data.u8[4], 2, 6);
        fail = getBitData(rx_frame.data.u8[7], 5, 3);
        Serial.print("State: ");
        Serial.println(state);
        Serial.print("電圧: ");
        Serial.println(volt);
      }
      //MG-ECU-2
      if (rx_frame.MsgID == 0x321) {
        invTmp = rx_frame.data.u8[0] - 40;  //オフセットで−40
        maxTorque = getBitData(rx_frame.data.u8[2], 0, 4) << 8;
        minTorque = rx_frame.data.u8[3] << 4;
        minTorque += getBitData(rx_frame.data.u8[2], 5, 4);
        mtTmp = rx_frame.data.u8[4] - 40;
        Serial.print("Received CAN frame, ID: ");
        Serial.println(rx_frame.MsgID, HEX);
        Serial.print("Data Length: ");
        Serial.println(rx_frame.FIR.B.DLC);
        Serial.print("Data: ");
        for (int i = 0; i < rx_frame.FIR.B.DLC; i++) {  //受信する８バイトの生データを16ビットで１バイト目から書き出す，HEXは16進数のこと
          Serial.print(rx_frame.data.u8[i], HEX);
          Serial.print(" ");
        }
        Serial.println();
        Serial.print("invTmp: ");
        Serial.println(invTmp);
        Serial.print("最大トルク");
        Serial.println(maxTorque);
        Serial.print("最小トルク");
        Serial.println(minTorque);
        Serial.print("mtTmp: ");
        Serial.println(mtTmp);
        Serial.print("rpm: ");
        Serial.println(rpm);
      }

      //txが送信、rxが受信
      tx_frame.FIR.B.FF = CAN_frame_std;
      tx_frame.MsgID = 0x301;
      tx_frame.FIR.B.DLC = 8;
      tx_frame.data.u8[0] = 0x00;
      tx_frame.data.u8[1] = 0xD0;
      tx_frame.data.u8[2] = 0x07;
      tx_frame.data.u8[3] = 0x00;
      tx_frame.data.u8[4] = 0x00;
      tx_frame.data.u8[5] = 0x00;
      tx_frame.data.u8[6] = 0x00;
      tx_frame.data.u8[7] = 0x00;

      //prechargeの時
      if (state == 1) {
        // MGECU実行要求をON  -> torque controlへ
        if (sterterBtn > 5 && volt > 50) {
          tx_frame.data.u8[0] = 0x01;  //0x01はEnableで，MG-ECU実行要求をONにする
          Serial.println("Precharge");
        }
      }
      //rapid dischargeの時
      if (state == 7) {
        tx_frame.data.u8[0] = 0x02;  //平滑コンデンサ放電要求をONにして，MG-ECU実行要求をOFFにする
        Serial.println("Discharge");
      }
      Serial.println(state);
      Serial.println(sterterBtn);
    }
    Serial.println("CANフレームの受信に成功しました");
  } else {
    // CANフレームが受信されなかった場合の処理
    Serial.println("CANフレームの受信に失敗しました");
    return;  // loop()関数から抜け出す
  }

  //アクセル制御開始
  // if (bspd <= 2000) {  //BSPDが失陥を検知したときは5Vになる
  // Serial.println("BSPD : OK");
  if (Acceleratoropening > 100) {
    Acceleratoropening = 100;
  }
  
  if (isBrakeAndAcceleratorPressedPreviously == false) {  //isBrakeAndAcceleratorPressedPreviouslyというstateでtrueかfalseか判断
    // Ready to Driveモードの時、モーターを回す
    ERROR = 1;
    Serial.println("アクセル制御に入った");
    // if ((APPS1Value >= minValue && APPS1Value <= maxValue) && (APPS2Value >= minValue && APPS2Value <= maxValue)) {
    // 各APPSの値を比較し、値に10%以上の差があるか判定
    // if ((APPS1opening - APPS2opening < 50) or (APPS1opening - APPS2opening > -50)) {  //中身変えた.   //本番は10％
    // APPSが範囲内か判定し、モーターの動作を決める
    if (Acceleratoropening >= 0 && Acceleratoropening <= 101) {
      // ブレーキが踏まれているか判定
      ERROR = 2;
      if (brakenama > 2000) {  //ブレーキの生データを取得するように変更する
        // if (brakenama > 840) {  //ブレーキの生データを取得するように変更する
        ERROR = 3;
        Serial.println("ブレーキが踏まれています,またはブレーキはずし");
        Serial.println("モーター停止");
        // アクセルが踏まれているか判定
        if (state == 3) {
          if (sterterBtn < 5) {  //readytodriveがONになっていないと，トルクコントロールにははいらない
            tx_frame.data.u8[0] = 0x02;
          } else {
            tx_frame.data.u8[0] = 0x01;  //MG-ECU実行要求ONにする
            Serial.println("モーター停止1");
            torque = 0;
            tx_frame.data.u8[1] = 208 - (torque * 2);
            //0x07= 1792,  (1792+204)*0.5-1000=-2;
          }
        }                               //いらないかも？
        if (Acceleratoropening > 30) {  //5or25%??  //シェイクダウン用にAPPS1openingの値を変える
          isBrakeAndAcceleratorPressedPreviously = true;
          Serial.println("ブレーキとアクセルの同時踏みがありました");
          ERROR = 4;
        }
      } else {  //ブレーキが踏まれていない
                // if (Acceleratoropening > 0) {  //アクセルが踏まれている
        //torque controlの時
        if (state == 3) {
          if (sterterBtn < 5) {  //readytodriveがONになっていないと，トルクコントロールにははいらない
            tx_frame.data.u8[0] = 0x02;
          } else {
            // tx_frame.data.u8[0] = 0x01;  //MG-ECU実行要求ONにする
            // Serial.println("モーター回転");
            // if (rpm < 2900) {
            //   // torque = maxTorque * Acceleratoropening * 0.01;
            //   torque = 30 * Acceleratoropening * 0.01;  //Acceleratoropening = APPS2opening
            // } else {
            //   MaxTorque = 18240 * 60 / 2 * 3.14 * rpm;  //電流に制限があるため，回転数によるMaxTorqueを制限する
            //   torque = MaxTorque * Acceleratoropening * 0.01;
            // }
            tx_frame.data.u8[0] = 0x01;  //MG-ECU実行要求ONにする
            Serial.println("モーター回転");
            //work = 仕事量 40Aで制御
            //workC = 仕事量　電流値で制御


            torque_seigyo = 60;
            work = volt * 80;                           //最大電圧は396.3 ,80はアンペア制限、2025は100Aまでいける
            Maxrpm = (int)((work * 60) / (2 * 3.14 * torque_seigyo));  //Maxrpmを変える際は一番右の値(35)を変える. 35の時は4868.10737
            Serial.print("akuseru");
            Serial.println(Acceleratoropening);

            //4878に低い値のMaxrpmを入れてちゃんと動作するか確認する

            if (rpm < Maxrpm) {  //45A,396.3のとき4868.10737
              torquefloat = torque_seigyo * Acceleratoropening * 0.01;  ///////最大トルクを変えるには左辺の数字を変える
            } else if (rpm > Maxrpm) {
              MaxTorque = (int)((work * 60) / (2 * 3.14 * rpm));  //電流に制限があるため，回転数によるMaxTorqueを制限する
              //⇧ 80A, 5000rpmのとき53
              // MaxTorque = (int)(383 * 60  * 60 / 2 * 3.14 * rpm);
              torquefloat = MaxTorque * Acceleratoropening * 0.01;
            }

            // torquefloat = 30 * Acceleratoropening * 0.01; //2025.7/15シェイクダウン時


            torque = (int)torquefloat;
            tx_frame.data.u8[1] = 208 - (torque * 2);
            //0x07= 1792,  (1792+204)*0.5-1000=-2;
            ERROR = 0;
          }
        }
        // } else {
        //   if (state == 3) {
        //     if (sterterBtn < 5) {  //readytodriveがONになっていないと，トルクコントロールにははいらない
        //       tx_frame.data.u8[0] = 0x02;
        //     } else {
        //       tx_frame.data.u8[0] = 0x01;  //MG-ECU実行要求ONにする
        //       Serial.println("モーター停止2");
        //       torque = 0;
        //       tx_frame.data.u8[1] = 208 - (torque * 2);
        //       //0x07= 1792,  (1792+204)*0.5-1000=-2;
        //     }
        //   }
        // }
      }  //トルク０をここにも入れる必要がある？
    } else {
      ERROR = 5;
      Serial.println("APPSが範囲外                 アウト");
      Serial.println("モーター停止3");
      if (state == 3) {
        if (sterterBtn < 5) {  //readytodriveがONになっていないと，トルクコントロールにははいらない
          tx_frame.data.u8[0] = 0x02;
        } else {
          tx_frame.data.u8[0] = 0x01;  //MG-ECU実行要求ONにする
          Serial.println("モーター停止4");
          torque = 0;
          tx_frame.data.u8[1] = 208 - (torque * 2);
          //0x07= 1792,  (1792+204)*0.5-1000=-2;
        }
      }
    }
    // } else {
    //   Serial.println("10%                       アウト");
    //   Serial.println("モーター停止5");
    //   if (state == 3) {
    //     if (sterterBtn < 5) {  //readytodriveがONになっていないと，トルクコントロールにははいらない
    //       tx_frame.data.u8[0] = 0x02;
    //     } else {
    //       tx_frame.data.u8[0] = 0x01;  //MG-ECU実行要求ONにする
    //       Serial.println("モーター停止6");
    //       torque = 0;
    //       tx_frame.data.u8[1] = 208 - (torque * 2);
    //       //0x07= 1792,  (1792+204)*0.5-1000=-2;
    //     }
    //   }
    // }
  } else {
    //ブレーキ同時踏み
    ERROR = 6;
    if (state == 3) {
      if (sterterBtn < 5) {  //readytodriveがONになっていないと，トルクコントロールにははいらない
        tx_frame.data.u8[0] = 0x02; //平滑コンデンサ放電要求をONにして，MG-ECU実行要求をOFFにする
        //state7に移る
      } else {
        tx_frame.data.u8[0] = 0x01;  //MG-ECU実行要求ONにする
        Serial.println("モーター停止9");
        torque = 0;
        tx_frame.data.u8[1] = 208 - (torque * 2);
        //0x07= 1792,  (1792+204)*0.5-1000=-2;
      }
    }
  }


  Serial.println(isBrakeAndAcceleratorPressedPreviously);
  if (isBrakeAndAcceleratorPressedPreviously == true) {  //ブレーキアクセル同時踏み
    ERROR = 7;
    Serial.println("trueです");
    // アクセルが5%以下になるまでモーター停止
    if (Acceleratoropening > 30) {  //アクセルが5％以下になるまでトルク0，trueのまま
      isBrakeAndAcceleratorPressedPreviously = true;
      Serial.print("ブレーキ : ");
      Serial.println(isBrakeAndAcceleratorPressedPreviously);
      Serial.print("ブレーキ生値 : ");
      Serial.println(brakenama);
      Serial.println("アクセル5%以上のためモーター停止");
      //torque controlの時
      if (state == 3) {
        tx_frame.data.u8[0] = 0x01;
        torque = 0;
        tx_frame.data.u8[1] = 208 - (torque * 2);
        //0x07= 1792,  (1792+204)*0.5-1000=-2;
      }
    }
    if (Acceleratoropening <= 29) {  //組み付け後に確認
      if (brakenama < 840) {
        isBrakeAndAcceleratorPressedPreviously = false;
        Serial.println("アクセルが5%以下になったのでfalseになりました");
      }
    }
  }

  Serial.print("ERROR");
  Serial.println(ERROR);



  //FrontECUシリアル通信
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////
  if (Acceleratoropening < 0) {
    Acceleratoropening = 0;
  } else if (Acceleratoropening > 255) {
    Acceleratoropening = 100;
  }

  OUTPUTtorque = (int)(volt * current * 60000 / 2 * 3.14 * rpm);
  Hvoltage = volt - 145;

  

  if (currentMillis - previousMillis >= interval) {
    uint8_t sendData[15];
    sendData[0] = Acceleratoropening;
    sendData[1] = speed;
    // sendData[1] = sterterBtn; //使ってない（消してもいい）
    sendData[2] = state;
    sendData[3] = rpm & 0xFF;
    sendData[4] = (rpm >> 8) & 0xFF;
    sendData[5] = Hvoltage;
    sendData[6] = (volt >> 8) & 0xFF; //使ってない
    sendData[7] = fail; //使ってない
    sendData[8] = mtTmp;
    sendData[9] = invTmp;
    sendData[10] = torque;
    sendData[11] = brakenama & 0xFF;
    sendData[12] = (brakenama >> 8) & 0xFF;
    sendData[13] = ERROR;
    sendData[14] = current;
    previousMillis = currentMillis;

    Serial.println("Sending data:");
    for (int i = 0; i < 15; i++) {
      Serial.print("Data[");
      Serial.print(i);
      Serial.print("]: ");
      Serial.println(sendData[i]);
    }
    previousMillis = currentMillis;  // データを最後に送信した時間を更新 timestamp = currentMillis;
    Serial2.write(0x02);             // スタートビットを送信 (STX)
    Serial2.write(sendData, sizeof(sendData));
    Serial.println("Data sent.");
  }

  ////////////////////////////////////////////////////////////////////////////////////////////////////////////

  if (currentMillis - previousMillisCAN >= intervalCAN) {
    ESP32Can.CANWriteFrame(&tx_frame);
    if (ESP32Can.CANWriteFrame(&tx_frame) == ESP_OK) {  //CAN通信が送信できたか判断する関数
      Serial.println("CANフレームの送信に成功しました");
    } else {
      Serial.println("CANフレームの送信に失敗しました");
    }
    //最後の送信時間を更新
    previousMillisCAN = currentMillis;
  }
  int apps;
  apps = (int)(APPS1opening / 3);

  // delay(1000);//delayがあると，うまくCAN通信できない
}

// 2進数でindexの位置からcount回分のデータを抜き出す
int getBitData(int data, int index, int count) {
  int result = 0;
  for (int i = 0; i < count; i++) {
    result += bitRead(data, index + i) << i;
  }
  return result;
}
