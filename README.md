# SafeHouse Smart Room · ESP32 + MQTT + Flutter + Supabase

A compact smart-room demo that monitors **smoke**, **light**, and **motion**, displays status on a **16×2 I²C LCD**, locks/unlocks a door via a **servo** (keypad + app control), and streams data over **MQTT (HiveMQ Cloud)** for a **Flutter** app UI. Historical logs & auth can be handled by **Supabase**.

---

## ✨ Features

* **ESP32 firmware**

  * MQ‑2 smoke detection (buzzer alarm)
  * LDR auto‑light control (on when dark)
  * IR motion alarm (buzzer)
  * 4×4 keypad password unlock (`#` to submit, `*` to clear)
  * Servo door lock with auto‑close (default 5s)
  * 16×2 I²C LCD status
  * MQTT JSON: publishes telemetry and receives commands
* **MQTT (HiveMQ Cloud)**

  * Publish topic: `safehouse/data` (JSON)
  * Subscribe topic: `safehouse/servo` (JSON commands: `{"servo":"open"}` / `{"servo":"close"}`)
* **Flutter app**

  * Realtime dashboard (subscribe `safehouse/data`)
  * Door control (publish to `safehouse/servo`)
* **Supabase (optional)**

  * App auth
  * Persist telemetry & events

---

## 🧰 Hardware

* ESP32 dev board
* MQ‑2 smoke sensor → **analog**
* LDR + resistor → **analog** (voltage divider)
* IR motion sensor → **digital**
* SG90/180° servo (door lock)
* Buzzer (alarm)
* LED (status / room light)
* 16×2 I²C LCD (PCF8574, default addr `0x27`)
* 5V supply (servo power), common GND with ESP32

> **Power tip:** Servos cause brown‑outs. Power servo from a stable 5V source; **share ground** with the ESP32.

---

## 🔌 Pin Map (matches the provided sketch)

| Part        | ESP32 Pin                        | Notes                                               |
| ----------- | -------------------------------- | --------------------------------------------------- |
| Smoke MQ‑2  | `GPIO32`                         | **Analog** read                                     |
| LDR         | `GPIO34`                         | **Analog** read                                     |
| IR motion   | `GPIO35`                         | Input‑only pin; digital read (active‑low in sketch) |
| Servo       | `GPIO23`                         | LEDC PWM @ 50 Hz                                    |
| Buzzer      | `GPIO18`                         | Digital out                                         |
| LED         | `GPIO2`                          | Digital out                                         |
| LCD (I²C)   | `GPIO21` SDA, `GPIO22` SCL       | Default Wire pins                                   |
| Keypad rows | `GPIO13, GPIO12, GPIO14, GPIO27` |                                                     |
| Keypad cols | `GPIO26, GPIO25, GPIO33, GPIO32` |                                                     |

> Adjust pins to your actual wiring if needed.

---

## 🏗️ Repository Structure

```
SafeHouse/
├─ firmware/
│  └─ esp32/
│     ├─ safehouse_esp32.ino         # Your working sketch
│     └─ README_firmware.md          # (optional) wiring pics & notes
├─ app/
│  └─ flutter/                       # Your Flutter project
├─ cloud/
│  └─ supabase_schema.sql            # (optional) telemetry schema
├─ docs/
│  ├─ wiring-diagram.png
│  ├─ maquette-photos/
│  └─ flowchart.png
├─ .gitignore
└─ README.md                         # this file
```

---

## 🔑 Configuration (Firmware)

Edit these in the sketch:

```cpp
// WiFi
const char* ssid = "<YOUR_WIFI_SSID>";
const char* password = "<YOUR_WIFI_PASSWORD>";

// HiveMQ Cloud
const char* mqtt_server = "<YOUR_CLUSTER>.s1.eu.hivemq.cloud";
const int   mqtt_port   = 8883; // TLS
const char* mqtt_user   = "<YOUR_MQTT_USERNAME>";
const char* mqtt_pass   = "<YOUR_MQTT_PASSWORD>";
```

> For submissions, avoid committing real secrets. Consider `secrets.h` (ignored) and a `secrets.example.h` template.

---

## 📡 MQTT Topics & Payloads

### Publish: `safehouse/data`

```json
{
  "smoke": 0,
  "light": "dark",
  "motion": 1,
  "door": "open"
}
```

* `smoke`: `0`/`1`
* `light`: `"dark"` or `"light"`
* `motion`: `0`/`1`
* `door`: `"open"` or `"closed"`

### Subscribe: `safehouse/servo`

```json
{"servo":"open"}
```

```json
{"servo":"close"}
```

---

## 🧪 Building & Flashing (Arduino IDE)

1. **Boards Manager** → Install **ESP32** by Espressif.
2. **Libraries** (Sketch → Include Library → Manage Libraries):

   * PubSubClient
   * ESP32Servo
   * Keypad
   * LiquidCrystal\_I2C
   * ArduinoJson
3. Open `firmware/esp32/safehouse_esp32.ino` and set your WiFi/MQTT creds.
4. Select your board/port → **Upload**.
5. Serial Monitor @ **115200** baud.

> **Servo direction:** If your maquette needs counter‑clockwise for open, invert the open/close angles in the `for` loops as noted in the code comments.

---

## 📱 Flutter App Notes

* Use `mqtt_client` package.
* Connect with TLS to HiveMQ Cloud using the same host/port/username/password.
* **Publish** to `safehouse/servo` with JSON:

  ```dart
  final payload = '{"servo":"open"}';
  final builder = MqttClientPayloadBuilder()..addString(payload);
  client.publishMessage('safehouse/servo', MqttQos.atLeastOnce, builder.payload!);
  ```
* **Subscribe** to `safehouse/data` and parse JSON to update UI.
* (Optional) Write incoming messages to Supabase.

---

## 🗄️ Supabase (Optional)

Minimal telemetry table:

```sql
create table if not exists telemetry (
  id bigint generated always as identity primary key,
  ts timestamptz default now(),
  smoke int,
  light text,
  motion int,
  door text
);
```

Insert from Flutter after decoding `safehouse/data`.

---

## 🧰 .gitignore (suggested)

```gitignore
# OS
.DS_Store
Thumbs.db

# Arduino / PlatformIO / VSCode
build/
.pio/
.vscode/
*.bin
*.elf
*.map

# Flutter
.dart_tool/
.packages
.pub-cache/
build/
**/GeneratedPluginRegistrant.*
android/.gradle/
android/local.properties
ios/Pods/
ios/.symlinks/

# Secrets
firmware/esp32/secrets.h
.env
```

---

## 🚀 Demo Flow

1. Power ESP32 + servo (stable 5V for servo; common GND).
2. ESP32 connects to WiFi & HiveMQ Cloud.
3. LCD shows system status.
4. Flutter app subscribes `safehouse/data` & shows telemetry.
5. From app, publish `{"servo":"open"}` to `safehouse/servo` → door opens; auto‑closes after 5s.

---

## 🧯 Troubleshooting

* **No servo movement from app**: Ensure you publish to **`safehouse/servo`** with valid JSON. Check broker username/password and TLS port **8883**.
* **JSON parse failed**: Validate JSON (double quotes, no trailing commas).
* **Brown‑outs / resets**: Use external 5V for servo; share ground.
* **Wrong LCD address**: Scan I²C or try `0x3F`.
* **WiFi/MQTT creds leaked**: Rotate credentials and commit placeholders.

---

## 👥 Credits / Roles

* **Hardware & Maquette:** *Name*
* **Firmware (ESP32 + MQTT + LCD + Keypad):** *Name*
* **Flutter App (UI + MQTT + Supabase):** *Name*
* **Cloud (HiveMQ, Node‑RED, Supabase):** *Name*
* **Docs, Report & Presentation:** *Name*

---

## 📄 License

You can add an MIT License or keep the repo private for your submission.
