# Remote control options compared – RC, Bluepad32, WiFi app

With the [advanced board](../pcb/advanced/README.md) the ESP32‑S3 drives the **whole
vehicle**: ESC and steering through the PCA9685 outputs, the crane through the TMC2209s. The
control link then carries the throttle too. If it fails unsafely, the vehicle runs away
instead of just stopping a boom. This page compares four ways to control it:

* **A. RC transmitter**: an ELRS receiver on the CRSF port (J7).
* **B. ESP32 + Bluepad32**: a PlayStation controller paired directly with an ESP32.
* **C. WiFi + Android app**: touch joysticks, the phone joins the ESP's access point.
* **D. WiFi + Android app + controller on the phone**: wired (USB‑OTG) or Bluetooth.

## Short answer: is ESP32 + Bluepad32 safe?

**Safe enough for a slow crawler with a crane at short range. It won't run on the ESP32‑S3
alone, and the failsafe is your job, not the library's.**

1. **The S3 can't pair a PlayStation controller.** DualShock 4 and DualSense use Bluetooth
   Classic (BR/EDR). The ESP32‑S3, C3 and C6 only have BLE, so Bluepad32 there only works
   with BLE pads (Xbox firmware 5.x+, Steam, Stadia, some 8BitDo). PS controllers need the
   original ESP32 (WROOM‑32).
2. **Turn WiFi off while driving.** On one ESP32, WiFi and Bluetooth share the same 2.4 GHz
   radio and take turns. With the settings access point running, controller reports arrive
   late and irregularly.
3. **Write your own link watchdog.** DS4 and DualSense send reports all the time, so
   "no report for 250 ms → stop" works like the current firmware's RC failsafe. The
   Bluetooth disconnect event alone can arrive seconds late.
4. **Range is about 10 m in practice,** less when your body or the vehicle shields the
   controller. That's fine for a garden crawler, but too short for anything fast.

## Signal paths

Every hop is a place where the link can fail. Latencies are typical values, not measured on
this board.

| Option | Path | Latency |
|---|---|---|
| A · RC (ELRS) | transmitter → **2.4 GHz FHSS** → ELRS receiver → CRSF on J7 → ESP32‑S3 | ≈ 2–20 ms |
| B · Bluepad32 | DS4 / DualSense → **Bluetooth Classic** → classic ESP32 → CRSF on J7 → ESP32‑S3 | ≈ 5–15 ms |
| C · WiFi app | touchscreen → app → **WiFi** (ESP access point) → ESP32‑S3 | ≈ 10–50 ms, spikes ≥ 100 ms |
| D · App + controller | controller → **Bluetooth** or USB‑OTG → Android input → app → **WiFi** → ESP32‑S3 | ≈ 20–70 ms, spikes ≥ 100 ms |

## Comparison

| | A. RC transmitter (ELRS, CRSF on J7) | B. Bluepad32 (PS controller → classic ESP32) | C. WiFi + Android app (touch) | D. WiFi + app + controller on the phone |
|---|---|---|---|---|
| Failsafe | ✅ **built in**: the receiver stops sending or holds set positions. CRSF reports link quality, so the ESP can tell "weak" from "lost" | ⚠️ **you build it**: a report timeout works because PS pads send reports all the time. BLE pads that only report on change can't be watched this way | ⚠️ **you build it**: the app sends a heartbeat at 20–50 Hz and the ESP stops after 250 ms of silence. Use UDP: TCP/WebSocket retries stall instead of failing | ❌ **two links to watch**: the app must also catch a controller disconnect and send neutral. If the app is killed, only the ESP's timeout helps |
| Range | ✅ hundreds of m and more | ⚠️ ≈ 10 m (Class 2 Bluetooth, the body shields it) | ⚠️ ≈ 30–80 m line of sight, depends on the phone | ⚠️ ≈ 30–80 m, same WiFi link |
| Latency, jitter | ✅ low and constant, fixed packet rate (50–500 Hz) | ✅ low, if WiFi on that ESP is off | ⚠️ variable: phone power saving and other traffic cause spikes | ❌ highest: two radio hops plus the Android input pipeline |
| Interference | ✅ frequency hopping, made for crowded 2.4 GHz | ⚠️ hops frequencies, but has little link margin | ❌ one fixed WiFi channel shared with every network nearby | ❌ same WiFi, plus phone Bluetooth on the same band |
| Controls for drive + crane | ⚠️ depends on the radio: a twin‑stick or pistol radio has 4 axes plus switches; ELRS carries up to 16 channels | ✅ 2 sticks + 2 analog triggers + 14 buttons, with rumble as feedback | ❌ no feel, and your eyes are on the screen instead of the vehicle | ✅ gamepad controls, and the phone shows telemetry or a camera |
| Works on the S3 board as is | ✅ J7 CRSF/SBUS port, GPIO 40/39 | ⚠️ with a second chip: a classic ESP32 bridge on J7. On the S3 itself, BLE pads only | ✅ the firmware already runs a WiFi access point for settings | ✅ same as C on the ESP side |
| Software effort | ✅ low: a CRSF parser. Libraries exist, and it's already planned | ✅ low–medium: the Bluepad32 Arduino core plus a CRSF encoder on the bridge | ⚠️ medium: a control page next to the existing settings UI, or a native app | ❌ high: needs a native Android app, because Chrome's Gamepad API only runs on HTTPS pages and the ESP serves plain `http://192.168.4.1` |
| Extra hardware | ≈ €70–170: ELRS receiver ≈ €10–20 + radio ≈ €60–150, €0 if you already have one | ≈ €5: ESP32‑WROOM DevKit, plus a PS controller | €0, just a phone | €0–20: a phone clip, an OTG cable for wired use |
| Everyday use | ✅ bind once, switch on and drive | ✅ pair once, reconnects when you press PS | ⚠️ Android may leave a WiFi network with no internet. Calls, screen lock and the app going to the background all cut the control link | ❌ three batteries (controller, phone, vehicle), plus all of C's phone quirks |

## Applies to all four: the PCA9685 keeps driving when the ESP32 hangs

The PCA9685 generates its pulses on its own. If the ESP32 crashes or locks up mid‑drive,
the ESC keeps getting the last throttle pulse, whichever link you use. A dedicated receiver
doesn't have this weak spot, because it falls back to its own failsafe. The ESP firmware
has to cover it:

* Keep the ESP's task watchdog on, so a hang becomes a reset. During a reset the 10 kΩ
  pull‑up on `OE` (GPIO 48) switches the outputs off, and the ESC sees "no signal" and stops.
* On link loss, first send neutral throttle and centred steering. After about 1 s, pull `OE`
  high as well.
* Check what your ESC does when the signal stops. Most Hobbywing ESCs cut throttle on
  signal loss. Test it on the bench with the wheels off the ground.
* Only arm the drive after the link has been up for a moment, with the throttle at neutral,
  like a flight controller does.

## The options in detail

### A. RC transmitter with ELRS (recommended primary)

This is the link the board was designed around. The safety work is done in the receiver,
and link quality arrives as telemetry, so the firmware can warn before the link drops.

* **Pick it when** the vehicle goes fast or far, or other people are around, or you want the
  link that needs the least code to trust.
* **Watch out:** a pistol radio (an MT12‑style surface radio) is great for driving, but has
  few controls for the crane. A gamepad‑style ELRS radio has two sticks.

### B. PlayStation controller via Bluepad32 (good second option)

The best ergonomics for drive plus crane at the lowest cost. Build it as a **bridge**: a €5
classic ESP32 runs Bluepad32 and sends CRSF frames into J7, so the S3 can't tell it apart
from an ELRS receiver.

* **Pick it when** you crawl slowly within a few metres, in the garden or indoors.
* **Watch out:**
  * Put the 250 ms report timeout in the bridge, and have it stop sending CRSF, so the S3's
    own failsafe fires too.
  * No WiFi on the bridge chip.
  * Bluepad32 builds on BTstack, which is free for non‑commercial use. Selling kits needs a
    BTstack licence.

### C. WiFi + Android app (setup, not driving)

Very useful for settings, calibration, homing and telemetry; the firmware already has the
access point. It's weak as the main control link: touch has no feel, WiFi jitters, and one
fixed channel gets crowded.

* **Pick it when** you're demoing the crane on a table, with the drive disabled.
* **If you drive with it:** use a UDP heartbeat at 20–50 Hz with the timeout on the ESP, and
  cap the speed in this mode.

### D. App + controller on the phone (only for a screen)

Fixes C's ergonomics but adds a second radio hop, a native app and the most failure modes.
It's worth it only if you want a live camera or telemetry screen in front of you.

* **Pick it when** FPV or a telemetry display is the goal.
* **Watch out:**
  * A plain web page can't read the gamepad over http. You need a native app, or HTTPS with
    a self‑signed certificate on the ESP.
  * The app must react to the controller dropping out (Android's `onInputDeviceRemoved`).

## Suggested architecture: one input path, swappable radios

Make the S3 firmware read just one control input: CRSF on J7, with one failsafe and one
arming check. ELRS and the Bluepad32 bridge both plug in there. WiFi stays on the S3 for
setup and telemetry and goes off while the drive is armed, as the current `wifi_off`
setting already does.

```
  ELRS receiver ───────────────┐
                               ├─ CRSF ─► J7 (GPIO 40/39) ─► ESP32-S3 ─► PCA9685 ─► ESC, steering, servos
  DS4/DualSense ─BT─► ESP32 ───┘          one failsafe,      │
                      (Bluepad32,         one arming check   └─► TMC2209 ×4 ─► crane
                       CRSF out)
  Phone ─WiFi─► ESP32-S3 web UI: settings, homing, telemetry (drive disarmed)
```

Latency and range are typical values, not measurements on this hardware. Prices are rough
street prices (2026).

**Sources:**
[Bluepad32 supported gamepads](https://bluepad32.readthedocs.io/en/latest/supported_gamepads/)
(BR/EDR pads need the original ESP32; S3/C3/C6 are BLE only) ·
[Chromium: Intent to Ship, Restrict Gamepad usage](https://groups.google.com/a/chromium.org/g/blink-dev/c/B1QUuICApvc/m/RRxZLqG4HQAJ)
(Gamepad API only on secure contexts) ·
[Mozilla: Securing Gamepad API](https://hacks.mozilla.org/2020/07/securing-gamepad-api/)
