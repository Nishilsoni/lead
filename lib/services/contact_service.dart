import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/contact.dart';

class ContactService {
  final ApiClient _client = ApiClient();

  Future<List<Contact>> getContacts(String businessId) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.contacts,
        queryParameters: {'business_id': businessId},
      );
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Contact.fromJson)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Contact> createContact({
    required String businessId,
    String name = '',
    String mobile = '',
    String email = '',
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.contacts,
        data: {
          'business_id': businessId,
          if (name.isNotEmpty) 'name': name,
          if (mobile.isNotEmpty) 'mobile': mobile,
          if (email.isNotEmpty) 'email': email,
        },
      );
      return Contact.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Contact> updateContact({
    required String contactId,
    required String businessId,
    String name = '',
    String mobile = '',
    String email = '',
  }) async {
    try {
      final response = await _client.dio.put(
        ApiConstants.contactById(contactId),
        data: {
          'business_id': businessId,
          if (name.isNotEmpty) 'name': name,
          if (mobile.isNotEmpty) 'mobile': mobile,
          if (email.isNotEmpty) 'email': email,
        },
      );
      return Contact.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await _client.dio.delete(ApiConstants.contactById(contactId));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.statusCode == 401) return 'Session expired. Please log in again.';
    if (e.response?.statusCode == 404) return 'Contact not found.';
    if (e.response?.statusCode == 422) {
      final data = e.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) return first['msg'].toString();
        }
      }
      return 'Validation error';
    }
    if (e.type == DioExceptionType.connectionError) return 'No internet connection.';
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    return 'Something went wrong';
  }
}
