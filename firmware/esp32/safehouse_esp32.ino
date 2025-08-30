#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ESP32Servo.h>
#include <Keypad.h>
#include <LiquidCrystal_I2C.h>
#include <ArduinoJson.h>   // added for JSON

// WiFi credentials
const char* ssid = "Kayan Space";
const char* password = "Kayan12345";

// HiveMQ Cloud credentials
const char* mqtt_server = "195bdf59edc94f0f82ca8280f9aeea8c.s1.eu.hivemq.cloud";
const int mqtt_port = 8883;  // TLS port
const char* mqtt_user = "Morse";
const char* mqtt_pass = "Morsesama9";

#define IR_PIN 19
#define LED_PIN 2
#define LDR_PIN 35
#define BUZZER_PIN 5
#define SMOKE_PIN 34

int servoPin = 23;
const int freq = 50;
const int resolution = 16;

uint32_t angleToDuty(int angle) {
  uint32_t us = map(angle, 0, 180, 500, 2400);
  uint32_t maxDuty = (1UL << resolution) - 1;
  return (us * maxDuty) / 20000UL;
}

bool isDark = false;
bool ledOn = false;
bool motionDetected = false;
bool smokeDetected = false;

bool smokeAlarmActive = false;
bool motionAlarmActive = false;

unsigned long lastPublishTime = 0;
const int PUBLISH_INTERVAL = 1000;

const int LIGHT_THRESHOLD = 1000;
const int SMOKE_THRESHOLD = 500;

// ====== Keypad Setup ======
const byte ROWS = 4;
const byte COLS = 4;
char keys[ROWS][COLS] = {
  {'1','2','3','A'},
  {'4','5','6','B'},
  {'7','8','9','C'},
  {'*','0','#','D'}
};
byte rowPins[ROWS] = {13, 12, 14, 27}; 
byte colPins[COLS] = {26, 25, 33, 32};
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

// ====== LCD Setup ======
LiquidCrystal_I2C lcd(0x27, 16, 2);
unsigned long lastUpdate = 0;

// Password logic
String inputPassword = "";
String correctPassword = "1234";
bool doorOpen = false;
unsigned long doorOpenTime = 0;
const unsigned long DOOR_OPEN_DURATION = 5000; // auto close after 5s

WiFiClientSecure espClient;
PubSubClient client(espClient);

void setup() {
  Serial.begin(115200);

  pinMode(IR_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  setup_wifi();
  espClient.setInsecure();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);

  digitalWrite(LED_PIN, LOW);

  ledcAttach(servoPin, freq, resolution);
  ledcWrite(servoPin, angleToDuty(90)); // start closed (REVERSED: now 180°)

  // LCD Init
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Smart Home");
  lcd.setCursor(0, 1);
  lcd.print("System Ready");
  delay(2000);
  lcd.clear();

  Serial.println("Smart Home Security System Started");
}

void loop() {
  if (!client.connected()) reconnect();
  client.loop();

  readSensors();
  handleSmoke();
  handleLighting();
  handleMotion();

  handleKeypad();

  // auto-close door after time
  if (doorOpen && millis() - doorOpenTime > DOOR_OPEN_DURATION) {
    for (int a = 0; a <= 90; a++) { // REVERSED: close by going from 0° to 180°
      ledcWrite(servoPin, angleToDuty(a));
      delay(15);
    }
    doorOpen = false;
    Serial.println("Door auto-closed");
  }

  unsigned long now = millis();
  if (now - lastPublishTime >= PUBLISH_INTERVAL) {
    publishData();
    lastPublishTime = now;
  }

  // Update LCD every 500ms
  if (millis() - lastUpdate > 500) {
    updateDisplay();
    lastUpdate = millis();
  }
}

void readSensors() {
  int smokeLevel = analogRead(SMOKE_PIN);
  smokeDetected = (smokeLevel > SMOKE_THRESHOLD);

  int lightLevel = analogRead(LDR_PIN);
  isDark = (lightLevel < LIGHT_THRESHOLD);

  motionDetected = !digitalRead(IR_PIN);

  Serial.print("Smoke: "); Serial.print(smokeLevel);
  Serial.print(", Light: "); Serial.print(lightLevel);
  Serial.print(", Motion: "); Serial.print(motionDetected);
  Serial.println();
}

void handleSmoke() {
  if (smokeDetected && !smokeAlarmActive) {
    smokeAlarmActive = true;
    digitalWrite(BUZZER_PIN, HIGH);
    Serial.println("SMOKE DETECTED! Alarm ON");
  } else if (!smokeDetected && smokeAlarmActive) {
    smokeAlarmActive = false;
    digitalWrite(BUZZER_PIN, LOW);
    Serial.println("Smoke cleared. Alarm OFF");
  }
}

void handleLighting() {
  if (isDark && !ledOn) {
    ledOn = true;
    digitalWrite(LED_PIN, HIGH);
    Serial.println("Dark detected. LED ON");
  } else if (!isDark && ledOn) {
    ledOn = false;
    digitalWrite(LED_PIN, LOW);
    Serial.println("Light detected. LED OFF");
  }
}

void handleMotion() {
  if (motionDetected && !motionAlarmActive) {
    motionAlarmActive = true;
    digitalWrite(BUZZER_PIN, HIGH);
    Serial.println("MOTION DETECTED! - ALARM!");
  } else if (!motionDetected && motionAlarmActive) {
    motionAlarmActive = false;
    digitalWrite(BUZZER_PIN, LOW);
    Serial.println("Motion stopped. Alarm cleared.");
  }
}

void handleKeypad() {
  char key = keypad.getKey();
  if (key) {
    Serial.print("Key pressed: ");
    Serial.println(key);

    if (key == '#') {  // Enter
      if (inputPassword == correctPassword) {
        Serial.println("Password correct - opening door");
        lcd.clear();
        lcd.print("Access Granted");
        for (int a = 90; a >= 0; a--) { // REVERSED: open by going from 180° to 0°
          ledcWrite(servoPin, angleToDuty(a));
          delay(15);
        }
        doorOpen = true;
        doorOpenTime = millis();
      } else {
        Serial.println("Wrong password!");
        lcd.clear();
        lcd.print("Wrong Password");
        delay(1000);
      }
      inputPassword = "";
    } else if (key == '*') {
      inputPassword = "";
      Serial.println("Password cleared");
    } else {
      inputPassword += key;
    }
  }
}

// PUBLISH JSON DATA
void publishData() {
  StaticJsonDocument<200> doc;
  doc["smoke"] = smokeDetected ? 1 : 0;
  doc["light"] = isDark ? "dark" : "light";
  doc["motion"] = motionDetected ? 1 : 0;
  doc["door"] = doorOpen ? "open" : "closed";

  char buffer[200];
  serializeJson(doc, buffer);

  client.publish("safehouse/data", buffer);
  Serial.print("Published JSON: ");
  Serial.println(buffer);
}

// SUBSCRIBE JSON COMMANDS
void callback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];

  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  Serial.println(msg);

  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, msg);
  if (error) {
    Serial.println("JSON parse failed");
    return;
  }

  if (doc.containsKey("servo")) {
    String command = doc["servo"];
    if (command == "open") {
      for (int a = 90; a >= 0; a--) { // REVERSED: open by going from 180° to 0°
        ledcWrite(servoPin, angleToDuty(a));
        delay(15);
      }
      doorOpen = true;
      doorOpenTime = millis();
      Serial.println("Servo OPEN");
    } else if (command == "close") {
      for (int a = 0; a <= 90; a++) { // REVERSED: close by going from 0° to 180°
        ledcWrite(servoPin, angleToDuty(a));
        delay(15);
      }
      doorOpen = false;
      Serial.println("Servo CLOSE");
    }
  }
}

void updateDisplay() {
  lcd.clear();

  if (smokeAlarmActive) {
    lcd.setCursor(0, 0);
    lcd.print("!!! SMOKE ALARM");
  } else if (motionAlarmActive) {
    lcd.setCursor(0, 0);
    lcd.print("!! MOTION ALARM");
  } else if (inputPassword.length() > 0) {
    lcd.setCursor(0, 0);
    lcd.print("Enter Password:");
    lcd.setCursor(0, 1);
    for (int i = 0; i < inputPassword.length(); i++) {
      lcd.print("*");
    }
  } else {
    lcd.setCursor(0, 0);
    lcd.print("L:");
    lcd.print(ledOn ? "ON " : "OFF");
    lcd.print(" D:");
    lcd.print(doorOpen ? "OPEN " : "SHUT");

    lcd.setCursor(0, 1);
    lcd.print("M:");
    lcd.print(motionDetected ? "Y " : "N ");
    lcd.print("S:");
    lcd.print(smokeDetected ? "Y" : "N");
  }
}

void setup_wifi() {
  delay(10);
  Serial.println("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Connecting to MQTT...");
    if (client.connect("ESP32Client", mqtt_user, mqtt_pass)) {
      Serial.println("connected");
      client.subscribe("safehouse/servo");  // still listening, but expects JSON
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      delay(2000);
    }
  }
}
