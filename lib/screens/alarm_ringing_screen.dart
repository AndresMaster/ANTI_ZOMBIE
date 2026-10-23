import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/alarm_controller.dart';
import '../core/theme/app_theme.dart';
import '../widgets/network_status_card.dart';

/// Pantalla 2: Pantalla de Alarma Activa (Pantalla de Despertar).
/// - Se bloquea visualmente con `PopScope(canPop: false)`.
/// - Muestra alerta impactante en Modo Oscuro con acentos rojos parpadeantes.
/// - REGLA DE ORO: El botón tradicional de "Apagar" está deshabilitado y muestra el mensaje:
///   "Dispositivo desconectado. Ve a la sala, conecta la ESP32 para apagar la alarma".
class AlarmRingingScreen extends StatefulWidget {
  const AlarmRingingScreen({super.key});

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AlarmController>();
    final currentTimeStr = DateFormat('HH:mm:ss').format(_now);

    return PopScope(
      canPop: false, // Bloquea el botón Atrás del sistema
      child: Scaffold(
        backgroundColor: AntizombiTheme.bgObsidian,
        body: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final glowAlpha = 0.08 + (_pulseAnimation.value * 0.24);
            final borderAlpha = 0.30 + (_pulseAnimation.value * 0.65);

            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 1.15,
                  colors: [
                    AntizombiTheme.crimsonAlert.withValues(alpha: glowAlpha),
                    AntizombiTheme.bgObsidian,
                  ],
                ),
                border: Border.all(
                  color: AntizombiTheme.crimsonAlert
                      .withValues(alpha: borderAlpha),
                  width: 2.5,
                ),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabecera de Alerta Crítica Parpadeante
                  _buildBlinkingAlertBadge(),

                  // Reloj gigante en tiempo real
                  Column(
                    children: [
                      Text(
                        currentTimeStr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AntizombiTheme.textPrimary,
                          fontSize: 58,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ALARMA PROGRAMADA: ${controller.formattedSelectedTime}',
                        style: const TextStyle(
                          color: AntizombiTheme.crimsonAlert,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),

                  // REGLA DE ORO: Mensaje grande y claro de desconexión de la ESP32
                  _buildGoldenRuleAlertBox(),

                  // Estado en vivo del Servidor HTTP Local (:8080) y Radar mDNS
                  NetworkStatusCard(
                    isServerRunning: controller.isHttpServerRunning,
                    endpointUrl: controller.httpEndpointUrl,
                    esp32Hostname: controller.esp32Hostname,
                    resolvedEsp32Ip: controller.resolvedEsp32Ip,
                    isRingingMode: true,
                  ),

                  // Botón de Apagar Tradicional DESHABILITADO por diseño
                  _buildDisabledStopButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlinkingAlertBadge() {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(_pulseAnimation),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AntizombiTheme.crimsonDark.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: AntizombiTheme.crimsonAlert,
            width: 1.2,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_active_rounded,
              color: AntizombiTheme.crimsonAlert,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'MODO ANTIZOMBI ACTIVO · BLOQUEO DE PANTALLA',
              style: TextStyle(
                color: AntizombiTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldenRuleAlertBox() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          decoration: BoxDecoration(
            color: AntizombiTheme.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Color.lerp(
                AntizombiTheme.crimsonDark,
                AntizombiTheme.crimsonAlert,
                _pulseAnimation.value,
              )!,
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: AntizombiTheme.crimsonAlert
                    .withValues(alpha: 0.14 * _pulseAnimation.value),
                blurRadius: 28,
                spreadRadius: 3,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AntizombiTheme.crimsonAlert.withValues(alpha: 0.15),
              border: Border.all(
                color: AntizombiTheme.crimsonAlert.withValues(alpha: 0.5),
              ),
            ),
            child: const Icon(
              Icons.router_rounded,
              size: 34,
              color: AntizombiTheme.crimsonAlert,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Dispositivo desconectado. Ve a la sala, conecta la ESP32 para apagar la alarma',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AntizombiTheme.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.35,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Esperando petición HTTP en el puerto 8080 o anuncio mDNS de esp32-alarma.local...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AntizombiTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledStopButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton.icon(
            // Botón explícitamente deshabilitado (null) cumpliendo la Regla de Oro
            onPressed: null,
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: AntizombiTheme.bgCard,
              disabledForegroundColor: AntizombiTheme.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(
                  color: AntizombiTheme.borderSubtle,
                  width: 1,
                ),
              ),
            ),
            icon: const Icon(Icons.lock_outline_rounded, size: 20),
            label: const Text(
              'APAGADO MANUAL DESHABILITADO',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
