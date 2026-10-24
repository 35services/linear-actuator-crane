// Web UI: the ESP32 opens its own WiFi access point and serves one page at
// http://192.168.4.1 that lists every registered setting. The page builds its form
// from /api/settings, so new settings show up without touching this file.
//
//   GET  /               the page
//   GET  /api/settings   all settings as JSON
//   POST /api/settings   key=value pairs (form encoded), stores and applies them
//   POST /api/reset      all settings back to their defaults
//   POST /api/restart    restart (and home again)
//   GET  /api/status     live values from the sketch (positions, RC pulses, ...)
#pragma once

#include <WebServer.h>
#include <WiFi.h>
#include "settings.h"

static const char PAGE[] PROGMEM = R"HTML(<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RC crane</title>
<style>
*{box-sizing:border-box}body{font-family:system-ui,sans-serif;margin:0 auto;padding:16px;background:#f4f4f2;color:#222;max-width:640px}
h1{font-size:1.3em;margin:0 0 12px}
fieldset{border:1px solid #ccc;border-radius:8px;margin:0 0 12px;background:#fff;min-width:0}
legend{font-weight:600;padding:0 6px}
label{display:grid;grid-template-columns:minmax(0,1fr) 7.5em 3em;gap:8px;align-items:center;margin:6px 0}
input,select{font:inherit;padding:4px;width:100%}
small{color:#777}.changed{background:#fff6d6}
button{font:inherit;padding:8px 14px;margin:0 8px 8px 0;border-radius:6px;border:1px solid #888;background:#fff}
button.main{background:#2f6fd8;color:#fff;border-color:#2f6fd8}
#msg{min-height:1.4em}#status{font-family:ui-monospace,monospace;font-size:.85em;white-space:pre-wrap}
</style></head><body>
<h1>RC crane settings</h1>
<form id="f"></form>
<button class="main" onclick="save()">Save</button><button onclick="reset()">Defaults</button><button onclick="restart()">Restart + home</button>
<div id="msg"></div>
<fieldset><legend>Live</legend><div id="status">...</div></fieldset>
<script>
const f=document.getElementById('f'),msg=t=>document.getElementById('msg').textContent=t;
let items=[];
function fmt(v,s){return s.options?s.options.split('|')[v]:v+' '+s.unit}
async function load(){
  items=await (await fetch('/api/settings')).json();
  f.innerHTML='';const groups={};
  for(const s of items){
    if(!groups[s.group]){const fs=document.createElement('fieldset');fs.innerHTML='<legend>'+s.group+'</legend>';f.appendChild(fs);groups[s.group]=fs}
    const l=document.createElement('label');
    let input;
    if(s.options){input='<select name="'+s.key+'">'+s.options.split('|').map((o,i)=>'<option value="'+i+'"'+(i==s.value?' selected':'')+'>'+o+'</option>').join('')+'</select>'}
    else{input='<input type="number" name="'+s.key+'" value="'+s.value+'" min="'+s.min+'" max="'+s.max+'" step="'+s.step+'">'}
    l.innerHTML='<span>'+s.label+(s.restart?' <small>(after restart)</small>':'')+'<br><small>default '+fmt(s.default,s)+'</small></span>'+input+'<span>'+(s.options?'':s.unit)+'</span>';
    if(s.value!=s.default)l.classList.add('changed');
    groups[s.group].appendChild(l);
  }
}
async function post(url,body){const r=await fetch(url,{method:'POST',body});return r.text()}
async function save(){msg(await post('/api/settings',new URLSearchParams(new FormData(f))));load()}
async function reset(){if(confirm('Reset all settings to defaults?')){msg(await post('/api/reset'));load()}}
async function restart(){msg(await post('/api/restart'));setTimeout(load,8000)}
async function status(){try{const s=await (await fetch('/api/status')).json();
  document.getElementById('status').textContent=Object.entries(s).map(([k,v])=>k+': '+(typeof v=='object'?Object.entries(v).map(([a,b])=>a+' '+b).join(', '):v)).join('\n')}catch(e){}}
load();status();setInterval(status,1000);
</script></body></html>)HTML";

class WebUi {
 public:
  WebUi(SettingsStore& settings, std::function<String()> status) : settings(settings), status(status) {}

  std::function<void()> beforeRestart;  // called before /api/restart restarts the ESP32

  // apOffS: switch WiFi off after this many seconds without a connected client, 0 = never
  void begin(const String& ssid, const char* password, const float* apOffS) {
    this->apOffS = apOffS;
    WiFi.mode(WIFI_AP);
    WiFi.softAP(ssid.c_str(), password);
    Serial.printf("WiFi \"%s\" - settings at http://%s\n", ssid.c_str(), WiFi.softAPIP().toString().c_str());

    server.on("/", HTTP_GET, [this] { server.send_P(200, "text/html", PAGE); });
    server.on("/api/settings", HTTP_GET, [this] { server.send(200, "application/json", settings.json()); });
    server.on("/api/settings", HTTP_POST, [this] { handleSave(); });
    server.on("/api/reset", HTTP_POST, [this] {
      settings.resetToDefaults();
      settings.changed();
      server.send(200, "text/plain", "All settings back to defaults.");
    });
    server.on("/api/restart", HTTP_POST, [this] {
      server.send(200, "text/plain", "Restarting, the crane homes again...");
      if (beforeRestart) beforeRestart();
      delay(200);
      ESP.restart();
    });
    server.on("/api/status", HTTP_GET, [this] { server.send(200, "application/json", this->status()); });
    server.begin();
    on = true;
    lastClient = millis();
  }

  void loop() {
    if (!on) return;
    server.handleClient();
    if (WiFi.softAPgetStationNum() > 0) lastClient = millis();
    if (*apOffS > 0 && millis() - lastClient > *apOffS * 1000UL) {
      Serial.println("WiFi off (no client). Restart to turn it on again.");
      server.stop();
      WiFi.softAPdisconnect(true);
      WiFi.mode(WIFI_OFF);
      on = false;
    }
  }

 private:
  SettingsStore& settings;
  std::function<String()> status;
  WebServer server{80};
  const float* apOffS = nullptr;
  uint32_t lastClient = 0;
  bool on = false;

  void handleSave() {
    String bad;
    for (int i = 0; i < server.args(); i++) {
      if (server.argName(i) == "plain") continue;  // raw body, not a field
      if (!settings.set(server.argName(i), server.arg(i))) bad += " " + server.argName(i);
    }
    settings.changed();
    server.send(bad.isEmpty() ? 200 : 400, "text/plain",
                bad.isEmpty() ? "Saved." : "Saved, but ignored:" + bad);
  }
};
