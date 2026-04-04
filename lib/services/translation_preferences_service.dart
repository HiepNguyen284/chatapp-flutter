import 'package:shared_preferences/shared_preferences.dart';

import '../models/language_option.dart';

class TranslationPreferencesService {
  static const String translationTargetLanguageKey =
      'chat.translation.target_language.v1';
  static const String defaultTargetLanguage = 'vi';

  Future<String> getTargetLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(translationTargetLanguageKey) ?? '').trim();
    return normalizeTargetLanguage(raw);
  }

  Future<void> setTargetLanguage(String languageCode) async {
    final normalized = normalizeTargetLanguage(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(translationTargetLanguageKey, normalized);
  }

  String normalizeTargetLanguage(String languageCode) {
    final normalized = languageCode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return defaultTargetLanguage;
    }

    final match = LanguageOption.findByCode(normalized);
    return match?.code ?? defaultTargetLanguage;
  }
}
