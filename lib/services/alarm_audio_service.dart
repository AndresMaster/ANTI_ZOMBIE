import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Servicio encargado de reproducir el sonido de alarma continuo e insistente
/// con prioridad de canal de Alarma en Android e iOS.
class AlarmAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _hapticTimer;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// Inicializa el contexto de audio de alta prioridad para despertar al usuario.
  Future<void> initialize() async {
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
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setVolume(1.0);
  }

  /// Inicia la sirena de alarma continua en bucle y vibración háptica insistente.
  /// Si existe `assets/sounds/alarm_siren.mp3` lo reproduce; de lo contrario,
  /// sintetiza en memoria una sirena bitonal WAV de alta intensidad (880Hz / 1320Hz)
  /// para garantizar que la alarma suene siempre sin fallar por falta de archivos.
  Future<void> startAlarmSound() async {
    if (_isPlaying) return;
    _isPlaying = true;

    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setVolume(1.0);

    try {
      // Verifica si el asset personalizado existe en el bundle
      await rootBundle.load('assets/sounds/alarm_siren.mp3');
      await _audioPlayer.play(
        AssetSource('sounds/alarm_siren.mp3'),
        volume: 1.0,
      );
    } catch (_) {
      // Fallback garantizado: genera sirena WAV bitonal de alta urgencia en memoria
      final Uint8List wavBytes = _generateHighUrgencySirenWav();
      await _audioPlayer.play(
        BytesSource(wavBytes, mimeType: 'audio/wav'),
        volume: 1.0,
      );
    }

    // Pulso háptico adicional cada 800 ms mientras suena la alarma
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      HapticFeedback.vibrate();
    });
  }

  /// Detiene inmediatamente el sonido de la alarma y las vibraciones.
  Future<void> stopAlarmSound() async {
    _isPlaying = false;
    _hapticTimer?.cancel();
    _hapticTimer = null;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  /// Sintetiza un archivo WAV PCM de 16-bit (2 segundos en bucle continuo)
  /// alternando frecuencias de alarma (880 Hz y 1320 Hz con armónicos).
  Uint8List _generateHighUrgencySirenWav() {
    const int sampleRate = 22050;
    const int durationSeconds = 2;
    const int numSamples = sampleRate * durationSeconds;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    const int dataSize = numSamples * numChannels * (bitsPerSample ~/ 8);
    const int totalSize = 36 + dataSize;

    final ByteData buffer = ByteData(44 + dataSize);

    // Cabecera RIFF / WAVE
    _writeAscii(buffer, 0, 'RIFF');
    buffer.setUint32(4, totalSize, Endian.little);
    _writeAscii(buffer, 8, 'WAVE');
    _writeAscii(buffer, 12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little); // Subchunk1Size (PCM)
    buffer.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    buffer.setUint16(22, numChannels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, numChannels * (bitsPerSample ~/ 8), Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    _writeAscii(buffer, 36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    // Síntesis de onda cuadrada suavizada bitonal (patrón de alarma despertador)
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      // Alterna cada 0.25s entre 960 Hz y 1440 Hz, con breve silencio en el último 10%
      final double cyclePos = (t * 4) % 1.0;
      final bool isHighTone = ((t * 2).floor() % 2) == 0;
      final double freq = isHighTone ? 1320.0 : 920.0;

      double sample = 0.0;
      if (cyclePos < 0.85) {
        final double fundamental = math.sin(2 * math.pi * freq * t);
        final double harmonic = 0.35 * math.sin(2 * math.pi * (freq * 2) * t);
        sample = ((fundamental + harmonic) / 1.35).clamp(-1.0, 1.0);
      }

      final int pcmValue = (sample * 28000).toInt();
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
