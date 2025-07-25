// #define BLYNK_TEMPLATE_ID "TMPL6oAT_xyy-"
// #define BLYNK_TEMPLATE_NAME "IOTProject"
// #define BLYNK_AUTH_TOKEN "W1JZvs5v_ddcF7PrWEbt8ah1I68cq8KR"

// #include <WiFi.h>
// #include <BlynkSimpleEsp32.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>

// WiFi
// char ssid[] = "Mia House 306";
// char pass[] = "306306306";

// LCD
LiquidCrystal_I2C lcd(0x27, 20, 4);

// ==== CẢM BIẾN ====
#define SOIL_MOISTURE_PIN 34
#define LM35_PIN 35
#define TRIG_PIN 16
#define ECHO_PIN 17

const int DRY = 4095;
const int WET = 2500;

// ==== THIẾT BỊ ====
#define RELAY_PIN 15
#define SERVO_PIN 2
Servo myServo;

// Blynk điều khiển
int pumpState = 0;
int servoAngle = 0;

// Giá trị Hmax, Vmax mặc định
float Hmax = 30.0;
float Vmax = 1000.0;

// Giá trị người dùng chỉnh
float userHmax = Hmax;
float userVmax = Vmax;

// Ngưỡng độ ẩm (mặc định)
int moistureThreshold = 20;

//bật, tắt automode
bool autoMode = true;

unsigned long lastUpdate = 0;
const unsigned long updateInterval = 3000;

void setup() {
  Serial.begin(115200);
  Wire.begin(5, 18);
  lcd.init();
  lcd.backlight();

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH);  // Mặc định tắt bơm

  myServo.attach(SERVO_PIN);
  myServo.write(servoAngle);  // Mặc định che ô đang mở

  // Blynk.begin(BLYNK_AUTH_TOKEN, ssid, pass);
}

// ---- Đọc cảm biến độ ẩm đất ----
int readSoilMoisture() {
  int value = analogRead(SOIL_MOISTURE_PIN);
  int percent = map(value, DRY, WET, 0, 100);
  return constrain(percent, 0, 100);
}

// ---- Đọc cảm biến nhiệt độ ----
float readTemperature() {
  int adc = analogRead(LM35_PIN);
  float voltage = adc * 3.3 / 4095.0;
  return voltage * 100.0;
}

// ---- Đọc cảm biến siêu âm ----
float readWaterLevel() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  float distance = duration * 0.034 / 2.0;
  float height = userHmax - distance;
  return constrain(height, 0, userHmax);
}

// ---- Nhận tín hiệu từ app Blynk ----
// BLYNK_WRITE(V1) {  // Điều khiển bơm tay
//   pumpState = param.asInt();
//   digitalWrite(RELAY_PIN, pumpState ? LOW : HIGH);
// }

// BLYNK_WRITE(V2) {  // Điều khiển servo tay
//   servoAngle = param.asInt() * 180;
//   myServo.write(servoAngle);
// }

// BLYNK_WRITE(V6) {  // Nhận Hmax
//   userHmax = param.asFloat();
//   Serial.print("Set Hmax: ");
//   Serial.println(userHmax);
// }

// BLYNK_WRITE(V7) {  // Nhận Vmax
//   userVmax = param.asFloat();
//   Serial.print("Set Vmax: ");
//   Serial.println(userVmax);
// }

// BLYNK_WRITE(V8) {  // Nhận ngưỡng độ ẩm
//   moistureThreshold = param.asInt();
//   Serial.print("Set moisture threshold: ");
//   Serial.println(moistureThreshold);
// }

// BLYNK_WRITE(V9) {  // Chế độ tự động / thủ công
//   autoMode = param.asInt();
//   Serial.print("Chế độ hiện tại: ");
//   Serial.println(autoMode ? "TỰ ĐỘNG" : "THỦ CÔNG");
// }

// ---- Gửi dữ liệu lên Blynk ----
// void sendToBlynk(int moisture, float temp, float volumeNow) {
//   Blynk.virtualWrite(V0, WiFi.status() == WL_CONNECTED);
//   Blynk.virtualWrite(V3, moisture);
//   Blynk.virtualWrite(V4, temp);
//   Blynk.virtualWrite(V5, (int)volumeNow);
// }

// ---- Hiển thị LCD ----
void displayToLCD(int moisture, float temp, float volumeNow, bool pumpOn) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Do am dat : ");
  lcd.print(moisture);
  lcd.print("%");

  lcd.setCursor(0, 1);
  lcd.print("Nhiet do  : ");
  lcd.print(temp, 1);
  lcd.print((char)223);
  lcd.print("C");

  lcd.setCursor(0, 2);
  lcd.print("Muc nuoc  : ");
  lcd.print(volumeNow);
  lcd.print("ml");

  lcd.setCursor(0, 3);
  lcd.print("Bom: ");
  lcd.print(pumpOn ? "BAT" : "TAT");
  lcd.print(" Che o: ");
  lcd.print(servoAngle == 180 ? "BAT" : "TAT");
}

// ==== LOOP ====
void loop() {
  // Blynk.run();

  if (millis() - lastUpdate >= updateInterval) {
    lastUpdate = millis();
    // cập nhật dữ liệu cảm biến và xử lý
  }
  int soil = readSoilMoisture();
  float temp = readTemperature();
  float waterHeight = readWaterLevel();
  float volumeNow = (waterHeight / userHmax) * userVmax;

  if (autoMode) {
    // ==== TỰ ĐỘNG ĐIỀU KHIỂN ====
    // Tắt bơm nếu hết nước
    if (volumeNow <= 0 && pumpState == 1) {
      pumpState = 0;
      digitalWrite(RELAY_PIN, HIGH);
      // Blynk.virtualWrite(V1, 0);
      Serial.println("Tắt bơm vì hết nước!");
    }

    // Bật bơm nếu độ ẩm < ngưỡng và còn nước
    if (soil < moistureThreshold && volumeNow > 0 && pumpState == 0) {
      pumpState = 1;
      digitalWrite(RELAY_PIN, LOW);
      // Blynk.virtualWrite(V1, 1);
      Serial.println("Tưới nước tự động vì đất khô!");
    }

    // Tự động che ô nếu nhiệt độ > 35 độ C
    if (temp > 35.0 && servoAngle != 180) {
      servoAngle = 180;
      myServo.write(servoAngle);
      // Blynk.virtualWrite(V2, 1);
      Serial.println("Tự động che ô vì nhiệt độ cao!");
    }
  }

  // sendToBlynk(soil, temp, volumeNow);
  displayToLCD(soil, temp, volumeNow, pumpState);

  // ==== SERIAL MONITOR ====
  Serial.print("Do am dat: ");
  Serial.print(soil);
  Serial.println("%");

  Serial.print("Muc nuoc: ");
  Serial.print(waterHeight, 1);
  Serial.print(" cm (");
  Serial.print((waterHeight / userHmax) * 100, 1); // Calculate water percent for serial output
  Serial.print("%, ~");
  Serial.print(volumeNow, 2);
  Serial.println(" L)");

  Serial.print("Nhiet do: ");
  Serial.print(temp, 1);
  Serial.println(" °C");

  Serial.print("Bom nuoc: ");
  Serial.println((digitalRead(RELAY_PIN) == LOW) ? "BAT" : "TAT"); // Assuming LOW means BAT (active low relay)

  Serial.print("Servo: ");
  Serial.println((servoAngle == 180) ? "180 do" : "0 do");

  Serial.println("----------------------------");

  delay(3000);
}
