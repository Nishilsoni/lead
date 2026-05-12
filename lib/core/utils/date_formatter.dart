import 'package:intl/intl.dart';

/// Utility class for consistent date formatting across the app.
class DateFormatter {
  DateFormatter._();

  static final DateFormat _shortDate = DateFormat('MMM d, yyyy');
  static final DateFormat _fullDate = DateFormat('MMMM d, yyyy');
  static final DateFormat _apiDate = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  /// "Jan 15, 2026"
  static String short(DateTime date) => _shortDate.format(date);

  /// "January 15, 2026"
  static String full(DateTime date) => _fullDate.format(date);

  /// Relative time: "2 days ago", "Just now", etc.
  static String relative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return short(date);
  }

  /// Format for API submission
  static String toApi(DateTime date) {
    return _apiDate.format(date.toUtc());
  }

  /// Parse from API response
  static DateTime fromApi(String dateStr) {
    return DateTime.parse(dateStr);
  }
}
