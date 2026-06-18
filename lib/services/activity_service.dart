import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/activity.dart';

/// Service layer for Interactions (Activities) and Appointments.
class ActivityService {
  final ApiClient _client = ApiClient();

  // ── Interactions (Activities) ────────────────────────────────────

  Future<List<Interaction>> getInteractions({String? leadId}) async {
    try {
      final params = <String, dynamic>{};
      if (leadId != null) params['lead_id'] = leadId;
      // Default to last 90 days
      params['since'] = DateTime.now().subtract(const Duration(days: 90)).toUtc().toIso8601String();

      final response = await _client.dio.get(
        ApiConstants.interactions,
        queryParameters: params,
      );

      final data = response.data;
      if (data is List) {
        return data.map((e) => Interaction.fromJson(e)).toList();
      }
      // Could be wrapped in a pagination object
      if (data is Map && data['items'] != null) {
        return (data['items'] as List).map((e) => Interaction.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Interaction> createInteraction({
    required String leadId,
    required String note,
    required String interactionType,
    required DateTime interactedAt,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.interactions,
        data: {
          'lead_id': leadId,
          'note': note,
          'interaction_type': interactionType,
          'interacted_at': interactedAt.toUtc().toIso8601String(),
        },
      );
      // Parse if the response is a valid map; otherwise return a stub so
      // callers that don't use the return value (e.g. call-log dialog) succeed.
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return Interaction.fromJson(data);
      }
      return Interaction(
        id: '',
        note: note,
        interactionType: interactionType,
        interactedAt: interactedAt,
        interactedByUser: const InteractionUser(id: '', name: ''),
        business: const InteractionBusiness(business: '', name: ''),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw 'Failed to save interaction';
    }
  }

  // ── Appointments ─────────────────────────────────────────────────

  Future<List<Appointment>> getAppointments({String? leadId, DateTime? since, DateTime? until}) async {
    try {
      final params = <String, dynamic>{};
      if (leadId != null) params['lead_id'] = leadId;
      
      params['since'] = (since ?? DateTime.now().subtract(const Duration(days: 90))).toUtc().toIso8601String();
      if (until != null) {
        params['until'] = until.toUtc().toIso8601String();
      }

      final response = await _client.dio.get(
        ApiConstants.appointments,
        queryParameters: params,
      );

      final data = response.data;
      if (data is List) {
        return data.map((e) => Appointment.fromJson(e)).toList();
      }
      if (data is Map && data['items'] != null) {
        return (data['items'] as List).map((e) => Appointment.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Appointment> createAppointment({
    required String leadId,
    required String note,
    required String appointmentType,
    required DateTime scheduledAt,
    required String assignedTo,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.appointments,
        data: {
          'lead_id': leadId,
          'note': note,
          'appointment_type': appointmentType,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'assigned_to': assignedTo,
        },
      );
      return Appointment.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Appointment> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    required String note,
    required String appointmentType,
    required DateTime scheduledAt,
    required String assignedTo,
  }) async {
    try {
      final response = await _client.dio.put(
        ApiConstants.appointmentById(appointmentId),
        data: {
          'status': status,
          'note': note,
          'appointment_type': appointmentType,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'assigned_to': assignedTo,
        },
      );
      return Appointment.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    final detail = e.response?.data?['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) return detail.first['msg'] ?? 'Error';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }
    return 'Something went wrong';
  }
}
