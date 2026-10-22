import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';

/// Tarjeta minimalista con bordes sutiles que muestra el estado del
/// Servidor HTTP Local y del Resolvedor mDNS (`esp32-alarma.local`).
class NetworkStatusCard extends StatelessWidget {
  final bool isServerRunning;
  final String endpointUrl;
  final String esp32Hostname;
  final String? resolvedEsp32Ip;
  final bool isRingingMode;

  const NetworkStatusCard({
    super.key,
    required this.isServerRunning,
    required this.endpointUrl,
    required this.esp32Hostname,
    required this.resolvedEsp32Ip,
    this.isRingingMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isRingingMode
        ? AntizombiTheme.crimsonAlert
        : AntizombiTheme.amberPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AntizombiTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRingingMode
              ? AntizombiTheme.borderCrimsonGlow
              : AntizombiTheme.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isServerRunning
                      ? AntizombiTheme.emeraldSuccess
                      : AntizombiTheme.crimsonAlert,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'TELEMETRÍA DE RED LOCAL (mDNS + HTTP)',
                style: TextStyle(
                  color: AntizombiTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fila 1: Endpoint HTTP Local
          _buildInfoRow(
            context: context,
            icon: Icons.dns_rounded,
            label: 'Servidor HTTP App',
            value: isServerRunning ? endpointUrl : 'Iniciando puerto 8080...',
            accentColor: accentColor,
            copyable: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AntizombiTheme.borderSubtle, height: 1),
          ),
          // Fila 2: Hostname mDNS de la ESP32
          _buildInfoRow(
            context: context,
            icon: Icons.wifi_tethering_rounded,
            label: 'Nodo mDNS Objetivo',
            value: resolvedEsp32Ip != null
                ? '$esp32Hostname ($resolvedEsp32Ip)'
                : '$esp32Hostname (Desconectado)',
            accentColor: resolvedEsp32Ip != null
                ? AntizombiTheme.emeraldSuccess
                : AntizombiTheme.textSecondary,
            copyable: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
    required bool copyable,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AntizombiTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AntizombiTheme.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (copyable)
          IconButton(
            tooltip: 'Copiar URL para ESP32',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AntizombiTheme.bgCardElevated,
                  content: Text(
                    'Endpoint copiado: $value',
                    style: const TextStyle(color: AntizombiTheme.textPrimary),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(
              Icons.copy_rounded,
              size: 16,
              color: AntizombiTheme.textSecondary,
            ),
          ),
      ],
    );
  }
}
