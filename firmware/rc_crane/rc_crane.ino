// RC crane controller – boom lift + telescopic extension
// ESP32-C3 + 2x TMC2209 (shared UART) + 2x mini stepper linear actuator, no end switches.
// See ../../README.md for wiring and tuning.

#include <TMCStepper.h>
#include <AccelStepper.h>

// ---------------------------------------------------------------- pins ----
constexpr int PIN_EN      = 6;   // shared by both drivers, LOW = enabled
constexpr int PIN_DIAG    = 7;   // both DIAG outputs OR'ed via diodes, HIGH on stall
constexpr int PIN_UART_RX = 20;
constexpr int PIN_UART_TX = 21;  // via 1k to PDN_UART of both drivers

// ------------------------------------------------- actuator mechanics ----
// CHECK THESE AGAINST YOUR ACTUATORS (both are the same model)
constexpr int   FULL_STEPS_PER_REV = 20;    // 18 deg motor
constexpr float SCREW_LEAD_MM      = 0.5f;  // M3 lead screw
constexpr int   MICROSTEPS         = 16;

constexpr float STEPS_PER_MM  = FULL_STEPS_PER_REV * MICROSTEPS / SCREW_LEAD_MM;
constexpr float SOFT_LIMIT_MM = 0.5f;       // stay this far from both ends

// ------------------------------------------------------------- motion ----
constexpr float MAX_SPEED_MM_S  = 5.0f;
constexpr float ACCEL_MM_S2     = 20.0f;
constexpr float HOME_SPEED_MM_S = 2.0f;
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
constexpr float    RC_DEADBAND    = 0.06f;  // rate mode, fraction of half range
constexpr long     POS_HYSTERESIS = (long)(0.1f * STEPS_PER_MM);
constexpr uint32_t RC_TIMEOUT_MS  = 250;

// --------------------------------------------------------------- axes ----
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
  {"boom lift",    4,   5,   3,  0,   30.0f, false, 300, 150, 30, ControlMode::POSITION},
  {"telescope",    0,   1,  10,  1,   30.0f, false, 300, 150, 30, ControlMode::RATE},
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
        posMin((long)(SOFT_LIMIT_MM * STEPS_PER_MM)),
        posMax((long)((cfg.strokeMm - SOFT_LIMIT_MM) * STEPS_PER_MM)) {
    rc.pin = cfg.pinRc;
  }

  const AxisConfig& cfg;
  TMC2209Stepper driver;
  AccelStepper stepper;
  RcInput rc;
  const long posMin;
  const long posMax;
  bool rateMoving = false;

  void begin() {
    driver.begin();
    driver.toff(4);
    driver.blank_time(24);
    driver.I_scale_analog(false);
    driver.rms_current(cfg.runCurrentMa, 0.3f);  // 30 % hold current
    driver.microsteps(MICROSTEPS);
    driver.pwm_autoscale(true);
    driver.en_spreadCycle(false);  // StealthChop: quiet, and required for StallGuard
    driver.TPWMTHRS(0);
    driver.SGTHRS(cfg.stallThreshold);
    setStallOutput(false);         // DIAG is shared, only the homing axis may drive it

    uint8_t result = driver.test_connection();
    if (result == 0) {
      Serial.printf("[%s] TMC2209 UART ok (addr %u)\n", cfg.name, cfg.driverAddr);
    } else {
      Serial.printf("[%s] TMC2209 UART FAILED (%u) - check PDN_UART wiring and MS1/MS2 address\n",
                    cfg.name, result);
    }

    stepper.setPinsInverted(cfg.invertDir, false, false);
    stepper.setMaxSpeed(MAX_SPEED_MM_S * STEPS_PER_MM);
    stepper.setAcceleration(ACCEL_MM_S2 * STEPS_PER_MM);

    pinMode(cfg.pinRc, INPUT);
    attachInterruptArg(digitalPinToInterrupt(cfg.pinRc), onRcEdge, &rc, CHANGE);
  }

  // TCOOLTHRS = 0 disables StallGuard on DIAG, 0xFFFFF enables it at all speeds
  void setStallOutput(bool on) { driver.TCOOLTHRS(on ? 0xFFFFF : 0); }

  // Drive toward the retracted end at low current. Stops on stall (DIAG) or after
  // the full stroke plus overrun, at which point we're at the hard stop either way.
  void home() {
    Serial.printf("[%s] Homing...\n", cfg.name);
    driver.rms_current(cfg.homeCurrentMa, 0.3f);
    if (USE_STALLGUARD) setStallOutput(true);

    stepper.setCurrentPosition(0);
    stepper.setSpeed(-HOME_SPEED_MM_S * STEPS_PER_MM);
    long maxSteps = (long)((cfg.strokeMm + HOME_OVERRUN_MM) * STEPS_PER_MM);
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
    driver.rms_current(cfg.runCurrentMa, 0.3f);
    stepper.runToNewPosition(posMin);
  }

  void updatePosition(float stick) {
    long target = map((long)(stick * 1000), -1000, 1000, posMin, posMax);
    if (labs(target - stepper.targetPosition()) > POS_HYSTERESIS) stepper.moveTo(target);
  }

  void updateRate(float stick) {
    if (fabsf(stick) < RC_DEADBAND) {
      if (rateMoving) stepper.stop();
      rateMoving = false;
      return;
    }
    stepper.setMaxSpeed(fabsf(stick) * MAX_SPEED_MM_S * STEPS_PER_MM);
    stepper.moveTo(stick > 0 ? posMax : posMin);
    rateMoving = true;
  }

  void updateControl() {
    float stick = readStick(rc);
    if (isnan(stick)) {
      // Failsafe: no signal -> stop where we are
      if (stepper.distanceToGo() != 0) stepper.stop();
    } else if (cfg.mode == ControlMode::POSITION) {
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
  axis.stepper.setMaxSpeed(HOME_SPEED_MM_S * STEPS_PER_MM);
  long span = (long)(axis.cfg.strokeMm / 2 * STEPS_PER_MM);
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

void setup() {
  Serial.begin(115200);
  pinMode(PIN_EN, OUTPUT);
  digitalWrite(PIN_EN, HIGH);
  pinMode(PIN_DIAG, INPUT_PULLDOWN);
  Serial1.begin(115200, SERIAL_8N1, PIN_UART_RX, PIN_UART_TX);

  for (Axis& axis : axes) axis.begin();

  if (TUNE_STALLGUARD >= 0 && TUNE_STALLGUARD < NUM_AXES) tuneStallGuard(TUNE_STALLGUARD);

  // Retract the telescope first so the boom moves with the shortest lever
  setDriversEnabled(true);
  for (int i = NUM_AXES - 1; i >= 0; i--) axes[i].home();
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

  if (moving) {
    idleSince = millis();
  } else if (driversEnabled && millis() - idleSince > IDLE_DISABLE_MS) {
    setDriversEnabled(false);
  }
}
