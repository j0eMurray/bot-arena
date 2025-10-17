#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClient.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <NTPClient.h>
#include <WiFiUdp.h>
#include "secrets.h"

// ====== Globals ======
WiFiClient espClient;
PubSubClient mqtt(espClient);
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org", 0 /*UTC*/, 60000 /*ms*/);

// Tópicos
String topicTelemetry = String(MQTT_BASE_TOPIC) + "/" + DEVICE_ID + "/telemetry";
String topicCmd       = String(MQTT_BASE_TOPIC) + "/" + DEVICE_ID + "/cmd";
String topicStatus    = String(MQTT_BASE_TOPIC) + "/" + DEVICE_ID + "/status";

unsigned long lastPubMs = 0;
const unsigned long pubIntervalMs = 5000;

void publishStatus(bool online) {
  StaticJsonDocument<128> doc;
  doc["online"] = online;
  char buf[128];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  // Usa la sobrecarga con const char* + retained
  mqtt.publish(topicStatus.c_str(), buf, true);
}

void handleCommand(char* topic, byte* payload, unsigned int length) {
  Serial.printf("[CMD] %s -> ", topic);
  for (unsigned int i = 0; i < length; i++) Serial.print((char)payload[i]);
  Serial.println();
  // TODO: parse JSON si quieres
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  handleCommand(topic, payload, length);
}

void ensureWifi() {
  if (WiFi.status() == WL_CONNECTED) return;

  Serial.printf("WiFi connecting to %s ...\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  uint8_t retries = 0;
  while (WiFi.status() != WL_CONNECTED && retries++ < 50) {
    delay(200);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("WiFi connected: %s RSSI=%d IP=%s\n",
                  WIFI_SSID, WiFi.RSSI(), WiFi.localIP().toString().c_str());
  } else {
    Serial.println("WiFi FAILED");
  }
}

void ensureMqtt() {
  if (mqtt.connected()) return;

  mqtt.setServer(MQTT_HOST, MQTT_PORT_CONST);
  mqtt.setCallback(mqttCallback);

  // Construir LWT en JSON
  StaticJsonDocument<64> lwt;
  lwt["online"] = false;
  char lwtBuf[64];
  serializeJson(lwt, lwtBuf, sizeof(lwtBuf));

  String clientId = String("esp32-") + DEVICE_ID + "-" + String((uint32_t)ESP.getEfuseMac(), HEX);
  Serial.printf("MQTT connecting to %s:%d as %s ...\n", MQTT_HOST, MQTT_PORT_CONST, clientId.c_str());

  // LWT via connect(... willTopic, willQos, willRetain, willMessage)
  // Overload: connect(clientID, user, pass, willTopic, willQos, willRetain, willMessage, cleanSession)
  bool ok = mqtt.connect(
      clientId.c_str(),
      MQTT_USER, MQTT_PASS,
      topicStatus.c_str(), 1, true, lwtBuf,
      true
  );

  if (ok) {
    Serial.println("MQTT connected");
    publishStatus(true);
    mqtt.subscribe(topicCmd.c_str(), 1);
  } else {
    Serial.printf("MQTT connect failed, rc=%d\n", mqtt.state());
  }
}

void publishTelemetry() {
  timeClient.update();
  unsigned long ts = timeClient.getEpochTime();

  StaticJsonDocument<256> doc;
  doc["ts"]   = (uint32_t)ts;
  doc["temp"] = 24.0 + (rand() % 10) / 10.0;
  doc["hum"]  = 50.0 + (rand() % 15);
  doc["rssi"] = WiFi.RSSI();

  char buf[256];
  size_t n = serializeJson(doc, buf, sizeof(buf));

  // Usa publish(topic, payload, retained) con char*
  bool ok = mqtt.publish(topicTelemetry.c_str(), buf, true);
  Serial.printf("PUB %s (%s) -> %.*s\n",
                topicTelemetry.c_str(), ok ? "OK" : "FAIL", (int)n, buf);
}

void setup() {
  Serial.begin(115200);
  delay(200);
  ensureWifi();
  timeClient.begin();
}

void loop() {
  ensureWifi();
  ensureMqtt();
  mqtt.loop();

  unsigned long now = millis();
  if (mqtt.connected() && now - lastPubMs >= pubIntervalMs) {
    lastPubMs = now;
    publishTelemetry();
  }

  delay(10);
}
