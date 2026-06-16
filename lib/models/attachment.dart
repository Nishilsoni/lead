import 'package:flutter/material.dart';

class AttachmentUser {
  final String id;
  final String name;

  const AttachmentUser({required this.id, required this.name});

  factory AttachmentUser.fromJson(Map<String, dynamic> json) =>
      AttachmentUser(id: json['id'] ?? '', name: json['name'] ?? '');
}

class LeadAttachment {
  final String id;
  final String leadId;
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final String contentType;
  final DateTime createdAt;
  final AttachmentUser? uploadedByUser;

  const LeadAttachment({
    required this.id,
    required this.leadId,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.contentType,
    required this.createdAt,
    this.uploadedByUser,
  });

  factory LeadAttachment.fromJson(Map<String, dynamic> json) {
    // Flexible user parsing — handle both field name variants
    AttachmentUser? user;
    final rawUser = json['uploaded_by_user'] ?? json['user'] ?? json['created_by'];
    if (rawUser is Map<String, dynamic>) {
      user = AttachmentUser.fromJson(rawUser);
    }

    return LeadAttachment(
      id: json['id'] ?? '',
      leadId: json['lead_id'] ?? '',
      fileName: json['file_name'] ?? json['filename'] ?? json['name'] ?? 'Unknown',
      fileUrl: json['file_url'] ?? json['url'] ?? json['download_url'] ?? '',
      fileSize: _parseInt(json['file_size'] ?? json['size'] ?? 0),
      contentType: json['content_type'] ?? json['mime_type'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      uploadedByUser: user,
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String get fileSizeFormatted {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get extension => fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';

  bool get isImage =>
      ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(extension) ||
      contentType.startsWith('image/');

  bool get isPdf =>
      extension == 'pdf' || contentType.contains('pdf');

  bool get isDoc =>
      ['doc', 'docx'].contains(extension) || contentType.contains('word');

  bool get isSheet =>
      ['xls', 'xlsx'].contains(extension) || contentType.contains('spreadsheet') || contentType.contains('excel');

  IconData get icon {
    if (isImage) return Icons.image_rounded;
    if (isPdf) return Icons.picture_as_pdf_rounded;
    if (isDoc) return Icons.description_rounded;
    if (isSheet) return Icons.table_chart_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color get iconColor {
    if (isImage) return const Color(0xFF8B5CF6);
    if (isPdf) return const Color(0xFFEF4444);
    if (isDoc) return const Color(0xFF3B82F6);
    if (isSheet) return const Color(0xFF10B981);
    return const Color(0xFF6B7280);
  }
}
