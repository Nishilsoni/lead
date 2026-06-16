import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/attachment.dart';

class AttachmentService {
  final ApiClient _client = ApiClient();

  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxFiles = 5;

  // ── List ──────────────────────────────────────────────────────────
  // Attachments are embedded inside the lead detail response — there is
  // no standalone GET /v1/lead/{id}/attachments endpoint (returns 405).

  Future<List<LeadAttachment>> getAttachments({required String leadId}) async {
    try {
      final response =
          await _client.dio.get(ApiConstants.leadById(leadId));
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final raw = data['attachments'];
        if (raw is List) {
          return raw
              .map((e) => LeadAttachment.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Upload ────────────────────────────────────────────────────────
  // POST /v1/lead/{leadId}/attachments  — multipart, field name: "file"
  // lead_id is in the URL path, NOT in the form body.

  Future<LeadAttachment> uploadAttachment({
    required String leadId,
    required PlatformFile file,
  }) async {
    if (file.size > maxFileSizeBytes) {
      throw 'File is too large. Maximum size is 10 MB.';
    }

    try {
      final MultipartFile multipart;
      if (file.bytes != null) {
        multipart = MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        );
      } else if (file.path != null) {
        multipart = await MultipartFile.fromFile(
          file.path!,
          filename: file.name,
        );
      } else {
        throw 'Could not read the selected file.';
      }

      final formData = FormData.fromMap({'file': multipart});

      final response = await _client.dio.post(
        ApiConstants.leadAttachments(leadId),
        data: formData,
      );
      return LeadAttachment.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────
  // DELETE /v1/lead/{leadId}/attachments/{attachmentId}

  Future<void> deleteAttachment({
    required String leadId,
    required String attachmentId,
  }) async {
    try {
      await _client.dio
          .delete(ApiConstants.leadAttachmentById(leadId, attachmentId));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Error helper ─────────────────────────────────────────────────

  String _handleError(DioException e) {
    final detail = e.response?.data?['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      return detail.first['msg'] ?? 'Error';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }
    return 'Something went wrong';
  }
}
