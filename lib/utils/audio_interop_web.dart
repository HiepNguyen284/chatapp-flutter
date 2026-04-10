// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void playWebRingtone() {
  try {
    js.context.callMethod('playRingtone', ['assets/lib/assets/facebook_call.mp3']);
  } catch (_) {}
}

void stopWebRingtone() {
  try {
    js.context.callMethod('stopRingtone', []);
  } catch (_) {}
}
