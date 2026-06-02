import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> getInstance() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<bool> setBool(String key, bool value) async {
    final prefs = await getInstance();
    return prefs.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }
}
