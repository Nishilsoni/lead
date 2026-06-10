import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';

class ParsedLeadData {
  final String? businessName;
  final String? contactName;
  final String? title;
  final String? mobile;
  final String? email;
  final String? designation;
  final String? website;
  final String? addressLine1;
  final String? city;
  final String? requirements;
  final String? notes;
  final int? potential;

  const ParsedLeadData({
    this.businessName,
    this.contactName,
    this.title,
    this.mobile,
    this.email,
    this.designation,
    this.website,
    this.addressLine1,
    this.city,
    this.requirements,
    this.notes,
    this.potential,
  });

  // Reads a string from json, returns null if missing or blank
  static String? _str(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  // Tries keys in order, returns first non-null non-blank
  static String? _pick(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = _str(json, k);
      if (v != null) return v;
    }
    return null;
  }

  factory ParsedLeadData.fromJson(Map<String, dynamic> json) {
    // Actual API response keys (verified from live response):
    // business_name, contact_person, title, mobile, email, designation,
    // website, address, city, requirement, potential, notes

    int? potential;
    final potRaw = json['potential'];
    if (potRaw is int) {
      potential = potRaw;
    } else if (potRaw is double) {
      potential = potRaw.toInt();
    } else if (potRaw != null) {
      potential = int.tryParse(potRaw.toString());
    }

    final parsed = ParsedLeadData(
      businessName: _pick(json, ['business_name', 'business', 'company']),
      contactName: _pick(json, ['contact_person', 'name', 'contact_name', 'contact']),
      title: _str(json, 'title'),
      mobile: _pick(json, ['mobile', 'phone']),
      email: _str(json, 'email'),
      designation: _str(json, 'designation'),
      website: _str(json, 'website'),
      addressLine1: _pick(json, ['address_line_1', 'address']),
      city: _str(json, 'city'),
      requirements: _pick(json, ['requirement', 'requirements']),
      notes: _pick(json, ['notes', 'note']),
      potential: potential,
    );

    if (kDebugMode) {
      debugPrint('[ParsedLeadData] businessName:    ${parsed.businessName}');
      debugPrint('[ParsedLeadData] contactName:     ${parsed.contactName}');
      debugPrint('[ParsedLeadData] mobile:          ${parsed.mobile}');
      debugPrint('[ParsedLeadData] email:           ${parsed.email}');
      debugPrint('[ParsedLeadData] city:            ${parsed.city}');
      debugPrint('[ParsedLeadData] requirements:    ${parsed.requirements}');
      debugPrint('[ParsedLeadData] notes:           ${parsed.notes}');
      debugPrint('[ParsedLeadData] potential:       ${parsed.potential}');
    }

    return parsed;
  }
}

class AiService {
  final ApiClient _client = ApiClient();

  Future<ParsedLeadData> parseLead(String text) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.aiParseLead,
        data: {'text': text},
      );
      if (kDebugMode) debugPrint('[AiService] raw response: ${response.data}');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ParsedLeadData.fromJson(data);
      }
      throw Exception('Unexpected response format from AI');
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[AiService] error: ${e.response?.data}');
      final msg = e.response?.data?['detail']?.toString() ?? 'AI parse failed';
      throw Exception(msg);
    }
  }
}
