#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

#include "secrets.h"

WiFiClient wifi;
PubSubClient mqtt(wifi);

static const char *DEVICE_TOPIC = "botarena/telemetry/" DEVICE_ID;

void connectWiFi()
{
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("WiFi connecting");
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("WiFi connected. IP: ");
  Serial.println(WiFi.localIP());
}

void connectMQTT()
{
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  // mqtt.setCallback(...) si necesitas suscripción

  Serial.print("MQTT connecting");
  while (!mqtt.connected())
  {
    if (mqtt.connect(DEVICE_ID, MQTT_USER, MQTT_PASS))
    {
      Serial.println();
      Serial.println("MQTT connected");
      break;
    }
    else
    {
      Serial.print(".");
      delay(1000);
    }
  }
}

void publishTelemetry() {
  // JSON moderno (ArduinoJson 7+)
  JsonDocument doc;
  doc["device"] = DEVICE_ID;
  doc["ip"] = WiFi.localIP().toString();
  doc["rssi"] = WiFi.RSSI();
  doc["heap"] = ESP.getFreeHeap();
  doc["millis"] = (uint32_t)millis();

  // Serializa a buffer
  char buf[256];
  size_t len = serializeJson(doc, buf, sizeof(buf));

  if (len > 0)
  {
    // Usa la sobrecarga publish(const char* topic, const char* payload)
    bool ok = mqtt.publish(DEVICE_TOPIC, buf);
    Serial.print("publish(");
    Serial.print(DEVICE_TOPIC);
    Serial.print(") -> ");
    Serial.println(ok ? "OK" : "FAIL");
  }
  else
  {
    Serial.println("serializeJson failed");
  }
}

unsigned long lastPub = 0;

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println();
  Serial.println("Booting...");

  connectWiFi();
  connectMQTT();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED)
  {
    connectWiFi();
  }
  if (!mqtt.connected())
  {
    connectMQTT();
  }
  mqtt.loop();

  unsigned long now = millis();
  if (now - lastPub > 5000)
  {
    lastPub = now;
    publishTelemetry();
  }
}
