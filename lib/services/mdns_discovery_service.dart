import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';

import '../models/alarm_state_model.dart';

/// Servicio de descubrimiento y resolución mDNS para localizar `esp32-alarma.local`
/// en la red Wi-Fi local y verificar su encendido físico en la sala.
class MdnsDiscoveryService {
  final String targetHostname;
  final void Function(Esp32WakeEvent event) onEsp32DiscoveredWhileRinging;
  final void Function(String? resolvedIp) onResolutionStatusUpdated;

  MDnsClient? _mdnsClient;
  Timer? _scanTimer;
  bool _isScanning = false;
  String? _lastResolvedIp;

  MdnsDiscoveryService({
    this.targetHostname = 'esp32-alarma.local',
    required this.onEsp32DiscoveredWhileRinging,
    required this.onResolutionStatusUpdated,
  });

  bool get isScanning => _isScanning;
  String? get lastResolvedIp => _lastResolvedIp;

  /// Inicia el radar mDNS periódico que busca `esp32-alarma.local` en la red local.
  Future<void> startDiscovery({required bool Function() isAlarmRinging}) async {
    if (_isScanning) return;
    _isScanning = true;

    _scanTimer?.cancel();
    // Escaneo periódico cada 3 segundos mientras la alarma está activa o armada
    _scanTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_isScanning) return;
      await _performMdnsAndHttpLookup(triggerShutdownIfFound: isAlarmRinging());
    });

    // Ejecuta una primera búsqueda inmediata
    unawaited(
      _performMdnsAndHttpLookup(triggerShutdownIfFound: isAlarmRinging()),
    );
  }

  /// Realiza la resolución mDNS del host `esp32-alarma.local` (registros A y PTR `_http._tcp.local`)
  /// y verifica conectividad con la ESP32.
  Future<String?> _performMdnsAndHttpLookup({
    required bool triggerShutdownIfFound,
  }) async {
    String? foundIp;

    // 1. Resolución mediante paquete multicast_dns (registros IPv4 A y PTR _http._tcp.local)
    final MDnsClient client = MDnsClient(
      rawDatagramSocketFactory: (
        dynamic host,
        int port, {
        bool reuseAddress = true,
        bool reusePort = false,
        int ttl = 255,
      }) {
        return RawDatagramSocket.bind(
          host,
          port,
          reuseAddress: true,
          ttl: ttl,
        );
      },
    );

    try {
      await client.start();
      _mdnsClient = client;

      // Consulta directa de registro A para esp32-alarma.local
      await for (final IPAddressResourceRecord record
          in client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv4(targetHostname),
        timeout: const Duration(milliseconds: 1400),
      )) {
        foundIp = record.address.address;
        break;
      }

      // Si no respondió al query A directo, busca en anuncios PTR _http._tcp.local
      if (foundIp == null) {
        final cleanName = targetHostname.replaceAll('.local', '').toLowerCase();
        await for (final PtrResourceRecord ptr
            in client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer('_http._tcp.local'),
          timeout: const Duration(milliseconds: 1200),
        )) {
          if (ptr.domainName.toLowerCase().contains(cleanName)) {
            await for (final SrvResourceRecord srv
                in client.lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
              timeout: const Duration(milliseconds: 900),
            )) {
              await for (final IPAddressResourceRecord ipRecord
                  in client.lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
                timeout: const Duration(milliseconds: 900),
              )) {
                foundIp = ipRecord.address.address;
                break;
              }
              if (foundIp != null) break;
            }
          }
          if (foundIp != null) break;
        }
      }
    } catch (_) {
      // En algunos dispositivos móviles el socket multicast requiere fallback del OS
    } finally {
      client.stop();
      _mdnsClient = null;
    }

    // 2. Fallback por resolvedor nativo del SO (Bonjour en iOS / NSD en Android)
    if (foundIp == null) {
      try {
        final addresses = await InternetAddress.lookup(targetHostname)
            .timeout(const Duration(milliseconds: 1000));
        if (addresses.isNotEmpty) {
          foundIp = addresses.first.address;
        }
      } catch (_) {}
    }

    // 3. Si encontramos la IP de la ESP32, verificamos que esté encendida y respondiendo
    if (foundIp != null) {
      final bool isAlive = await _verifyEsp32Reachable(foundIp);
      if (isAlive) {
        _lastResolvedIp = foundIp;
        onResolutionStatusUpdated(foundIp);

        if (triggerShutdownIfFound) {
          onEsp32DiscoveredWhileRinging(
            Esp32WakeEvent(
              sourceIp: foundIp,
              hostname: targetHostname,
              timestamp: DateTime.now(),
              triggerMethod: 'MDNS_DISCOVERY ($targetHostname)',
            ),
          );
        }
        return foundIp;
      }
    }

    _lastResolvedIp = null;
    onResolutionStatusUpdated(null);
    return null;
  }

  /// Verifica mediante una petición HTTP rápida o socket TCP que la ESP32 esté realmente encendida
  /// (evita falsos positivos por caché DNS antiguo en el router).
  Future<bool> _verifyEsp32Reachable(String ip) async {
    try {
      final uri = Uri.parse('http://$ip/');
      final response =
          await http.get(uri).timeout(const Duration(milliseconds: 1200));
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      try {
        final socket = await Socket.connect(
          ip,
          80,
          timeout: const Duration(milliseconds: 900),
        );
        socket.destroy();
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Detiene el radar mDNS.
  Future<void> stopDiscovery() async {
    _isScanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
    _mdnsClient?.stop();
    _mdnsClient = null;
  }
}
