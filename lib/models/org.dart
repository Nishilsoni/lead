class Org {
  final String id;
  final String name;

  const Org({required this.id, required this.name});

  factory Org.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    // Try every common field name the API might use for the org display name
    final name = (json['name'] ??
            json['org_name'] ??
            json['organization_name'] ??
            json['business'] ??
            json['business_name'] ??
            json['title'] ??
            '')
        .toString()
        .trim();
    return Org(id: id, name: name.isEmpty ? id : name);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
