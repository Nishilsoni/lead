import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneCallHelper {
  static const MethodChannel _channel = MethodChannel('lead/phone_call');

  static Future<bool> call(String phone) async {
    final normalizedPhone = _normalizePhone(phone);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _channel.invokeMethod<bool>('callPhone', {
          'phone': normalizedPhone,
        });
        return result ?? true;
      } on PlatformException {
        return false;
      } on MissingPluginException {
        // Fall through to the generic launcher on non-Android builds or if the
        // native bridge is unavailable.
      }
    }

    final uri = Uri(scheme: 'tel', path: normalizedPhone);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\s+'), '');
  }
}
