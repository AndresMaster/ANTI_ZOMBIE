import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/alarm_controller.dart';
import '../core/theme/app_theme.dart';
import '../models/alarm_state_model.dart';
import '../widgets/dark_time_picker.dart';
import '../widgets/network_status_card.dart';

/// Pantalla 1: Configuración y Activación de la Alarma ESP32 Antizombi.
/// Estética Dark Mode de cero deslumbramientos con acentos en ámbar cálido.
class AlarmSetupScreen extends StatelessWidget {
  const AlarmSetupScreen({super.key});

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AlarmController>();
    final isArmed = controller.phase == AlarmPhase.armed;

    return Scaffold(
      backgroundColor: AntizombiTheme.bgObsidian,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado con insignia de estado
              _buildHeader(isArmed),
              const SizedBox(height: 24),

              // Selector de Hora Intuitivo (Time Picker en Modo Oscuro)
              DarkTimePicker(
                selectedTime: controller.selectedTime,
                enabled: !isArmed,
                onTimeChanged: controller.updateSelectedTime,
              ),
              const SizedBox(height: 18),

              // Tarjeta de cuenta regresiva cuando la alarma está armada
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isArmed
                    ? _buildArmedCountdownBanner(controller)
                    : _buildRuleExplanationBanner(),
              ),
              const SizedBox(height: 18),

              // Telemetría de Servidor HTTP Local y mDNS
              NetworkStatusCard(
                isServerRunning: controller.isHttpServerRunning,
                endpointUrl: controller.httpEndpointUrl,
                esp32Hostname: controller.esp32Hostname,
                resolvedEsp32Ip: controller.resolvedEsp32Ip,
              ),
              const SizedBox(height: 28),

              // Botón grande y llamativo para "Activar Alarma"
              _buildPrimaryActionButton(context, controller, isArmed),

              const SizedBox(height: 14),

              // Botón secundario para probar inmediatamente el disparo de la alarma
              _buildSimulateTriggerButton(controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isArmed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  color: isArmed
                      ? AntizombiTheme.amberPrimary
                      : AntizombiTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 6),
                const Text(
                  'ALARMA ESP32',
                  style: TextStyle(
                    color: AntizombiTheme.amberPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Antizombi',
              style: TextStyle(
                color: AntizombiTheme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isArmed
                ? AntizombiTheme.amberPrimary.withValues(alpha: 0.14)
                : AntizombiTheme.bgCard,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isArmed
                  ? AntizombiTheme.amberPrimary
                  : AntizombiTheme.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isArmed ? Icons.shield_moon_rounded : Icons.bedtime_outlined,
                size: 15,
                color: isArmed
                    ? AntizombiTheme.amberPrimary
                    : AntizombiTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                isArmed ? 'ARMADA' : 'EN REPOSO',
                style: TextStyle(
                  color: isArmed
                      ? AntizombiTheme.amberPrimary
                      : AntizombiTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArmedCountdownBanner(AlarmController controller) {
    return Container(
      key: const ValueKey('armed_banner'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AntizombiTheme.amberPrimary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AntizombiTheme.borderAmberGlow),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AntizombiTheme.amberPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: AntizombiTheme.amberPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ALARMA PROGRAMADA Y SERVIDOR ACTIVO',
                  style: TextStyle(
                    color: AntizombiTheme.amberPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sonará en ${_formatDuration(controller.remainingTime)}',
                  style: const TextStyle(
                    color: AntizombiTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleExplanationBanner() {
    return Container(
      key: const ValueKey('rule_banner'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AntizombiTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AntizombiTheme.borderSubtle),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.memory_rounded,
            color: AntizombiTheme.amberPrimary,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Al sonar la alarma, el botón de apagado quedará bloqueado. '
              'Solo se detendrá cuando enchufes tu ESP32 en la sala.',
              style: TextStyle(
                color: AntizombiTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton(
    BuildContext context,
    AlarmController controller,
    bool isArmed,
  ) {
    if (!isArmed) {
      return SizedBox(
        height: 64,
        child: ElevatedButton(
          onPressed: () async {
            HapticFeedback.heavyImpact();
            await controller.activateAlarm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AntizombiTheme.amberPrimary,
            foregroundColor: AntizombiTheme.bgObsidian,
            elevation: 8,
            shadowColor: AntizombiTheme.amberPrimary.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.alarm_on_rounded, size: 26),
              SizedBox(width: 12),
              Text(
                'ACTIVAR ALARMA',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 58,
      child: OutlinedButton.icon(
        onPressed: () async {
          HapticFeedback.mediumImpact();
          await controller.disarmBeforeRinging();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AntizombiTheme.textPrimary,
          side: const BorderSide(color: AntizombiTheme.borderSubtle, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.edit_calendar_rounded, size: 20),
        label: const Text(
          'MODIFICAR HORA / DESARMAR ANTES DE DORMIR',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }

  Widget _buildSimulateTriggerButton(AlarmController controller) {
    return TextButton.icon(
      onPressed: () {
        HapticFeedback.heavyImpact();
        controller.triggerAlarmNow();
      },
      style: TextButton.styleFrom(
        foregroundColor: AntizombiTheme.crimsonAlert.withValues(alpha: 0.9),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: const Icon(Icons.warning_amber_rounded, size: 18),
      label: const Text(
        'Probar Despertar Ahora (Disparar Alarma Activa)',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
