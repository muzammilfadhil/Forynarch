import 'dart:async';
import 'package:dbus/dbus.dart';
import '../../packages/audio_service_mpris/lib/mpris.dart';

void check(bool ok, String message) {
  if (!ok) throw StateError(message);
}

Future<void> main() async {
  final host = DBusClient.session();
  final reader = DBusClient.session();
  final player = OrgMprisMediaPlayer2(identity: 'Mudil clock fixture', path: DBusObjectPath('/org/mpris/MediaPlayer2'));
  const name = 'org.mpris.MediaPlayer2.forynarch_clock';
  await host.requestName(name);
  await host.registerObject(player);
  final remote = DBusRemoteObject(reader, name: name, path: player.path);
  var seeks = 0;
  final signal = DBusRemoteObjectSignalStream(object: remote, interface: 'org.mpris.MediaPlayer2.Player', name: 'Seeked').listen((_) { seeks++; });
  Future<int> position() async => (await remote.getProperty('org.mpris.MediaPlayer2.Player', 'Position') as DBusInt64).value;
  try {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    player.position = const Duration(seconds: 5);
    player.playbackState = 'Playing';
    final before = await position();
    final elapsed = Stopwatch()..start();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final after = await position();
    check(after - before >= elapsed.elapsedMicroseconds * 0.8 && after - before <= elapsed.elapsedMicroseconds * 1.3 + 300000, 'Position did not advance over real D-Bus');
    player.playbackState = 'Paused';
    final paused = await position();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    check((await position()) == paused, 'Paused position drifted');
    player.position = const Duration(seconds: 81);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    check(await position() == 81000000 && seeks >= 2, 'Seek did not update Position and emit Seeked');
    player.rate = 2;
    player.playbackState = 'Playing';
    final fast = await position();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    check((await position()) - fast >= 420000, 'Rate was ignored');
    player.playbackState = 'Paused';
    player.position = Duration.zero;
    check(await position() == 0, 'Track reset retained old position');
    print('PASS real D-Bus position, pause, seek signal, 2x rate and track reset');
  } finally {
    await signal.cancel();
    await reader.close();
    await host.close();
  }
}
