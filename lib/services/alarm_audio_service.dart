import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servicio encargado de reproducir el sonido de alarma continuo e insistente
/// con prioridad de canal de Alarma en Android, iOS y macOS.
class AlarmAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _alertPulseTimer;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// Inicializa el contexto de audio de alta prioridad para despertar al usuario.
  Future<void> initialize() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[AUDIO] AudioContext notice: $e');
    }

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
    } catch (_) {}
  }

  /// Inicia la sirena de alarma continua en bucle y pulso auditivo/háptico insistente.
  Future<void> startAlarmSound() async {
    if (_isPlaying) return;
    _isPlaying = true;

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
    } catch (_) {}

    bool playedSuccessfully = false;

    // 1. Intenta reproducir el asset alarm_siren.wav
    try {
      await rootBundle.load('assets/sounds/alarm_siren.wav');
      await _audioPlayer.play(
        AssetSource('sounds/alarm_siren.wav'),
        volume: 1.0,
      );
      playedSuccessfully = true;
      debugPrint('[AUDIO] Reproduciendo sirena desde AssetSource(alarm_siren.wav)');
    } catch (e) {
      debugPrint('[AUDIO] Asset WAV no disponible: $e');
    }

    // 2. Si no cargó el asset WAV, intenta con alarm_siren.mp3
    if (!playedSuccessfully) {
      try {
        await rootBundle.load('assets/sounds/alarm_siren.mp3');
        await _audioPlayer.play(
          AssetSource('sounds/alarm_siren.mp3'),
          volume: 1.0,
        );
        playedSuccessfully = true;
        debugPrint('[AUDIO] Reproduciendo sirena desde AssetSource(alarm_siren.mp3)');
      } catch (_) {}
    }

    // 3. Fallback garantizado para macOS / iOS / Android:
    // Escribe la sirena WAV en el disco temporal y la reproduce mediante DeviceFileSource
    if (!playedSuccessfully) {
      try {
        final Uint8List wavBytes = _generateHighUrgencySirenWav();
        final tempFile = File('${Directory.systemTemp.path}/antizombi_siren.wav');
        await tempFile.writeAsBytes(wavBytes, flush: true);
        await _audioPlayer.play(
          DeviceFileSource(tempFile.path),
          volume: 1.0,
        );
        playedSuccessfully = true;
        debugPrint('[AUDIO] Reproduciendo sirena desde archivo temporal: ${tempFile.path}');
      } catch (e) {
        debugPrint('[AUDIO] Error con archivo temporal: $e');
      }
    }

    // Pulso complementario (Vibración en móvil y sonido de alerta del sistema en macOS)
    _alertPulseTimer?.cancel();
    _alertPulseTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!_isPlaying) return;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  /// Detiene inmediatamente el sonido de la alarma y los pulsos de alerta.
  Future<void> stopAlarmSound() async {
    _isPlaying = false;
    _alertPulseTimer?.cancel();
    _alertPulseTimer = null;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  /// Sintetiza un archivo WAV PCM de 16-bit (2 segundos en bucle continuo)
  /// alternando frecuencias de alarma de alta urgencia (800 Hz y 1200 Hz).
  Uint8List _generateHighUrgencySirenWav() {
    const int sampleRate = 44100;
    const int durationSeconds = 2;
    const int numSamples = sampleRate * durationSeconds;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    const int dataSize = numSamples * numChannels * (bitsPerSample ~/ 8);
    const int totalSize = 36 + dataSize;

    final ByteData buffer = ByteData(44 + dataSize);

    // Cabecera RIFF / WAVE estándar
    _writeAscii(buffer, 0, 'RIFF');
    buffer.setUint32(4, totalSize, Endian.little);
    _writeAscii(buffer, 8, 'WAVE');
    _writeAscii(buffer, 12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little); // Subchunk1Size (PCM = 16)
    buffer.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    buffer.setUint16(22, numChannels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, numChannels * (bitsPerSample ~/ 8), Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    _writeAscii(buffer, 36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    // Síntesis de sirena de alta intensidad
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double cyclePos = (t * 4) % 1.0;
      final bool isHighTone = ((t * 2).floor() % 2) == 0;
      final double freq = isHighTone ? 1200.0 : 800.0;

      double sample = 0.0;
      if (cyclePos < 0.82) {
        final double fundamental = math.sin(2 * math.pi * freq * t);
        final double harmonic = 0.3 * math.sin(2 * math.pi * (freq * 2) * t);
        sample = ((fundamental + harmonic) / 1.3).clamp(-1.0, 1.0);
      }

      final int pcmValue = (sample * 29000).toInt();
      buffer.setInt16(44 + (i * 2), pcmValue, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  void _writeAscii(ByteData data, int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  Future<void> dispose() async {
    await stopAlarmSound();
    await _audioPlayer.dispose();
  }
}
