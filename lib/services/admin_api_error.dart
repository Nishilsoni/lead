import 'dart:convert';
import 'package:dio/dio.dart';

/// Shared Dio error → friendly message translation for the administration
/// services (users, roles, permissions). Mirrors the handling in
/// [TagService] so error copy stays consistent across the app.
mixin AdminApiError {
  String humanizeError(DioException e, {String subject = 'item'}) {
    final status = e.response?.statusCode;
    final detail = _detailOf(e.response?.data);

    switch (status) {
      case 401:
        return 'Session expired. Please log in again.';
      case 403:
        return 'You don\'t have permission to do that.';
      case 404:
        return '${_cap(subject)} not found.';
      case 409:
        return detail?.toString() ?? 'That $subject already exists.';
      case 422:
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
        }
        return 'Please check the details and try again.';
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Connection timed out. Please check your internet.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }
    return detail?.toString() ?? 'Something went wrong. Please try again.';
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  dynamic _detailOf(dynamic data) {
    try {
      if (data is Map) return data['detail'];
      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded['detail'];
      }
    } catch (_) {
      // not JSON — ignore
    }
    return null;
  }
}
