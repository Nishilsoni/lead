import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/tag.dart';
import '../services/tag_service.dart';

/// Manages the org's tag list and CRUD state.
///
/// This is the single source of truth for the available tags used across:
///  • the Manage Tags screen,
///  • the tag selector in the create/edit Lead form, and
///  • the tag filter in the Leads list/board.
///
/// Usage statistics (how many leads carry each tag) are derived on demand from
/// a supplied list of leads via [usageFrom], since the API stores tags on leads
/// as plain name strings.
class TagProvider extends ChangeNotifier {
  final TagService _service = TagService();

  List<Tag> _tags = [];
  bool _isLoading = false;
  bool _loadedOnce = false;
  bool _isSaving = false;
  String? _error;

  List<Tag> get tags => _tags;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;

  /// Distinct tag names, sorted — convenient for chip selectors/filters.
  List<String> get tagNames =>
      _tags.map((t) => t.name).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  /// Load all tags. No-op once loaded unless [refresh] is true.
  Future<void> loadTags({bool refresh = false}) async {
    if (_isLoading) return;
    if (_loadedOnce && !refresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tags = await _service.getAllTags();
      _loadedOnce = true;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create a tag and insert it into the local list. Returns the created tag.
  Future<Tag> createTag(String name) async {
    _isSaving = true;
    notifyListeners();
    try {
      final created = await _service.createTag(name);
      if (!_tags.any((t) => t.id == created.id || t.name == created.name)) {
        _tags = [..._tags, created];
      }
      return created;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Ensure a tag with [name] exists, creating it if needed. Used by the lead
  /// form so a freshly typed tag becomes a real org tag (and shows everywhere).
  /// Never throws — a duplicate or failed create just returns silently.
  Future<void> ensureTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_tags.any((t) => t.name.toLowerCase() == trimmed.toLowerCase())) return;
    try {
      await createTag(trimmed);
    } catch (_) {
      // Already exists or transient failure — ignore; the lead still saves the
      // tag string, and the next refresh will reconcile the list.
    }
  }

  /// Rename a tag and update the local list.
  Future<Tag> updateTag(int id, String name) async {
    _isSaving = true;
    notifyListeners();
    try {
      final updated = await _service.updateTag(id, name);
      _tags = _tags.map((t) => t.id == id ? updated : t).toList();
      return updated;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Delete a tag and remove it from the local list.
  Future<void> deleteTag(int id) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _service.deleteTag(id);
      _tags = _tags.where((t) => t.id != id).toList();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Clear cached tags (e.g. on org switch / logout).
  void clearCache() {
    _tags = [];
    _loadedOnce = false;
    _error = null;
    notifyListeners();
  }

  /// Build per-tag usage stats from a list of [leads].
  ///
  /// [leadCount] counts leads whose tag-name set contains the tag, and
  /// [percentage] is that count relative to the most-used tag (0–100), matching
  /// the relative bars shown on the web. Sorted by lead count, descending.
  List<TagUsage> usageFrom(List<Lead> leads) {
    final counts = <String, int>{for (final t in _tags) t.name: 0};
    for (final lead in leads) {
      for (final name in lead.tags) {
        if (counts.containsKey(name)) counts[name] = counts[name]! + 1;
      }
    }
    final maxCount = counts.values.isEmpty
        ? 0
        : counts.values.reduce((a, b) => a > b ? a : b);

    final usage = _tags
        .map((t) {
          final c = counts[t.name] ?? 0;
          return TagUsage(
            tag: t,
            leadCount: c,
            percentage: maxCount == 0 ? 0 : (c / maxCount) * 100,
          );
        })
        .toList()
      ..sort((a, b) {
        final byCount = b.leadCount.compareTo(a.leadCount);
        return byCount != 0
            ? byCount
            : a.tag.name.toLowerCase().compareTo(b.tag.name.toLowerCase());
      });
    return usage;
  }
}
