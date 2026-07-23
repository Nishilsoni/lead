// A member of the organization, as shown in the Users administration list.
// Matches UserDetailSchema: { id, name, email, mobile?, role_name }.

import 'package:flutter/foundation.dart';

@immutable
class AdminUser {
  final String id;
  final String name;
  final String email;
  final String? mobile;
  final String roleName;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.roleName,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString(),
      roleName: json['role_name']?.toString() ?? '',
    );
  }

  bool get isAdmin => roleName.toUpperCase() == 'ADMIN';

  /// First initial for the avatar circle.
  String get initial =>
      name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
}
