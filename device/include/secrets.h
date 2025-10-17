#pragma once

// Ajusta estos valores:
static const char* WIFI_SSID       = "Casa Lladser";
static const char* WIFI_PASS       = "g8rpRgmhmsjm";
static const char* DEVICE_ID       = "iot-device-v1";  // Identificador único del dispositivo
static const char* MQTT_HOST       = "192.168.1.146";
static const int   MQTT_PORT_CONST = MQTT_PORT;   // viene de build_flags (1883)
static const char* MQTT_USER       = "iot_ingest";
static const char* MQTT_PASS       = "changeme";
static const char* MQTT_BASE_TOPIC = "devices";
