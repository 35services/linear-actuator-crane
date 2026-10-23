// RC crane controller – boom lift + telescopic extension
// ESP32-C3 + 2x TMC2209 (shared UART) + 2x mini stepper linear actuator, no end switches.
// See ../../README.md for wiring and tuning.
//
// The values marked [web] are defaults: they can be changed at runtime in the web UI
// (WiFi "rc-crane-xxxx", http://192.168.4.1) and are then stored in flash.

#include <TMCStepper.h>
#include <AccelStepper.h>
#include "settings.h"
#include "web_ui.h"

// ---------------------------------------------------------------- pins ----
constexpr int PIN_EN      = 6;   // shared by both drivers, LOW = enabled
constexpr int PIN_DIAG    = 7;   // both DIAG outputs OR'ed via diodes, HIGH on stall
constexpr int PIN_UART_RX = 20;
constexpr int PIN_UART_TX = 21;  // via 1k to PDN_UART of both drivers

// ------------------------------------------------- actuator mechanics ----
// CHECK THESE AGAINST YOUR ACTUATORS (both are the same model)
constexpr int   FULL_STEPS_PER_REV = 20;    // 18 deg motor
constexpr float SCREW_LEAD_MM      = 0.5f;  // M3 lead screw, 172 turns on 86.6 mm (counted, README "Speed")
constexpr int   MICROSTEPS         = 16;

constexpr float STEPS_PER_MM  = FULL_STEPS_PER_REV * MICROSTEPS / SCREW_LEAD_MM;
constexpr float SOFT_LIMIT_MM = 0.5f;       // stay this far from both ends

// ------------------------------------------------------------- motion ----
float maxSpeedMmS  = 5.0f;    // [web] = 200 full steps/s, slow for first tests. ~20 mm/s
                              // (800 full steps/s) is realistic under load, README "Speed"
float accelMmS2    = 20.0f;   // [web]
float homeSpeedMmS = 2.0f;    // [web]
constexpr float HOME_OVERRUN_MM = 2.0f;     // extra travel beyond stroke when homing

// ------------------------------------------------------------- driver ----
constexpr float    R_SENSE         = 0.11f; // BTT / FYSETC TMC2209 modules
constexpr uint32_t IDLE_DISABLE_MS = 500;   // lead screws self-lock, save power

// --------------------------------------------------- sensorless homing ----
constexpr bool     USE_STALLGUARD  = true;
constexpr uint32_t STALL_IGNORE_MS = 150;   // ignore DIAG while accelerating
constexpr int      TUNE_STALLGUARD = -1;    // axis index to tune (prints SG_RESULT), -1 = off

// --------------------------------------------------------- RC control ----
enum class ControlMode { POSITION, RATE };

constexpr uint16_t RC_MIN_US      = 1000;
constexpr uint16_t RC_MAX_US      = 2000;
float              rcDeadbandPct  = 6.0f;   // [web] rate mode, % of half the stick range
constexpr long     POS_HYSTERESIS = (long)(0.1f * STEPS_PER_MM);
constexpr uint32_t RC_TIMEOUT_MS  = 250;

// --------------------------------------------------------------- WiFi ----
constexpr const char* WIFI_PASSWORD = "crane-setup";  // min. 8 characters, change it
float wifiOffMin = 10.0f;     // [web] WiFi off after this many minutes without a client, 0 = never

// --------------------------------------------------------------- axes ----
// stroke, invert, run/home current, SG threshold and mode are [web] defaults
struct AxisConfig {
  const char* name;
  int         pinStep;
  int         pinDir;
  int         pinRc;
  uint8_t     driverAddr;      // MS1/MS2 strapping: 0 = both GND, 1 = MS1 high
  float       strokeMm;
  bool        invertDir;       // flip if "retract" moves outward
  uint16_t    runCurrentMa;    // ~ rated V / coil resistance
  uint16_t    homeCurrentMa;
  uint8_t     stallThreshold;  // stall when SG_RESULT <= 2 * this
  ControlMode mode;
};

constexpr AxisConfig AXES[] = {
  // name         STEP DIR  RC  addr stroke invert  run  home  SG  mode
  {"boom lift",    4,   5,   3,  0,   49.5f, false, 300, 150, 30, ControlMode::POSITION},  // crane.scad: 0..55° needs 49.6 mm
  {"telescope",    0,   1,  10,  1,   75.0f, false, 300, 150, 30, ControlMode::RATE},      // full actuator stroke
};
constexpr int NUM_AXES = sizeof(AXES) / sizeof(AXES[0]);

// ---------------------------------------------------------------------------

struct RcInput {
  int pin;
  volatile uint32_t riseUs = 0;
  volatile uint16_t pulseUs = 0;
  volatile uint32_t lastUs = 0;
};

void IRAM_ATTR onRcEdge(void* arg) {
  RcInput* rc = static_cast<RcInput*>(arg);
  uint32_t now = micros();
  if (digitalRead(rc->pin)) {
    rc->riseUs = now;
  } else {
    uint32_t width = now - rc->riseUs;
    if (width > 800 && width < 2200) {
      rc->pulseUs = width;
      rc->lastUs = now;
    }
  }
}

// Returns stick position -1..1, or NAN if the signal is lost.
float readStick(RcInput& rc) {
  noInterrupts();
  uint16_t pulse = rc.pulseUs;
  uint32_t last = rc.lastUs;
  interrupts();
  if (pulse == 0 || micros() - last > RC_TIMEOUT_MS * 1000UL) return NAN;
  float centre = (RC_MIN_US + RC_MAX_US) / 2.0f;
  float half = (RC_MAX_US - RC_MIN_US) / 2.0f;
  return constrain((pulse - centre) / half, -1.0f, 1.0f);
}

class Axis {
 public:
  explicit Axis(const AxisConfig& cfg)
      : cfg(cfg),
        driver(&Serial1, R_SENSE, cfg.driverAddr),
        stepper(AccelStepper::DRIVER, cfg.pinStep, cfg.pinDir),
        strokeMm(cfg.strokeMm),
        invertDir(cfg.invertDir),
        runCurrentMa(cfg.runCurrentMa),
        homeCurrentMa(cfg.homeCurrentMa),
        stallThreshold(cfg.stallThreshold),
        mode(cfg.mode == ControlMode::RATE) {
    rc.pin = cfg.pinRc;
  }

  const AxisConfig& cfg;
  TMC2209Stepper driver;
  AccelStepper stepper;
  RcInput rc;
  const long posMin = (long)(SOFT_LIMIT_MM * STEPS_PER_MM);
  long posMax = 0;
  bool rateMoving = false;

  // runtime settings, see addSettings()
  float strokeMm, invertDir, runCurrentMa, homeCurrentMa, stallThreshold, mode;

  void addSettings(SettingsStore& settings, int index) {
    String k = "a" + String(index) + "_", g = cfg.name;
    settings.add(k + "stroke", g, "Stroke", "mm", &strokeMm, 5, 80, 0.5);
    settings.add(k + "mode", g, "RC control", "", &mode, 0, 1, 1, "position (knob)|rate (stick)");
    settings.add(k + "run", g, "Run current", "mA", &runCurrentMa, 50, 800, 10);
    settings.add(k + "home", g, "Homing current", "mA", &homeCurrentMa, 50, 600, 10);
    settings.add(k + "sg", g, "Stall threshold", "", &stallThreshold, 0, 255, 1);
    settings.add(k + "invert", g, "Invert direction", "", &invertDir, 0, 1, 1, "no|yes", true);
  }

  // Applies changed settings while running. The direction only changes on restart,
  // because the homed position would be mirrored otherwise.
  void applySettings() {
    posMax = (long)((strokeMm - SOFT_LIMIT_MM) * STEPS_PER_MM);
    driver.rms_current(runCurrentMa, 0.3f);
    driver.SGTHRS(stallThreshold);
    stepper.setMaxSpeed(maxSpeedMmS * STEPS_PER_MM);
    stepper.setAcceleration(accelMmS2 * STEPS_PER_MM);
    if (stepper.targetPosition() > posMax) stepper.moveTo(posMax);
  }

  bool rateMode() const { return mode > 0.5f; }

  void begin() {
    driver.begin();
    driver.toff(4);
    driver.blank_time(24);
    driver.I_scale_analog(false);
    driver.rms_current(runCurrentMa, 0.3f);  // 30 % hold current
    driver.microsteps(MICROSTEPS);
    driver.pwm_autoscale(true);
    driver.en_spreadCycle(false);  // StealthChop: quiet, and required for StallGuard
    driver.TPWMTHRS(0);
    driver.SGTHRS(stallThreshold);
    setStallOutput(false);         // DIAG is shared, only the homing axis may drive it

    uint8_t result = driver.test_connection();
    if (result == 0) {
      Serial.printf("[%s] TMC2209 UART ok (addr %u)\n", cfg.name, cfg.driverAddr);
    } else {
      Serial.printf("[%s] TMC2209 UART FAILED (%u) - check PDN_UART wiring and MS1/MS2 address\n",
                    cfg.name, result);
    }

    stepper.setPinsInverted(invertDir > 0.5f, false, false);
    applySettings();

    pinMode(cfg.pinRc, INPUT);
    attachInterruptArg(digitalPinToInterrupt(cfg.pinRc), onRcEdge, &rc, CHANGE);
  }

  // TCOOLTHRS = 0 disables StallGuard on DIAG, 0xFFFFF enables it at all speeds
  void setStallOutput(bool on) { driver.TCOOLTHRS(on ? 0xFFFFF : 0); }

  // Drive toward the retracted end at low current. Stops on stall (DIAG) or after
  // the full stroke plus overrun, at which point we're at the hard stop either way.
  void home() {
    Serial.printf("[%s] Homing...\n", cfg.name);
    driver.rms_current(homeCurrentMa, 0.3f);
    if (USE_STALLGUARD) setStallOutput(true);

    stepper.setCurrentPosition(0);
    stepper.setSpeed(-homeSpeedMmS * STEPS_PER_MM);
    long maxSteps = (long)((strokeMm + HOME_OVERRUN_MM) * STEPS_PER_MM);
    uint32_t start = millis();
    bool stalled = false;

    while (-stepper.currentPosition() < maxSteps) {
      stepper.runSpeed();
      if (USE_STALLGUARD && millis() - start > STALL_IGNORE_MS && digitalRead(PIN_DIAG)) {
        stalled = true;
        break;
      }
    }

    if (stalled) {
      Serial.printf("[%s] Stall detected - homed.\n", cfg.name);
    } else if (USE_STALLGUARD) {
      Serial.printf("[%s] No stall detected - homed against hard stop. Consider raising the stall threshold.\n",
                    cfg.name);
    }

    setStallOutput(false);
    stepper.setCurrentPosition(0);
    driver.rms_current(runCurrentMa, 0.3f);
    stepper.runToNewPosition(posMin);
  }

  void updatePosition(float stick) {
    long target = map((long)(stick * 1000), -1000, 1000, posMin, posMax);
    if (labs(target - stepper.targetPosition()) > POS_HYSTERESIS) stepper.moveTo(target);
  }

  void updateRate(float stick) {
    if (fabsf(stick) < rcDeadbandPct / 100) {
      if (rateMoving) stepper.stop();
      rateMoving = false;
      return;
    }
    stepper.setMaxSpeed(fabsf(stick) * maxSpeedMmS * STEPS_PER_MM);
    stepper.moveTo(stick > 0 ? posMax : posMin);
    rateMoving = true;
  }

  void updateControl() {
    float stick = readStick(rc);
    if (isnan(stick)) {
      // Failsafe: no signal -> stop where we are
      if (stepper.distanceToGo() != 0) stepper.stop();
    } else if (!rateMode()) {
      updatePosition(stick);
    } else {
      updateRate(stick);
    }
  }

  // Returns true while moving
  bool run() {
    if (stepper.distanceToGo() == 0) return false;
    stepper.run();
    return true;
  }
};

Axis axes[NUM_AXES] = {Axis(AXES[0]), Axis(AXES[1])};

bool driversEnabled = false;

void setDriversEnabled(bool on) {
  if (on == driversEnabled) return;
  digitalWrite(PIN_EN, on ? LOW : HIGH);
  driversEnabled = on;
  if (on) delay(2);
}

void tuneStallGuard(int index) {
  Axis& axis = axes[index];
  setDriversEnabled(true);
  axis.setStallOutput(true);
  axis.stepper.setMaxSpeed(homeSpeedMmS * STEPS_PER_MM);
  long span = (long)(axis.strokeMm / 2 * STEPS_PER_MM);
  axis.stepper.moveTo(span);
  uint32_t lastPrint = 0;
  while (true) {
    if (axis.stepper.distanceToGo() == 0) axis.stepper.moveTo(axis.stepper.currentPosition() > 0 ? 0 : span);
    axis.stepper.run();
    if (millis() - lastPrint > 100) {
      lastPrint = millis();
      Serial.printf("[%s] SG_RESULT=%u  DIAG=%d\n", axis.cfg.name, axis.driver.SG_RESULT(), digitalRead(PIN_DIAG));
    }
  }
}

SettingsStore settings;

String statusJson() {
  String out = "{\"uptime_s\":" + String(millis() / 1000) + ",\"drivers\":\"" + (driversEnabled ? "on" : "off") + "\"";
  for (Axis& axis : axes) {
    float stick = readStick(axis.rc);
    out += ",\"" + String(axis.cfg.name) + "\":{\"pos_mm\":" + String(axis.stepper.currentPosition() / STEPS_PER_MM, 2) +
           ",\"target_mm\":" + String(axis.stepper.targetPosition() / STEPS_PER_MM, 2) +
           ",\"rc\":" + (isnan(stick) ? String("\"no signal\"") : String(stick, 2)) + "}";
  }
  return out + "}";
}

WebUi web(settings, statusJson);

void addSettings() {
  settings.add("speed", "Motion", "Max speed", "mm/s", &maxSpeedMmS, 1, 50, 0.5);
  settings.add("accel", "Motion", "Acceleration", "mm/s²", &accelMmS2, 5, 500, 5);
  settings.add("home_speed", "Motion", "Homing speed", "mm/s", &homeSpeedMmS, 0.5, 10, 0.5);
  settings.add("deadband", "RC", "Stick deadband (rate mode)", "%", &rcDeadbandPct, 0, 30, 1);
  settings.add("wifi_off", "WiFi", "WiFi off without client after", "min", &wifiOffMin, 0, 120, 1);
  for (int i = 0; i < NUM_AXES; i++) axes[i].addSettings(settings, i);

  settings.load();
  settings.onChange = [] {
    for (Axis& axis : axes) axis.applySettings();
  };
  Serial.println("Settings:");
  settings.print();
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_EN, OUTPUT);
  digitalWrite(PIN_EN, HIGH);
  pinMode(PIN_DIAG, INPUT_PULLDOWN);
  Serial1.begin(115200, SERIAL_8N1, PIN_UART_RX, PIN_UART_TX);

  addSettings();
  for (Axis& axis : axes) axis.begin();

  if (TUNE_STALLGUARD >= 0 && TUNE_STALLGUARD < NUM_AXES) tuneStallGuard(TUNE_STALLGUARD);

  // Retract the telescope first so the boom moves with the shortest lever
  setDriversEnabled(true);
  for (int i = NUM_AXES - 1; i >= 0; i--) axes[i].home();

  String ssid = "rc-crane-" + String((uint32_t)ESP.getEfuseMac() >> 16 & 0xFFFF, HEX);
  web.begin(ssid, WIFI_PASSWORD, &wifiOffMin);
}

void loop() {
  static uint32_t lastControl = 0;
  static uint32_t idleSince = 0;

  // ~50 Hz control update, matching RC frame rate
  if (millis() - lastControl >= 20) {
    lastControl = millis();
    for (Axis& axis : axes) axis.updateControl();
  }

  bool moving = false;
  for (Axis& axis : axes) {
    if (axis.stepper.distanceToGo() != 0) {
      setDriversEnabled(true);
      moving = true;
    }
    axis.run();
  }

  // the web server only runs while nothing moves: serving a page takes a few ms,
  // which would make the steppers stutter
  if (!moving) web.loop();

  if (moving) {
    idleSince = millis();
  } else if (driversEnabled && millis() - idleSince > IDLE_DISABLE_MS) {
    setDriversEnabled(false);
  }
}
