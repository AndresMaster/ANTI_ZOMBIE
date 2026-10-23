import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Servicio de notificaciones locales de alta prioridad (Full-Screen Intent)
/// para alertar al usuario en Android e iOS incluso con pantalla bloqueada.
class NotificationService {
  static const int alarmNotificationId = 9001;
  static const String channelId = 'antizombi_alarm_channel';
  static const String channelName = 'Alarma ESP32 Antizombi';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize({
    void Function(NotificationResponse)? onNotificationTap,
  }) async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: onNotificationTap,
      );

      // Solicitar permisos en Android 13+
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    } catch (_) {
      // Ignora errores si la plataforma de escritorio no soporta notificaciones de forma nativa
    }

    _initialized = true;
  }

  /// Programa una notificación de alta prioridad para la hora de despertar.
  Future<void> scheduleAlarmNotification(DateTime scheduledTime) async {
    if (!_initialized) await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription:
          'Alertas críticas de despertar que requieren conexión con ESP32',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final tz.TZDateTime tzScheduled =
        tz.TZDateTime.from(scheduledTime, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        alarmNotificationId,
        '¡ALARMA ANTIZOMBI ACTIVA!',
        'Dispositivo desconectado. Ve a la sala, conecta la ESP32 para apagar la alarma.',
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // En emuladores o plataformas sin exact alarm habilitado, continúa con el Timer en primer plano
    }
  }

  /// Muestra inmediatamente la notificación persistente de alarma activa.
  Future<void> showRingingNotification() async {
    if (!_initialized) await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    try {
      await _notificationsPlugin.show(
        alarmNotificationId,
        '¡ALARMA ANTIZOMBI ACTIVA!',
        'Ve a la sala y conecta la ESP32 para detener la alarma.',
        const NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
          macOS: darwinDetails,
        ),
      );
    } catch (_) {}
  }

  /// Cancela todas las notificaciones de la alarma cuando la ESP32 la apaga.
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancel(alarmNotificationId);
    } catch (_) {}
  }
}
