import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/alarm_controller.dart';
import '../core/theme/app_theme.dart';

/// Pantalla 3: Pantalla de Éxito de Buenos Días.
/// Se muestra automáticamente en el instante en que la ESP32 envía la petición
/// de apagado por red local. Permite regresar al estado de reposo para el día siguiente.
class GoodMorningScreen extends StatelessWidget {
  const GoodMorningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AlarmController>();
    final wakeEvent = controller.lastWakeEvent;
    final formattedWakeTime = wakeEvent != null
        ? DateFormat('HH:mm:ss').format(wakeEvent.timestamp)
        : DateFormat('HH:mm:ss').format(DateTime.now());

    return Scaffold(
      backgroundColor: AntizombiTheme.bgObsidian,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Insignia superior de verificación de hardware
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AntizombiTheme.emeraldSuccess
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AntizombiTheme.emeraldSuccess
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: AntizombiTheme.emeraldSuccess,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'ESP32 CONECTADA EN LA SALA · ALARMA APAGADA',
                          style: TextStyle(
                            color: AntizombiTheme.emeraldSuccess,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Bloque central motivacional de Buenos Días
              Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          AntizombiTheme.amberPrimary.withValues(alpha: 0.14),
                      border: Border.all(
                        color:
                            AntizombiTheme.amberPrimary.withValues(alpha: 0.45),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AntizombiTheme.amberPrimary
                              .withValues(alpha: 0.18),
                          blurRadius: 34,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wb_sunny_rounded,
                      color: AntizombiTheme.amberPrimary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '¡Buenos días!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AntizombiTheme.textPrimary,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    controller.motivationalQuote.isNotEmpty
                        ? controller.motivationalQuote
                        : 'Ya estás de pie en la sala y la ESP32 confirmó tu despertar. ¡Que tengas un excelente día!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AntizombiTheme.textSecondary,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),

              // Tarjeta de resumen técnico del disparo de apagado
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AntizombiTheme.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AntizombiTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'REGISTRO DE DESPERTAR FÍSICO',
                      style: TextStyle(
                        color: AntizombiTheme.amberPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      'Hora de apagado',
                      formattedWakeTime,
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Dispositivo mDNS',
                      wakeEvent?.hostname ?? controller.esp32Hostname,
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'IP Origen ESP32',
                      wakeEvent?.sourceIp ?? 'Red Wi-Fi Local',
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Protocolo',
                      wakeEvent?.triggerMethod ?? 'HTTP /off + mDNS',
                    ),
                  ],
                ),
              ),

              // Botón para volver al estado de reposo lista para el día siguiente
              SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await controller.resetToIdleForTomorrow();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AntizombiTheme.emeraldSuccess,
                    foregroundColor: AntizombiTheme.bgObsidian,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
                  label: const Text(
                    'LISTO PARA MAÑANA (VOLVER A REPOSO)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AntizombiTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AntizombiTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
