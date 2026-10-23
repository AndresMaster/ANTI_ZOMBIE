/**
 * Firmware: Alarma ESP32 Antizombi (Zero-Configuration / Sin dependencia de IP)
 * -----------------------------------------------------------------------------
 * Ubicación: En la sala (desconectada durante la noche).
 * Funcionamiento al enchufarse en la mañana:
 *   1. Se conecta al Wi-Fi.
 *   2. Difunde señal UDP Broadcast (255.255.255.255:8080):
 *      Llega a toda la red local sin importar qué IP tenga tu teléfono hoy o mañana.
 *   3. Enciende el respondedor mDNS (esp32-alarma.local) para que el radar
 *      de la app Flutter la detecte automáticamente.
 *   4. Envía petición HTTP POST directa como respaldo.
 */

#include <WiFi.h>
#include <WiFiUdp.h>
#include <ESPmDNS.h>
#include <WebServer.h>
#include <HTTPClient.h>

const char* WIFI_SSID     = "AndrésQuitaEstrés";
const char* WIFI_PASSWORD = "A13200212m";

// Respaldo directo si se conoce la IP (opcional gracias a UDP Broadcast y mDNS)
const char* PHONE_IP      = "192.168.3.50";
const int   PHONE_PORT    = 8080;

WebServer server(80);
WiFiUDP udp;
unsigned long lastShutdownAttempt = 0;
bool alarmStoppedConfirmed = false;

void sendShutdownSignals() {
  if (WiFi.status() != WL_CONNECTED) return;

  // 1. MÉTODO MAESTRO: UDP Broadcast a 255.255.255.255
  // Funciona aunque tu teléfono o Mac cambien de IP todos los días
  udp.beginPacket(IPAddress(255, 255, 255, 255), PHONE_PORT);
  udp.print("{\"cmd\":\"OFF\",\"device\":\"esp32-alarma.local\"}");
  udp.endPacket();
  Serial.println("[ANTIZOMBI] Difusión UDP Broadcast enviada a toda la red Wi-Fi (255.255.255.255:8080)");

  // 2. MÉTODO RESPALDO: HTTP POST directo
  HTTPClient http;
  String url = String("http://") + PHONE_IP + ":" + String(PHONE_PORT) + "/off";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  String payload = "{\"hostname\":\"esp32-alarma.local\",\"status\":\"awake\"}";
  int httpResponseCode = http.POST(payload);

  if (httpResponseCode == 200) {
    Serial.println("[ANTIZOMBI] ¡Confirmación HTTP recibida de la app!");
    alarmStoppedConfirmed = true;
  }
  http.end();
}

void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("[ANTIZOMBI] Conectando a Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(350);
    Serial.print(".");
  }
  Serial.printf("\n[ANTIZOMBI] Conectado! IP: %s\n", WiFi.localIP().toString().c_str());

  // Inicia mDNS (esp32-alarma.local)
  if (MDNS.begin("esp32-alarma")) {
    MDNS.addService("http", "tcp", 80);
    Serial.println("[ANTIZOMBI] Responder mDNS activo: http://esp32-alarma.local");
  }

  // Servidor HTTP en la ESP32 para que el radar mDNS de la app verifique presencia
  server.on("/", HTTP_GET, []() {
    server.send(200, "application/json", "{\"device\":\"esp32-alarma.local\",\"alive\":true}");
  });
  server.begin();

  // Envía señales inmediatas al encender
  sendShutdownSignals();
}

void loop() {
  server.handleClient();

  // Reintenta emitir cada 2 segundos hasta que la alarma confirme apagado
  if (!alarmStoppedConfirmed && (millis() - lastShutdownAttempt > 2000)) {
    lastShutdownAttempt = millis();
    sendShutdownSignals();
  }
}
