import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('AudioContext')
extension type _AC._(JSObject _) implements JSObject {
  external factory _AC();
  external double get currentTime;
  external _ADest get destination;
  external _Osc createOscillator();
  external _Gain createGain();
  external String get state;
  external JSPromise<JSAny?> resume();
}

extension type _ADest._(JSObject _) implements JSObject {}

extension type _Osc._(JSObject _) implements JSObject {
  external void connect(_Gain dest);
  external void start(double when);
  external void stop(double when);
  external _AP get frequency;
  external set type(String t);
}

extension type _Gain._(JSObject _) implements JSObject {
  external void connect(_ADest dest);
  external _AP get gain;
}

extension type _AP._(JSObject _) implements JSObject {
  external set value(double v);
  external void setValueAtTime(double value, double startTime);
  external void linearRampToValueAtTime(double value, double endTime);
  external void exponentialRampToValueAtTime(double value, double endTime);
}

class SoundService {
  static _AC? _ctx;
  static bool _muted = false;

  static bool get muted => _muted;
  static void toggleMute() => _muted = !_muted;

  static Future<_AC?> _getCtx() async {
    try {
      if (_ctx == null || _ctx!.state == 'closed') {
        _ctx = _AC();
      }
      if (_ctx!.state == 'suspended') {
        await _ctx!.resume().toDart;
      }
      return _ctx;
    } catch (e) {
      debugPrint('[Sound] AudioContext init failed: $e');
      return null;
    }
  }

  static Future<void> _tone({
    required double freq,
    required double dur,
    double vol = 0.25,
    String type = 'sine',
    double delay = 0.0,
    double fadeStart = 0.0,
  }) async {
    if (_muted) return;
    try {
      final ctx = await _getCtx();
      if (ctx == null) return;
      final now = ctx.currentTime + delay;

      final osc = ctx.createOscillator();
      final gn = ctx.createGain();
      osc.connect(gn);
      gn.connect(ctx.destination);

      osc.type = type;
      osc.frequency.setValueAtTime(freq, now);
      gn.gain.setValueAtTime(0.001, now);
      gn.gain.linearRampToValueAtTime(vol, now + 0.01);

      final fadeAt = fadeStart > 0 ? now + fadeStart : now + dur - 0.03;
      gn.gain.setValueAtTime(vol, fadeAt);
      gn.gain.exponentialRampToValueAtTime(0.001, now + dur);

      osc.start(now);
      osc.stop(now + dur + 0.05);
    } catch (e) {
      debugPrint('[Sound] tone error: $e');
    }
  }

  static void playSpinStart() {
    _tone(freq: 180, dur: 0.18, vol: 0.12, type: 'sawtooth');
    _tone(freq: 240, dur: 0.18, vol: 0.08, type: 'square', delay: 0.04);
  }

  static void playReelTick() {
    _tone(freq: 900, dur: 0.025, vol: 0.08, type: 'square');
  }

  static void playHit() {
    _tone(freq: 523, dur: 0.12, vol: 0.28, type: 'sine');
    _tone(freq: 659, dur: 0.18, vol: 0.28, type: 'sine', delay: 0.1);
  }

  static void playJackpot() {
    const notes = [523.0, 659.0, 784.0, 1047.0];
    for (int i = 0; i < notes.length; i++) {
      _tone(freq: notes[i], dur: 0.22, vol: 0.3, type: 'sine', delay: i * 0.13);
    }
  }

  static void playBossJackpot() {
    const notes = [392.0, 523.0, 659.0, 784.0, 1047.0, 1047.0];
    const delays = [0.0, 0.12, 0.24, 0.36, 0.48, 0.66];
    const vols = [0.3, 0.32, 0.34, 0.36, 0.45, 0.5];
    for (int i = 0; i < notes.length; i++) {
      _tone(
        freq: notes[i],
        dur: i == notes.length - 1 ? 0.6 : 0.25,
        vol: vols[i],
        type: 'sine',
        delay: delays[i],
      );
    }
  }
}
