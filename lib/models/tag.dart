// Tag domain models matching the OceanCRM API schema.
//
// A Tag is a simple labelled entity (`{ id, name }`) owned by the org. Leads
// reference tags by *name* (see Lead.tags), so usage counts are derived by
// matching a tag's name against the tags stored on each lead.

class Tag {
  final int id;
  final String name;

  const Tag({required this.id, required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is Tag && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// A tag paired with its computed usage across the org's leads.
///
/// [leadCount] is how many leads carry this tag, and [percentage] is that
/// count relative to the most-used tag (0–100) — mirroring the web bar chart.
class TagUsage {
  final Tag tag;
  final int leadCount;
  final double percentage;

  const TagUsage({
    required this.tag,
    required this.leadCount,
    required this.percentage,
  });

  bool get inUse => leadCount > 0;
}
