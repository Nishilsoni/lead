class Contact {
  final String id;
  final String name;
  final String mobile;
  final String email;

  const Contact({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  Contact copyWith({String? name, String? mobile, String? email}) {
    return Contact(
      id: id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
