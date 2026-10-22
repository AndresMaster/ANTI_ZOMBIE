import 'package:flutter/material.dart';

/// Estados posibles del ciclo de vida de la Alarma Antizombi.
enum AlarmPhase {
  /// En reposo: el usuario puede elegir la hora y activar la alarma.
  idle,

  /// Alarma programada y armada: esperando la hora de despertar con servidor HTTP + mDNS listos.
  armed,

  /// ¡Alarma sonando!: pantalla bloqueada, sonido en bucle, esperando señal de la ESP32.
  ringing,

  /// Despertar completado: la ESP32 envió la petición de apagado exitosamente.
  goodMorning,
}

/// Información del evento de apagado recibido desde la ESP32.
class Esp32WakeEvent {
  final String sourceIp;
  final String hostname;
  final DateTime timestamp;
  final String triggerMethod; // 'HTTP_POST_OFF' | 'MDNS_DISCOVERY'

  const Esp32WakeEvent({
    required this.sourceIp,
    required this.hostname,
    required this.timestamp,
    required this.triggerMethod,
  });
}

/// Modelo inmutable de configuración de hora de alarma.
class AlarmConfig {
  final TimeOfDay timeOfDay;
  final String esp32Hostname;
  final int httpServerPort;

  const AlarmConfig({
    required this.timeOfDay,
    this.esp32Hostname = 'esp32-alarma.local',
    this.httpServerPort = 8080,
  });

  /// Calcula el próximo [DateTime] en que ocurrirá la hora seleccionada.
  DateTime nextOccurrence([DateTime? from]) {
    final now = from ?? DateTime.now();
    var scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    if (scheduled.isBefore(now) || scheduled.isAtSameMomentAs(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String get formattedTime24h {
    final h = timeOfDay.hour.toString().padLeft(2, '0');
    final m = timeOfDay.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
