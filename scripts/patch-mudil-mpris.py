#!/usr/bin/env python3
"""Vendor the 0.2.1 MPRIS bridge with a monotonic clock and seek notifications."""
from pathlib import Path
import argparse
import shutil


def replace_once(path, old, new):
    text = path.read_text()
    if new in text:
        return
    if text.count(old) != 1:
        raise ValueError('Unexpected upstream MPRIS source: ' + str(path))
    path.write_text(text.replace(old, new, 1))


def patch(app, source):
    destination = app/'packages/audio_service_mpris'
    if not destination.exists():
        shutil.copytree(source, destination, ignore=shutil.ignore_patterns('.dart_tool', 'build', 'example', '.git'))
    path = destination/'lib/mpris.dart'
    replace_once(path, '  var position = const Duration(seconds: 0);', '''  Duration _position = Duration.zero;
  final Stopwatch _positionClock = Stopwatch();
  double _rate = 1.0;
  Duration get position => _position + Duration(
      microseconds: (_positionClock.elapsedMicroseconds * _rate).round());
  set position(Duration value) {
    final jump = (value - position).inMilliseconds.abs() >= 250;
    _position = value < Duration.zero ? Duration.zero : value;
    _positionClock.reset();
    if (_playbackState == 'Playing') _positionClock.start();
    if (jump) emitSeeked(_position);
  }
  double get rate => _rate;
  set rate(double value) {
    if (!value.isFinite || value <= 0 || value == _rate) return;
    _position = position;
    _positionClock.reset();
    _rate = value;
    emitPropertiesChanged('org.mpris.MediaPlayer2.Player',
        changedProperties: {'Rate': DBusDouble(value)});
  }''')
    replace_once(path, "    _playbackState = state;", '''    _position = position;
    _positionClock.reset();
    if (state == 'Playing') {
      _positionClock.start();
    } else {
      _positionClock.stop();
    }
    _playbackState = state;''')
    replace_once(path, '  DBusDouble getRate() {\n    return const DBusDouble(1.0);', '  DBusDouble getRate() {\n    return DBusDouble(_rate);')
    bridge = destination/'lib/audio_service_mpris.dart'
    replace_once(bridge, '''    _mpris.position = request.state.updatePosition;
    _isPlaying = request.state.playing;
    _mpris.playbackState = _isPlaying ? 'Playing' : 'Paused';''', '''    final state = request.state;
    _isPlaying = state.playing && state.processingState == AudioProcessingStateMessage.ready;
    final delta = DateTime.now().difference(state.updateTime);
    _mpris.position = state.updatePosition + (_isPlaying && !delta.isNegative
        ? Duration(microseconds: (delta.inMicroseconds * state.speed).round())
        : Duration.zero);
    _mpris.rate = state.speed;
    _mpris.playbackState = state.processingState == AudioProcessingStateMessage.idle ||
        state.processingState == AudioProcessingStateMessage.completed
        ? 'Stopped' : _isPlaying ? 'Playing' : 'Paused';''')
    spec = app/'pubspec.yaml'
    text = spec.read_text()
    override = '\n  audio_service_mpris:\n    path: packages/audio_service_mpris\n'
    if 'path: packages/audio_service_mpris' not in text:
        text = text.replace('dependency_overrides:', 'dependency_overrides:' + override) if 'dependency_overrides:' in text else text + '\ndependency_overrides:' + override
        spec.write_text(text)
    (destination/'FORYNARCH.md').write_text('Forynarch integration patch for audio_service_mpris 0.2.1.\n'
        'Adds a monotonic, rate-aware position clock, seek notifications and buffering-aware playback state.\n'
        'Original upstream license is retained. No background timer or network request is added.\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    patch(args.app.resolve(), args.source.resolve())
