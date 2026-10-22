import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/alarm_state_model.dart';
import '../services/alarm_audio_service.dart';
import '../services/local_http_server_service.dart';
import '../services/mdns_discovery_service.dart';
import '../services/notification_service.dart';

/// Controlador central de la aplicación Alarma ESP32 Antizombi.
/// Coordina la programación horaria, el audio insistente, el servidor HTTP local
/// y el resolvedor mDNS para el apagado físico desde la sala.
class AlarmController extends ChangeNotifier {
  static const String _prefHourKey = 'alarm_hour';
  static const String _prefMinuteKey = 'alarm_minute';
  static const String _prefArmedKey = 'alarm_is_armed';

  final AlarmAudioService _audioService = AlarmAudioService();
  final NotificationService _notificationService = NotificationService();
  late final LocalHttpServerService _httpServerService;
  late final MdnsDiscoveryService _mdnsService;

  AlarmPhase _phase = AlarmPhase.idle;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 6, minute: 30);
  DateTime? _scheduledDateTime;
  Duration _remainingTime = Duration.zero;
  Timer? _clockWatchdogTimer;

  String _esp32Hostname = 'esp32-alarma.local';
  final int _httpPort = 8080;
  String? _resolvedEsp32Ip;
  Esp32WakeEvent? _lastWakeEvent;
  String _motivationalQuote = '';

  static const List<String> _morningQuotes = [
    'Ya venciste la cama y caminaste hasta la sala. ¡El día es tuyo!',
    'Cero modo zombi: cuerpo en movimiento, mente enfocada. ¡Buenos días!',
    'La disciplina empieza en el primer minuto de la mañana. ¡A romperla hoy!',
    'ESP32 conectada, sueño derrotado. ¡Que tengas una mañana ultra productiva!',
  ];

  AlarmController() {
    _httpServerService = LocalHttpServerService(
      onEsp32ShutdownReceived: _handleEsp32WakeSignal,
      isAlarmCurrentlyActive: () =>
          _phase == AlarmPhase.ringing || _phase == AlarmPhase.armed,
    );

    _mdnsService = MdnsDiscoveryService(
      targetHostname: _esp32Hostname,
      onEsp32DiscoveredWhileRinging: _handleEsp32WakeSignal,
      onResolutionStatusUpdated: (ip) {
        if (_resolvedEsp32Ip != ip) {
          _resolvedEsp32Ip = ip;
          notifyListeners();
        }
      },
    );
  }

  // Getters públicos para la UI
  AlarmPhase get phase => _phase;
  TimeOfDay get selectedTime => _selectedTime;
  DateTime? get scheduledDateTime => _scheduledDateTime;
  Duration get remainingTime => _remainingTime;
  String get esp32Hostname => _esp32Hostname;
  int get httpPort => _httpPort;
  bool get isHttpServerRunning => _httpServerService.isRunning;
  String get localIpAddress => _httpServerService.localIpAddress;
  String get httpEndpointUrl => _httpServerService.endpointUrl;
  String? get resolvedEsp32Ip => _resolvedEsp32Ip;
  Esp32WakeEvent? get lastWakeEvent => _lastWakeEvent;
  String get motivationalQuote => _motivationalQuote;

  String get formattedSelectedTime {
    final h = _selectedTime.hour.toString().padLeft(2, '0');
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Inicializa servicios de audio, notificaciones, preferencias y red local.
  Future<void> initialize() async {
    await _audioService.initialize();
    await _notificationService.initialize();
    await _loadSavedPreferences();
    // Inicia el servidor HTTP desde el arranque para mostrar IP local lista
    await _httpServerService.startServer(port: _httpPort);
    notifyListeners();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHour = prefs.getInt(_prefHourKey) ?? 6;
    final savedMinute = prefs.getInt(_prefMinuteKey) ?? 30;
    final wasArmed = prefs.getBool(_prefArmedKey) ?? false;

    _selectedTime = TimeOfDay(hour: savedHour, minute: savedMinute);
    if (wasArmed) {
      await activateAlarm();
    }
  }

  /// Actualiza la hora seleccionada en el Time Picker.
  Future<void> updateSelectedTime(TimeOfDay newTime) async {
    _selectedTime = newTime;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefHourKey, newTime.hour);
    await prefs.setInt(_prefMinuteKey, newTime.minute);

    if (_phase == AlarmPhase.armed) {
      _recalculateSchedule();
    }
    notifyListeners();
  }

  /// Actualiza el hostname mDNS de la ESP32 si el usuario desea personalizarlo.
  void updateEsp32Hostname(String hostname) {
    if (hostname.trim().isEmpty) return;
    _esp32Hostname = hostname.trim();
    notifyListeners();
  }

  /// Activa la alarma ("Activar Alarma"), inicia el servidor HTTP local y el radar mDNS.
  Future<void> activateAlarm() async {
    final config = AlarmConfig(
      timeOfDay: _selectedTime,
      esp32Hostname: _esp32Hostname,
      httpServerPort: _httpPort,
    );

    _scheduledDateTime = config.nextOccurrence();
    _remainingTime = _scheduledDateTime!.difference(DateTime.now());
    _phase = AlarmPhase.armed;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefHourKey, _selectedTime.hour);
    await prefs.setInt(_prefMinuteKey, _selectedTime.minute);
    await prefs.setBool(_prefArmedKey, true);

    // Mantiene la CPU/pantalla lista y levanta servidor HTTP + mDNS
    try {
      await WakelockPlus.enable();
    } catch (_) {}

    await _httpServerService.startServer(port: _httpPort);
    await _mdnsService.startDiscovery(
      isAlarmRinging: () => _phase == AlarmPhase.ringing,
    );
    await _notificationService.scheduleAlarmNotification(_scheduledDateTime!);

    _startClockWatchdog();
    notifyListeners();
  }

  /// Cancela la alarma programada (solo disponible ANTES de que empiece a sonar).
  Future<void> disarmBeforeRinging() async {
    if (_phase == AlarmPhase.ringing) {
      // Regla de oro: prohibido desactivar manualmente cuando ya está sonando.
      return;
    }

    _clockWatchdogTimer?.cancel();
    _phase = AlarmPhase.idle;
    _scheduledDateTime = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefArmedKey, false);

    await _notificationService.cancelAll();
    await _mdnsService.stopDiscovery();
    try {
      await WakelockPlus.disable();
    } catch (_) {}

    notifyListeners();
  }

  void _recalculateSchedule() {
    final config = AlarmConfig(timeOfDay: _selectedTime);
    _scheduledDateTime = config.nextOccurrence();
    _remainingTime = _scheduledDateTime!.difference(DateTime.now());
  }

  void _startClockWatchdog() {
    _clockWatchdogTimer?.cancel();
    _clockWatchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_phase != AlarmPhase.armed || _scheduledDateTime == null) return;

      final now = DateTime.now();
      final diff = _scheduledDateTime!.difference(now);
      if (diff.isNegative || diff.inSeconds <= 0) {
        triggerAlarmNow();
      } else {
        _remainingTime = diff;
        notifyListeners();
      }
    });
  }

  /// Dispara inmediatamente el estado de Alarma Activa (Despertar).
  /// Inicia el sonido continuo, bloquea la UI y espera la señal HTTP/mDNS de la ESP32.
  Future<void> triggerAlarmNow() async {
    if (_phase == AlarmPhase.ringing) return;

    _clockWatchdogTimer?.cancel();
    _phase = AlarmPhase.ringing;
    _remainingTime = Duration.zero;

    try {
      await WakelockPlus.enable();
    } catch (_) {}

    // Asegura que el servidor HTTP local y el resolvedor mDNS estén activos
    await _httpServerService.startServer(port: _httpPort);
    await _mdnsService.startDiscovery(
      isAlarmRinging: () => _phase == AlarmPhase.ringing,
    );

    await _notificationService.showRingingNotification();
    await _audioService.startAlarmSound();

    notifyListeners();
  }

  /// Se ejecuta en el instante exacto en que la ESP32 envía la petición HTTP `/off`
  /// o es detectada encendida en la red local mientras suena la alarma.
  Future<void> _handleEsp32WakeSignal(Esp32WakeEvent event) async {
    // Si la alarma está sonando (o armada y se prueba la señal de la ESP32), la detiene
    if (_phase != AlarmPhase.ringing && _phase != AlarmPhase.armed) {
      return;
    }

    _lastWakeEvent = event;
    _motivationalQuote =
        _morningQuotes[DateTime.now().second % _morningQuotes.length];

    // 1. Detiene inmediatamente el sonido de la alarma y las notificaciones
    await _audioService.stopAlarmSound();
    await _notificationService.cancelAll();
    await _mdnsService.stopDiscovery();
    _clockWatchdogTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefArmedKey, false);

    // 2. Muestra la pantalla de éxito de Buenos Días
    _phase = AlarmPhase.goodMorning;
    notifyListeners();
  }

  /// Vuelve al estado de reposo lista para el día siguiente.
  Future<void> resetToIdleForTomorrow() async {
    _phase = AlarmPhase.idle;
    _scheduledDateTime = null;
    _remainingTime = Duration.zero;
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _clockWatchdogTimer?.cancel();
    _audioService.dispose();
    _mdnsService.stopDiscovery();
    _httpServerService.stopServer();
    super.dispose();
  }
}
