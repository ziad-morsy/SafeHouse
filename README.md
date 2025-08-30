# SafeHouse Smart Room · ESP32 + MQTT + Flutter + Supabase

A compact smart-room demo that monitors **smoke**, **light**, and **motion**, displays status on a **16×2 I²C LCD**, locks/unlocks a door via a **servo** (keypad + app control), and streams data over **MQTT (HiveMQ Cloud)** for a **Flutter** app UI. Historical logs & auth can be handled by **Supabase**.

---

## Wokwi Simulation: https://wokwi.com/projects/440166813677089793

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

## 🚀 Demo Flow

1. Power ESP32 + servo (stable 5V for servo; common GND).
2. ESP32 connects to WiFi & HiveMQ Cloud.
3. LCD shows system status.
4. Flutter app subscribes `safehouse/data` & shows telemetry.
5. From app, publish `{"servo":"open"}` to `safehouse/servo` → door opens; auto‑closes after 5s.


## 👥 Credits / Roles

* **Hardware & Maquette:** *Mohammed Saad*
* **Firmware (ESP32 + MQTT + LCD + Keypad):** *Ziad Morsy*
* **Flutter App (UI + MQTT + Supabase):** *Monzir Ali*
* **Cloud (HiveMQ, Node‑RED, Supabase):** *Yousef Mohammed*
* **Docs, Report & Presentation:** *Abdallah*
* **Wokwi Simulation:** *Nour*
