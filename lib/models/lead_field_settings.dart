class CustomField {
  final String key;
  final String label;
  final String fieldType; // "text", "number", "date", "select", "checkbox"
  final bool isRequired;
  final List<String>? options; // for select fields

  CustomField({
    required this.key,
    required this.label,
    required this.fieldType,
    required this.isRequired,
    this.options,
  });

  factory CustomField.fromJson(Map<String, dynamic> json) => CustomField(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        fieldType: json['field_type'] as String? ?? 'text',
        isRequired: json['is_required'] as bool? ?? false,
        options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      );
}

class LeadFieldSettings {
  final List<CustomField> customFields;

  LeadFieldSettings({required this.customFields});

  factory LeadFieldSettings.fromJson(Map<String, dynamic> json) {
    final allFields = (json['fields'] as List<dynamic>?) ?? [];
    final parsedCustomFields = allFields
        .where((e) => e['type'] == 'custom' && e['is_enabled'] == true)
        .map((e) => CustomField.fromJson(e as Map<String, dynamic>))
        .toList();
    return LeadFieldSettings(customFields: parsedCustomFields);
  }
}
