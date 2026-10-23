import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../models/alarm_state_model.dart';

/// Servidor HTTP local embebido que escucha en segundo plano (puerto 8080 por defecto).
/// Recibe la petición de apagado enviada por la ESP32 al conectarse a la corriente.
class LocalHttpServerService {
  HttpServer? _server;
  RawDatagramSocket? _udpSocket;
  String? _localIpAddress;
  int _port = 8080;

  final void Function(Esp32WakeEvent event) onEsp32ShutdownReceived;
  final bool Function() isAlarmCurrentlyActive;

  LocalHttpServerService({
    required this.onEsp32ShutdownReceived,
    required this.isAlarmCurrentlyActive,
  });

  bool get isRunning => _server != null;
  String get localIpAddress => _localIpAddress ?? '0.0.0.0';
  int get port => _port;
  String get endpointUrl => 'http://$localIpAddress:$_port/off';

  /// Inicia el servidor HTTP local en [port] (por defecto 8080).
  Future<void> startServer({int port = 8080}) async {
    _port = port;
    await _refreshLocalIp();

    if (_server != null) {
      return;
    }

    final router = Router();

    // Endpoint de salud y autodescubrimiento para que la ESP32 identifique el teléfono
    router.get('/status', (Request request) {
      return _jsonResponse(200, {
        'service': 'alarma-esp32-antizombi',
        'status': 'listening',
        'alarmRinging': isAlarmCurrentlyActive(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    // Endpoints de apagado que la ESP32 invoca apenas se enchufa en la sala
    router.get('/off', _handleShutdownRequest);
    router.post('/off', _handleShutdownRequest);
    router.get('/alarm/stop', _handleShutdownRequest);
    router.post('/alarm/stop', _handleShutdownRequest);

    final handler = const Pipeline()
        .addMiddleware(_corsAndLoggingMiddleware())
        .addHandler(router.call);

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      _port,
      shared: true,
    );

    // Escucha de difusión UDP (Broadcast 255.255.255.255) para que la ESP32
    // pueda apagar la alarma sin conocer la IP del teléfono (Zero-Configuration).
    try {
      _udpSocket?.close();
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _port,
        reuseAddress: true,
        reusePort: true,
      );
      _udpSocket?.broadcastEnabled = true;
      _udpSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram != null) {
            final msg = utf8.decode(datagram.data).trim();
            if (msg.toUpperCase().contains('OFF') ||
                msg.contains('esp32-alarma')) {
              final wakeEvent = Esp32WakeEvent(
                sourceIp: datagram.address.address,
                hostname: 'esp32-alarma.local',
                timestamp: DateTime.now(),
                triggerMethod: 'UDP_BROADCAST_255.255.255.255',
              );
              onEsp32ShutdownReceived(wakeEvent);
            }
          }
        }
      });
    } catch (_) {}
  }

  /// Procesa la petición HTTP de la ESP32 para detener la alarma inmediatamente.
  Future<Response> _handleShutdownRequest(Request request) async {
    final connectionInfo =
        request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
    final remoteIp =
        connectionInfo?.remoteAddress.address ?? 'ESP32-Red-Local';

    String hostname = 'esp32-alarma.local';
    try {
      if (request.method == 'POST') {
        final bodyStr = await request.readAsString();
        if (bodyStr.isNotEmpty) {
          final Map<String, dynamic> payload = jsonDecode(bodyStr);
          if (payload['hostname'] is String) {
            hostname = payload['hostname'] as String;
          }
        }
      } else if (request.url.queryParameters['hostname'] != null) {
        hostname = request.url.queryParameters['hostname']!;
      }
    } catch (_) {
      // Cuerpo opcional, continúa con valores por defecto
    }

    final wakeEvent = Esp32WakeEvent(
      sourceIp: remoteIp,
      hostname: hostname,
      timestamp: DateTime.now(),
      triggerMethod: 'HTTP_${request.method}_/off',
    );

    // Notifica al controlador principal en el instante exacto de la petición
    onEsp32ShutdownReceived(wakeEvent);

    return _jsonResponse(200, {
      'status': 'ok',
      'alarmStopped': true,
      'message': 'Alarma Antizombi detenida. ¡Buenos días!',
      'esp32Ip': remoteIp,
      'timestamp': wakeEvent.timestamp.toIso8601String(),
    });
  }

  Middleware _corsAndLoggingMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, X-ESP32-Token',
    'Content-Type': 'application/json; charset=utf-8',
  };

  Response _jsonResponse(int statusCode, Map<String, dynamic> body) {
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: _corsHeaders,
    );
  }

  /// Obtiene la IP local Wi-Fi del dispositivo móvil para mostrarla en la UI.
  Future<void> _refreshLocalIp() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) {
        _localIpAddress = wifiIp;
        return;
      }
    } catch (_) {}

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            _localIpAddress = addr.address;
            return;
          }
        }
      }
    } catch (_) {
      _localIpAddress = '0.0.0.0';
    }
  }

  /// Detiene el servidor HTTP local y el socket UDP cuando ya no son necesarios.
  Future<void> stopServer() async {
    _udpSocket?.close();
    _udpSocket = null;
    await _server?.close(force: true);
    _server = null;
  }
}
