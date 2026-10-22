/**
 * Firmware de Referencia: Alarma ESP32 Antizombi
 * -----------------------------------------------
 * Ubicación física: En la sala (desconectada durante la noche).
 * Funcionamiento al enchufarse en la mañana:
 *   1. Se conecta automáticamente a la red Wi-Fi del hogar.
 *   2. Anuncia su nombre mDNS `esp32-alarma.local` y servicio `_http._tcp` (puerto 80)
 *      para que el radar mDNS de la app Flutter la detecte de inmediato.
 *   3. Envía una petición HTTP POST directa a `http://<IP_DEL_TELEFONO>:8080/off`
 *      para detener la alarma en el instante exacto de encendido.
 */

#include <WiFi.h>
#include <ESPmDNS.h>
#include <WebServer.h>
#include <HTTPClient.h>

const char* WIFI_SSID     = "TU_RED_WIFI";
const char* WIFI_PASSWORD = "TU_PASSWORD_WIFI";

// IP del teléfono mostrada en la tarjeta "Telemetría de Red Local" de la app
const char* PHONE_IP      = "192.168.1.100";
const int   PHONE_PORT    = 8080;

WebServer server(80);
unsigned long lastShutdownAttempt = 0;
bool alarmStoppedConfirmed = false;

void sendShutdownToPhone() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String("http://") + PHONE_IP + ":" + String(PHONE_PORT) + "/off";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  String payload = "{\"hostname\":\"esp32-alarma.local\",\"status\":\"awake\"}";
  int httpResponseCode = http.POST(payload);

  if (httpResponseCode == 200) {
    Serial.println("[ANTIZOMBI] ¡Alarma del teléfono apagada con éxito!");
    alarmStoppedConfirmed = true;
  } else {
    Serial.printf("[ANTIZOMBI] Intento HTTP POST (%d) hacia %s\n", httpResponseCode, url.c_str());
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

  // 1. Inicia mDNS como esp32-alarma.local
  if (MDNS.begin("esp32-alarma")) {
    MDNS.addService("http", "tcp", 80);
    Serial.println("[ANTIZOMBI] Responder mDNS activo: http://esp32-alarma.local");
  }

  // 2. Servidor HTTP en puerto 80 para que el teléfono verifique presencia por mDNS
  server.on("/", HTTP_GET, []() {
    server.send(200, "application/json", "{\"device\":\"esp32-alarma.local\",\"alive\":true}");
  });
  server.begin();

  // 3. Disparo inmediato hacia el servidor HTTP local de la app en el teléfono
  sendShutdownToPhone();
}

void loop() {
  server.handleClient();

  // Reintenta cada 2 segundos hasta que el teléfono confirme el apagado
  if (!alarmStoppedConfirmed && (millis() - lastShutdownAttempt > 2000)) {
    lastShutdownAttempt = millis();
    sendShutdownToPhone();
  }
}
