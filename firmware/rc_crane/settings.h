// Runtime settings: values the web UI can change, stored in flash (NVS) so they
// survive a restart. Register a float with add(); its value at that moment becomes
// the default, so the defaults stay in the constants at the top of the sketch.
#pragma once

#include <Arduino.h>
#include <Preferences.h>
#include <functional>
#include <vector>

struct Setting {
  String key;      // NVS key, max 15 characters
  String group;    // shown as one box in the web UI
  String label;
  String unit;
  float* value;
  float  def;
  float  min, max, step;
  String options;  // "a|b|c": a list, the value is the index. Empty: a number field
  bool   restart;  // only takes effect after a restart
};

class SettingsStore {
 public:
  std::vector<Setting> items;
  std::function<void()> onChange;  // called after values changed, to apply them

  void add(const String& key, const String& group, const String& label, const String& unit,
           float* value, float min, float max, float step,
           const String& options = "", bool restart = false) {
    items.push_back({key, group, label, unit, value, *value, min, max, step, options, restart});
  }

  // Overwrites the registered values with the ones stored in flash
  void load() {
    prefs.begin(NAMESPACE, false);
    for (Setting& s : items) *s.value = fit(s, prefs.getFloat(s.key.c_str(), *s.value));
    prefs.end();
  }

  // Sets and stores one value. Returns false for an unknown key or a non-number.
  bool set(const String& key, const String& text) {
    Setting* s = find(key);
    if (!s) return false;
    char* end;
    float v = strtof(text.c_str(), &end);
    if (end == text.c_str()) return false;
    *s->value = fit(*s, v);
    prefs.begin(NAMESPACE, false);
    if (*s->value == s->def) prefs.remove(s->key.c_str());
    else prefs.putFloat(s->key.c_str(), *s->value);
    prefs.end();
    return true;
  }

  void resetToDefaults() {
    prefs.begin(NAMESPACE, false);
    prefs.clear();
    prefs.end();
    for (Setting& s : items) *s.value = s.def;
  }

  void changed() {
    if (onChange) onChange();
  }

  String json() const {
    String out = "[";
    for (size_t i = 0; i < items.size(); i++) {
      const Setting& s = items[i];
      if (i) out += ",";
      out += "{\"key\":\"" + s.key + "\",\"group\":\"" + s.group + "\",\"label\":\"" + s.label +
             "\",\"unit\":\"" + s.unit + "\",\"value\":" + String(*s.value, 3) +
             ",\"default\":" + String(s.def, 3) + ",\"min\":" + String(s.min, 3) +
             ",\"max\":" + String(s.max, 3) + ",\"step\":" + String(s.step, 3) +
             ",\"options\":\"" + s.options + "\",\"restart\":" + (s.restart ? "true" : "false") + "}";
    }
    return out + "]";
  }

  void print() const {
    for (const Setting& s : items)
      Serial.printf("  %-12s %-26s %8.2f %s%s\n", s.key.c_str(), (s.group + ": " + s.label).c_str(),
                    *s.value, s.unit.c_str(), *s.value != s.def ? "  (changed)" : "");
  }

 private:
  static constexpr const char* NAMESPACE = "crane";
  Preferences prefs;

  Setting* find(const String& key) {
    for (Setting& s : items)
      if (s.key == key) return &s;
    return nullptr;
  }

  // clamp to the range and snap to the step
  static float fit(const Setting& s, float v) {
    if (isnan(v)) return s.def;
    v = constrain(v, s.min, s.max);
    if (s.step > 0) v = s.min + roundf((v - s.min) / s.step) * s.step;
    return constrain(v, s.min, s.max);
  }
};
