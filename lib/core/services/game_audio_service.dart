import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class GameAudioService {
  GameAudioService({AudioPlayer? voicePlayer, AudioPlayer? sfxPlayer})
    : _voicePlayer = voicePlayer ?? AudioPlayer(),
      _sfxPlayer = sfxPlayer ?? AudioPlayer() {
    _voicePlayer.setReleaseMode(ReleaseMode.stop);
    _sfxPlayer.setReleaseMode(ReleaseMode.stop);
  }

  final AudioPlayer _voicePlayer;
  final AudioPlayer _sfxPlayer;

  static const String _dingPath = 'assets/audio/sfx/ding.mp3';
  static const String _oopsPath = 'assets/audio/sfx/oops.mp3';

  Future<void> playWord(String assetPath) {
    return _playAsset(_voicePlayer, assetPath);
  }

  Future<void> playCorrect() {
    return _playAsset(_sfxPlayer, _dingPath);
  }

  Future<void> playWrong() {
    return _playAsset(_sfxPlayer, _oopsPath);
  }

  Future<void> _playAsset(AudioPlayer player, String assetPath) async {
    final String trimmed = assetPath.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final String sourcePath = _toAssetSourcePath(trimmed);
    try {
      await player.stop();
      await player.play(AssetSource(sourcePath), volume: 1.0);
    } on MissingPluginException {
      // Plugin is not available in test or unsupported targets.
    } catch (error) {
      debugPrint('Audio playback failed for "$assetPath": $error');
    }
  }

  String _toAssetSourcePath(String path) {
    if (path.startsWith('assets/')) {
      return path.substring('assets/'.length);
    }
    return path;
  }

  Future<void> dispose() async {
    await _voicePlayer.dispose();
    await _sfxPlayer.dispose();
  }
}
