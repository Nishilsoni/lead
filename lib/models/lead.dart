// Lead domain models matching the OceanCRM API schema.

class Lead {
  final String id;
  final DateTime since;
  final String stage;
  final Set<String> tags;
  final String requirements;
  final String notes;
  final int potential;
  final Business business;
  final List<ProductItem> products;
  final SourceItem? source;
  final AssignedUser? assignedUser;
  final Map<String, dynamic> customFields;

  const Lead({
    required this.id,
    required this.since,
    required this.stage,
    required this.tags,
    required this.requirements,
    required this.notes,
    required this.potential,
    required this.business,
    required this.products,
    this.source,
    this.assignedUser,
    this.customFields = const {},
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['id'] ?? '',
      since: DateTime.parse(json['since']),
      stage: json['stage'] ?? '',
      tags: Set<String>.from(json['tags'] ?? []),
      requirements: json['requirements'] ?? '',
      notes: json['notes'] ?? '',
      potential: json['potential'] ?? 0,
      business: Business.fromJson(json['business'] ?? {}),
      products: (json['products'] as List<dynamic>?)
              ?.map((p) => ProductItem.fromJson(p))
              .toList() ??
          [],
      source: json['source'] != null
          ? SourceItem.fromJson(json['source'])
          : null,
      assignedUser: json['assigned_user'] != null
          ? AssignedUser.fromJson(json['assigned_user'])
          : null,
      customFields: json['custom_fields'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Display name: prefer business name, fallback to contact person name.
  String get displayName {
    if (business.business.isNotEmpty) return business.business;
    if (business.name.isNotEmpty) return business.name;
    return 'Unnamed Lead';
  }

  /// Contact person name with optional title.
  String get contactPerson {
    final title = business.title != null ? '${business.title} ' : '';
    return '$title${business.name}'.trim();
  }
}

class Business {
  final String id;
  final String business;
  final String name;
  final String? title;
  final String designation;
  final String mobile;
  final String email;
  final String website;
  final String addressLine1;
  final String addressLine2;
  final String country;
  final String city;
  final String gstin;
  final String code;

  const Business({
    required this.id,
    required this.business,
    required this.name,
    this.title,
    required this.designation,
    required this.mobile,
    required this.email,
    required this.website,
    required this.addressLine1,
    required this.addressLine2,
    required this.country,
    required this.city,
    required this.gstin,
    required this.code,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] ?? '',
      business: json['business'] ?? '',
      name: json['name'] ?? '',
      title: json['title'],
      designation: json['designation'] ?? '',
      mobile: json['mobile'] ?? '',
      email: json['email'] ?? '',
      website: json['website'] ?? '',
      addressLine1: json['address_line_1'] ?? '',
      addressLine2: json['address_line_2'] ?? '',
      country: json['country'] ?? '',
      city: json['city'] ?? '',
      gstin: json['gstin'] ?? '',
      code: json['code'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'business': business,
        'name': name,
        'title': title,
        'designation': designation,
        'mobile': mobile,
        'email': email,
        'website': website,
        'address_line_1': addressLine1,
        'address_line_2': addressLine2,
        'country': country,
        'city': city,
        'gstin': gstin,
        'code': code,
      };

  /// Full address string.
  String get fullAddress {
    final parts = [addressLine1, addressLine2, city, country]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }
}

class ProductItem {
  final int id;
  final String name;

  const ProductItem({required this.id, required this.name});

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class SourceItem {
  final int id;
  final String name;
  final bool isDefault;

  const SourceItem({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  factory SourceItem.fromJson(Map<String, dynamic> json) {
    return SourceItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      isDefault: json['is_default'] ?? false,
    );
  }
}

class AssignedUser {
  final String id;
  final String name;

  const AssignedUser({required this.id, required this.name});

  factory AssignedUser.fromJson(Map<String, dynamic> json) {
    return AssignedUser(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class LeadStage {
  final String? id;
  final String stage;
  final int order;
  final String? section; // pipeline/section the stage belongs to (rename needs it)

  const LeadStage({this.id, required this.stage, required this.order, this.section});

  factory LeadStage.fromJson(Map<String, dynamic> json) {
    // Try dedicated ID fields first; fall back to order (the integer the API
    // accepts for DELETE /v1/lead/stage/{id}).
    final id = (json['id'] ?? json['stage_id'] ?? json['uuid'] ?? json['order'])
        ?.toString();
    return LeadStage(
      id: id,
      stage: json['stage'] ?? '',
      order: json['order'] ?? 0,
      section: json['section'] ?? json['pipeline'] ?? json['section_name'],
    );
  }

  LeadStage copyWith({String? stage, int? order}) => LeadStage(
        id: id,
        stage: stage ?? this.stage,
        order: order ?? this.order,
        section: section,
      );
}

/// Request model for creating a lead.
class CreateLeadRequest {
  final int? sourceId;
  final DateTime since;
  final List<int> productIds;
  final String? assignedTo;
  final String stage;
  final Set<String> tags;
  final String requirements;
  final String notes;
  final int potential;
  final Map<String, dynamic> business;
  final Map<String, dynamic>? customFields;

  const CreateLeadRequest({
    this.sourceId,
    required this.since,
    required this.productIds,
    this.assignedTo,
    required this.stage,
    required this.tags,
    required this.requirements,
    required this.notes,
    required this.potential,
    required this.business,
    this.customFields,
  });

  Map<String, dynamic> toJson() => {
        if (sourceId != null) 'source_id': sourceId,
        'since': since.toUtc().toIso8601String(),
        'product_ids': productIds,
        if (assignedTo != null) 'assigned_to': assignedTo,
        'stage': stage,
        'tags': tags.toList(),
        'requirements': requirements,
        'notes': notes,
        'potential': potential,
        'business': business,
        if (customFields != null && customFields!.isNotEmpty) 'custom_fields': customFields,
      };
}

/// Request model for updating a lead.
class UpdateLeadRequest {
  final int? sourceId;
  final DateTime since;
  final List<int> productIds;
  final String? assignedTo;
  final String stage;
  final Set<String> tags;
  final String requirements;
  final String notes;
  final int potential;
  final Map<String, dynamic> business;
  final Map<String, dynamic>? customFields;

  const UpdateLeadRequest({
    this.sourceId,
    required this.since,
    required this.productIds,
    this.assignedTo,
    required this.stage,
    required this.tags,
    required this.requirements,
    required this.notes,
    required this.potential,
    required this.business,
    this.customFields,
  });

  Map<String, dynamic> toJson() => {
        if (sourceId != null) 'source_id': sourceId,
        'since': since.toUtc().toIso8601String(),
        'product_ids': productIds,
        if (assignedTo != null) 'assigned_to': assignedTo,
        'stage': stage,
        'tags': tags.toList(),
        'requirements': requirements,
        'notes': notes,
        'potential': potential,
        'business': business,
        if (customFields != null && customFields!.isNotEmpty) 'custom_fields': customFields,
      };
}

/// User detail model (for assignee dropdowns).
class UserDetail {
  final String id;
  final String name;
  final String email;
  final String? mobile;
  final String roleName;

  const UserDetail({
    required this.id,
    required this.name,
    required this.email,
    this.mobile,
    required this.roleName,
  });

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    return UserDetail(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      mobile: json['mobile'],
      roleName: json['role_name'] ?? '',
    );
  }
}
