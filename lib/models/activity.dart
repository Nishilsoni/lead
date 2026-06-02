// Models for Activities (Interactions) and Appointments.

class InteractionUser {
  final String id;
  final String name;

  const InteractionUser({required this.id, required this.name});

  factory InteractionUser.fromJson(Map<String, dynamic> json) =>
      InteractionUser(id: json['id'] ?? '', name: json['name'] ?? '');
}

class InteractionBusiness {
  final String business;
  final String name;

  const InteractionBusiness({required this.business, required this.name});

  factory InteractionBusiness.fromJson(Map<String, dynamic> json) =>
      InteractionBusiness(
        business: json['business'] ?? '',
        name: json['name'] ?? '',
      );
}

class Interaction {
  final String id;
  final String note;
  final String interactionType;
  final DateTime interactedAt;
  final InteractionUser interactedByUser;
  final InteractionBusiness business;

  const Interaction({
    required this.id,
    required this.note,
    required this.interactionType,
    required this.interactedAt,
    required this.interactedByUser,
    required this.business,
  });

  factory Interaction.fromJson(Map<String, dynamic> json) => Interaction(
        id: json['id'] ?? '',
        note: json['note'] ?? '',
        interactionType: json['interaction_type'] ?? '',
        interactedAt: DateTime.tryParse(json['interacted_at'] ?? '') ?? DateTime.now(),
        interactedByUser: InteractionUser.fromJson(json['interacted_by_user'] ?? {}),
        business: InteractionBusiness.fromJson(json['business'] ?? {}),
      );

  Map<String, dynamic> toCreateJson({required String leadId}) => {
        'lead_id': leadId,
        'note': note,
        'interaction_type': interactionType,
        'interacted_at': interactedAt.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────

class AppointmentUser {
  final String id;
  final String name;

  const AppointmentUser({required this.id, required this.name});

  factory AppointmentUser.fromJson(Map<String, dynamic> json) =>
      AppointmentUser(id: json['id'] ?? '', name: json['name'] ?? '');
}

class AppointmentBusiness {
  final String business;
  final String name;

  const AppointmentBusiness({required this.business, required this.name});

  factory AppointmentBusiness.fromJson(Map<String, dynamic> json) =>
      AppointmentBusiness(
        business: json['business'] ?? '',
        name: json['name'] ?? '',
      );
}

class Appointment {
  final String id;
  final String note;
  final String appointmentType;
  final DateTime scheduledAt;
  final AppointmentUser assignedUser;
  final AppointmentBusiness business;
  final String status;
  final String leadId;

  const Appointment({
    required this.id,
    required this.note,
    required this.appointmentType,
    required this.scheduledAt,
    required this.assignedUser,
    required this.business,
    required this.status,
    required this.leadId,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] ?? '',
        note: json['note'] ?? '',
        appointmentType: json['appointment_type'] ?? '',
        scheduledAt: DateTime.tryParse(json['scheduled_at'] ?? '') ?? DateTime.now(),
        assignedUser: AppointmentUser.fromJson(json['assigned_user'] ?? {}),
        business: AppointmentBusiness.fromJson(json['business'] ?? {}),
        status: json['status'] ?? 'SCHEDULED',
        leadId: json['lead_id'] ?? '',
      );

  bool get isScheduled => status == 'SCHEDULED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
}

const List<String> activityTypes = ['Call', 'Meeting', 'Online', 'Email', 'Message', 'Other'];
