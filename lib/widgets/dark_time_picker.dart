import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';

/// Selector de hora nocturno ("Cero Deslumbramientos") con ruedas táctiles
/// de precisión y opción de reloj circular en modo oscuro.
class DarkTimePicker extends StatefulWidget {
  final TimeOfDay selectedTime;
  final ValueChanged<TimeOfDay> onTimeChanged;
  final bool enabled;

  const DarkTimePicker({
    super.key,
    required this.selectedTime,
    required this.onTimeChanged,
    this.enabled = true,
  });

  @override
  State<DarkTimePicker> createState() => _DarkTimePickerState();
}

class _DarkTimePickerState extends State<DarkTimePicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hourController =
        FixedExtentScrollController(initialItem: widget.selectedTime.hour);
    _minuteController =
        FixedExtentScrollController(initialItem: widget.selectedTime.minute);
  }

  @override
  void didUpdateWidget(covariant DarkTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTime.hour != widget.selectedTime.hour &&
        _hourController.hasClients) {
      _hourController.jumpToItem(widget.selectedTime.hour);
    }
    if (oldWidget.selectedTime.minute != widget.selectedTime.minute &&
        _minuteController.hasClients) {
      _minuteController.jumpToItem(widget.selectedTime.minute);
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  Future<void> _openDialPicker(BuildContext context) async {
    if (!widget.enabled) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: widget.selectedTime,
      helpText: 'SELECCIONA LA HORA DE DESPERTAR',
      cancelText: 'CANCELAR',
      confirmText: 'GUARDAR',
      builder: (context, child) {
        return Theme(
          data: AntizombiTheme.darkTheme.copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AntizombiTheme.bgCard,
              hourMinuteColor: AntizombiTheme.bgObsidian,
              hourMinuteTextColor: AntizombiTheme.amberPrimary,
              dialBackgroundColor: AntizombiTheme.bgObsidian,
              dialHandColor: AntizombiTheme.amberPrimary,
              dialTextColor: AntizombiTheme.textPrimary,
              entryModeIconColor: AntizombiTheme.amberPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(
                  color: AntizombiTheme.borderAmberGlow,
                  width: 1,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      widget.onTimeChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AntizombiTheme.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.enabled
              ? AntizombiTheme.borderAmberGlow
              : AntizombiTheme.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AntizombiTheme.amberPrimary.withValues(alpha: 0.05),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: widget.enabled
                        ? AntizombiTheme.amberPrimary
                        : AntizombiTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'HORA PROGRAMADA (24H)',
                    style: TextStyle(
                      color: AntizombiTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              if (widget.enabled)
                TextButton.icon(
                  onPressed: () => _openDialPicker(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AntizombiTheme.amberPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.touch_app_rounded, size: 16),
                  label: const Text(
                    'Teclado / Reloj',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 175,
            child: AbsorbPointer(
              absorbing: !widget.enabled,
              child: Opacity(
                opacity: widget.enabled ? 1.0 : 0.65,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Banda central resaltada para la hora seleccionada
                    Container(
                      height: 58,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AntizombiTheme.bgObsidian.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AntizombiTheme.amberPrimary
                              .withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Rueda de Horas (00 - 23)
                        SizedBox(
                          width: 110,
                          child: CupertinoPicker.builder(
                            scrollController: _hourController,
                            itemExtent: 58,
                            diameterRatio: 1.3,
                            selectionOverlay: const SizedBox.shrink(),
                            childCount: 24,
                            onSelectedItemChanged: (hour) {
                              HapticFeedback.selectionClick();
                              widget.onTimeChanged(
                                TimeOfDay(
                                  hour: hour,
                                  minute: widget.selectedTime.minute,
                                ),
                              );
                            },
                            itemBuilder: (context, index) {
                              final isSelected =
                                  index == widget.selectedTime.hour;
                              return Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: isSelected ? 42 : 28,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AntizombiTheme.amberPrimary
                                        : AntizombiTheme.textMuted,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: AntizombiTheme.amberPrimary,
                            ),
                          ),
                        ),
                        // Rueda de Minutos (00 - 59)
                        SizedBox(
                          width: 110,
                          child: CupertinoPicker.builder(
                            scrollController: _minuteController,
                            itemExtent: 58,
                            diameterRatio: 1.3,
                            selectionOverlay: const SizedBox.shrink(),
                            childCount: 60,
                            onSelectedItemChanged: (minute) {
                              HapticFeedback.selectionClick();
                              widget.onTimeChanged(
                                TimeOfDay(
                                  hour: widget.selectedTime.hour,
                                  minute: minute,
                                ),
                              );
                            },
                            itemBuilder: (context, index) {
                              final isSelected =
                                  index == widget.selectedTime.minute;
                              return Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: isSelected ? 42 : 28,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AntizombiTheme.textPrimary
                                        : AntizombiTheme.textMuted,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
