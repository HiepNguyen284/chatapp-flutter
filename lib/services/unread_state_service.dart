import 'package:shared_preferences/shared_preferences.dart';

class UnreadStateService {
  static const String _prefix = 'room_last_read_at_';

  Future<DateTime?> getLastReadAt(int roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$roomId');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  Future<void> setLastReadAt(int roomId, DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$roomId', value.toUtc().toIso8601String());
  }
}
