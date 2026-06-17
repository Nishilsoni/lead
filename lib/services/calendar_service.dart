import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/calendar_event.dart';

/// Aggregates appointments (/v1/appointment) and interactions
/// (/v1/interaction) into a single list of [CalendarEvent]s for a date
/// range. Both endpoints are org-scoped via the x-org-id header that the
/// ApiClient interceptor injects, so this works for test and prod alike.
class CalendarService {
  final ApiClient _client = ApiClient();

  Future<List<CalendarEvent>> getEvents({
    required DateTime since,
    required DateTime until,
  }) async {
    final sinceIso = since.toUtc().toIso8601String();
    final untilIso = until.toUtc().toIso8601String();

    final results = await Future.wait([
      _fetchAppointments(sinceIso, untilIso),
      _fetchInteractions(sinceIso, untilIso),
    ]);

    final events = <CalendarEvent>[...results[0], ...results[1]];
    events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return events;
  }

  Future<List<CalendarEvent>> _fetchAppointments(
      String since, String until) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.appointments,
        queryParameters: {'since': since, 'until': until},
      );
      return _extractList(response.data)
          .map((e) => CalendarEvent.fromAppointment(e))
          .toList();
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[CalendarService] appointments error: ${e.response?.data}');
      }
      return [];
    }
  }

  Future<List<CalendarEvent>> _fetchInteractions(
      String since, String until) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.interactions,
        queryParameters: {'since': since, 'until': until},
      );
      return _extractList(response.data)
          .map((e) => CalendarEvent.fromInteraction(e))
          .toList();
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[CalendarService] interactions error: ${e.response?.data}');
      }
      return [];
    }
  }

  /// Both endpoints may return a bare list or a paginated {items:[...]}.
  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }
}
