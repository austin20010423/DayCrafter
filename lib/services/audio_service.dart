import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String path =
            '${appDocDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig(); // Default config (m4a on iOS/macOS)

        await _audioRecorder.start(config, path: path);
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();

      return path;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }

  void dispose() {
    _audioRecorder.dispose();
  }

  Stream<Amplitude> getAmplitudeStream() {
    return _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100));
  }
}
