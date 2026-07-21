import 'package:flutter/material.dart';
import '../utils/shared_prefs.dart';
import '../models/lead_field_settings.dart';
import '../models/lead.dart';
import '../services/lead_service.dart';

/// Manages lead listing, search, filter, pagination, and CRUD states.
class LeadProvider extends ChangeNotifier {
  LeadProvider() {
    _loadShowCustomFields();
  }

  Future<void> _loadShowCustomFields() async {
    final prefs = await SharedPrefs.getInstance();
    _showCustomFields = prefs.getBool('showCustomFields') ?? true;
    notifyListeners();
  }

  Future<void> _saveShowCustomFields() async {
    final prefs = await SharedPrefs.getInstance();
    await prefs.setBool('showCustomFields', _showCustomFields);
  }

  // Existing fields ...
  final LeadService _leadService = LeadService();

  // ── Cache config ─────────────────────────────────────────────────
  static const Duration _cacheDuration = Duration(minutes: 5);
  DateTime? _lastLoadedAt;

  bool _isCacheStale() =>
      _lastLoadedAt == null ||
      DateTime.now().difference(_lastLoadedAt!) >= _cacheDuration;

  // ── Lead List State ──────────────────────────────────────────────
  List<Lead> _leads = [];
  bool _isLoading = false;
  bool _initialLoaded = false; // cache guard: leads fetched at least once
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;

  // ── Search & Filter State ────────────────────────────────────────
  String _searchQuery = '';
  String? _selectedStage;

  // ── Supporting Data ──────────────────────────────────────────────
  List<LeadStage> _stages = [];
  List<ProductItem> _products = [];
  List<SourceItem> _sources = [];
  List<UserDetail> _users = [];
  bool _supportingDataLoaded = false;
  LeadFieldSettings? _leadFieldSettings; // holds custom field definitions
  bool _showCustomFields = true; // Controls global display of custom fields

  /// Toggle the global custom fields visibility.
  void setShowCustomFields(bool value) {
    _showCustomFields = value;
    _saveShowCustomFields();
    notifyListeners();
  }

  // Map to hold custom field values entered by user
  Map<String, dynamic> customFieldValues = {};

  /// Update a single custom field value.
  void updateCustomFieldValue(String id, dynamic value) {
    customFieldValues[id] = value;
    notifyListeners();
  }

  // ── CRUD Operation State ─────────────────────────────────────────
  bool _isSaving = false;
  bool _isDeleting = false;

  // ── Getters ──────────────────────────────────────────────────────
  List<Lead> get leads => _leads;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  int get totalCount => _totalCount;
  bool get hasMore => _currentPage < _totalPages;

  String get searchQuery => _searchQuery;
  String? get selectedStage => _selectedStage;

  List<LeadStage> get stages => _stages;
  List<ProductItem> get products => _products;
  List<SourceItem> get sources => _sources;
  List<UserDetail> get users => _users;
  bool get supportingDataLoaded => _supportingDataLoaded;
  LeadFieldSettings? get leadFieldSettings => _leadFieldSettings;
  bool get showCustomFields => _showCustomFields;

  bool get isSaving => _isSaving;
  bool get isDeleting => _isDeleting;

  // ── Board View State (loads ALL leads for the kanban board) ──────
  List<Lead> _boardLeads = [];
  bool _boardLoading = false;
  String? _boardError;
  bool _boardLoaded = false;

  List<Lead> get boardLeads => _boardLeads;
  bool get boardLoading => _boardLoading;
  String? get boardError => _boardError;

  /// Load every lead (across all stages) for the kanban board.
  Future<void> loadBoardLeads({bool refresh = false}) async {
    if (_boardLoading) return;
    if (!refresh && _boardLoaded) return;

    _boardLoading = true;
    _boardError = null;
    notifyListeners();

    try {
      final all = <Lead>[];
      var page = 1;
      var totalPages = 1;
      // Page through the API so the board has the complete pipeline.
      do {
        final res = await _leadService.getLeads(page: page, pageSize: 200);
        all.addAll(res.items);
        totalPages = res.totalPages;
        page++;
      } while (page <= totalPages && page <= 25); // hard cap = 5000 leads
      _boardLeads = all;
      _boardLoaded = true;
    } catch (e) {
      _boardError = e.toString();
    }

    _boardLoading = false;
    notifyListeners();
  }

  /// Change a lead's assigned user (board drag in "Group by Assigned To").
  Future<void> setLeadAssignee(Lead lead, String? userId) async {
    final request = UpdateLeadRequest(
      sourceId: lead.source?.id,
      since: lead.since,
      productIds: lead.products.map((p) => p.id).toList(),
      assignedTo: userId,
      stage: lead.stage,
      tags: lead.tags,
      requirements: lead.requirements,
      notes: lead.notes,
      potential: lead.potential,
      business: lead.business.toJson(),
      customFields: lead.customFields,
    );
    final updated = await updateLead(lead.id, request);
    if (updated != null) _replaceBoardLead(updated);
  }

  /// Bulk-assign the given leads to a user. Uses the bulk endpoint; if it fails,
  /// falls back to updating each lead individually so it works on every backend.
  Future<void> bulkAssign(List<String> leadIds, String? userId) async {
    try {
      await _leadService.bulkAssignLeads(leadIds: leadIds, userId: userId);
    } catch (_) {
      // Fallback: update each lead one by one.
      for (final id in leadIds) {
        final lead = _leads.firstWhere(
          (l) => l.id == id,
          orElse: () => _boardLeads.firstWhere((l) => l.id == id),
        );
        await setLeadAssignee(lead, userId);
      }
    }
  }

  /// Optimistically swap a lead in the board list after an update.
  void _replaceBoardLead(Lead lead) {
    final i = _boardLeads.indexWhere((l) => l.id == lead.id);
    if (i != -1) {
      _boardLeads[i] = lead;
      notifyListeners();
    }
  }

  /// Move a board lead to a new stage (drag in "Group by Stage").
  Future<void> moveBoardLeadToStage(Lead lead, String stage) async {
    final updated = await setLeadStage(lead, stage);
    if (updated != null) _replaceBoardLead(updated);
  }

  /// Add [tagName] to a board lead (drag onto a tag column). No-op if present.
  Future<void> addTagToBoardLead(Lead lead, String tagName) async {
    if (lead.tags.contains(tagName)) return;
    final updated = await _updateLeadTags(lead, {...lead.tags, tagName});
    if (updated != null) _replaceBoardLead(updated);
  }

  /// Remove [tagName] from every board lead carrying it (the tag itself stays).
  /// Powers the tag board's "Clear all cards" action.
  Future<void> removeTagFromAllLeads(String tagName) async {
    final affected = _boardLeads
        .where((l) => l.tags.contains(tagName))
        .toList();
    for (final lead in affected) {
      final updated = await _updateLeadTags(
        lead,
        lead.tags.where((t) => t != tagName).toSet(),
      );
      if (updated != null) _replaceBoardLead(updated);
    }
  }

  /// Rename [oldName] → [newName] on every board lead carrying it, so the tag
  /// board column and its cards follow a tag rename.
  Future<void> renameTagOnAllLeads(String oldName, String newName) async {
    final affected = _boardLeads
        .where((l) => l.tags.contains(oldName))
        .toList();
    for (final lead in affected) {
      final newTags = lead.tags.map((t) => t == oldName ? newName : t).toSet();
      final updated = await _updateLeadTags(lead, newTags);
      if (updated != null) _replaceBoardLead(updated);
    }
  }

  /// Update only a lead's tag list, preserving every other field.
  Future<Lead?> _updateLeadTags(Lead lead, Set<String> tags) async {
    final request = UpdateLeadRequest(
      sourceId: lead.source?.id,
      since: lead.since,
      productIds: lead.products.map((p) => p.id).toList(),
      assignedTo: lead.assignedUser?.id,
      stage: lead.stage,
      tags: tags,
      requirements: lead.requirements,
      notes: lead.notes,
      potential: lead.potential,
      business: lead.business.toJson(),
      customFields: lead.customFields,
    );
    return updateLead(lead.id, request);
  }

  /// Reorder pipeline stages (drag columns on the board). Sends the full ordered
  /// list of stage names, then refreshes the local stage list.
  Future<void> reorderStages(List<String> orderedNames) async {
    // Optimistic local reorder so the board updates instantly.
    final byName = {for (final s in _stages) s.stage: s};
    final next = <LeadStage>[];
    for (var i = 0; i < orderedNames.length; i++) {
      final s = byName[orderedNames[i]];
      if (s != null) next.add(s.copyWith(order: i));
    }
    if (next.length == _stages.length) {
      _stages = next;
      notifyListeners();
    }
    await _leadService.moveStages(orderedNames);
    await refreshStages();
  }

  /// Pipeline names for the filter dropdown: the known pipelines first (so all
  /// three always appear), followed by any extra sections found on the stages.
  List<String> get pipelines {
    final result = <String>[...knownPipelines];
    for (final s in _stages) {
      final sec = s.section;
      if (sec != null && sec.isNotEmpty && !result.contains(sec)) {
        result.add(sec);
      }
    }
    return result;
  }

  // ── Load Leads ───────────────────────────────────────────────────

  /// Initial load / refresh of leads.
  ///
  /// Caching: once leads have been fetched, calling this again is a no-op so
  /// returning to the tab shows the cached list instantly. Pass [refresh] = true
  /// (pull-to-refresh, search, filter, org switch) to force a fresh fetch.
  Future<void> loadLeads({bool refresh = false}) async {
    if (_isLoading) return;
    // Serve cached leads unless: explicit refresh, first load, or cache stale (> 5 min)
    if (!refresh && _initialLoaded && !_isCacheStale()) return;

    _isLoading = true;
    _error = null;
    if (refresh) {
      _currentPage = 1;
    }
    notifyListeners();

    try {
      final response = await _leadService.getLeads(
        page: 1,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
        stage: _selectedStage,
      );

      _leads = response.items;
      _currentPage = response.page;
      _totalPages = response.totalPages;
      _totalCount = response.total;
      _error = null;
      _initialLoaded = true;
      _lastLoadedAt = DateTime.now();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load next page (infinite scroll).
  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final response = await _leadService.getLeads(
        page: _currentPage + 1,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
        stage: _selectedStage,
      );

      _leads.addAll(response.items);
      _currentPage = response.page;
      _totalPages = response.totalPages;
      _totalCount = response.total;
    } catch (e) {
      _error = e.toString();
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // ── Search & Filter ──────────────────────────────────────────────

  /// Update search query and reload.
  Future<void> search(String query) async {
    _searchQuery = query;
    await loadLeads(refresh: true);
  }

  // New method to fetch custom field settings
  /// Fetch custom field settings from the backend.
  Future<void> fetchLeadFieldSettings({bool forceRefresh = false}) async {
    if (_leadFieldSettings != null && !forceRefresh) return; // already loaded
    try {
      final settings = await _leadService.getLeadFieldSettings();
      _leadFieldSettings = settings;
      notifyListeners();
    } catch (e) {
      // ignore errors; UI will handle missing settings
    }
  }

  /// Adds a new value to a `select` custom field's dropdown, org-wide.
  /// Rethrows on failure so the caller (an "Add new" dialog) can show it.
  Future<void> addCustomFieldOption(String fieldKey, String newOption) async {
    final settings = await _leadService.addCustomFieldOption(
      fieldKey: fieldKey,
      newOption: newOption,
    );
    _leadFieldSettings = settings;
    notifyListeners();
  }

  /// Filter by stage and reload.
  Future<void> filterByStage(String? stage) async {
    _selectedStage = stage;
    await loadLeads(refresh: true);
  }

  /// Clear all filters and reload.
  Future<void> clearFilters() async {
    _searchQuery = '';
    _selectedStage = null;
    await loadLeads(refresh: true);
  }

  /// Clears lead list so the next screen visit fetches fresh data for the active org.
  void clearCache() {
    _leads = [];
    _searchQuery = '';
    _selectedStage = null;
    _currentPage = 1;
    _initialLoaded = false;
    _lastLoadedAt = null;
    _supportingDataLoaded = false;
    _boardLeads = [];
    _boardLoaded = false;
    notifyListeners();
  }

  // ── Supporting Data ──────────────────────────────────────────────

  /// The pipelines (sections) this CRM supports.
  static const List<String> knownPipelines = [
    'Inquiry Pipeline',
    'Order Pipeline',
    'Dispatch Pipeline',
  ];

  /// Fetch stages for every pipeline and merge them, each tagged with its
  /// pipeline/section. Falls back gracefully:
  ///  • If a single call already returns multiple sections, use it as-is.
  ///  • If the `section` query param is ignored (every pipeline returns the same
  ///    stages), keep the single set so we don't show fake duplicate columns.
  Future<List<LeadStage>> _fetchAllStages() async {
    final base = await _leadService.getLeadStages();
    final baseSections = base.map((s) => s.section).whereType<String>().toSet();
    if (baseSections.length > 1) return base; // API already returns all

    // Fetch each known pipeline separately.
    final perPipeline = <String, List<LeadStage>>{};
    for (final p in knownPipelines) {
      try {
        perPipeline[p] = await _leadService.getLeadStages(section: p);
      } catch (_) {
        perPipeline[p] = [];
      }
    }

    // Detect whether the `section` param actually filtered anything: if every
    // pipeline came back with an identical stage-name set, the param was ignored.
    final nonEmpty = perPipeline.values.where((l) => l.isNotEmpty).toList();
    if (nonEmpty.length < 2) return base;
    final sets = nonEmpty.map((l) => l.map((s) => s.stage).toSet()).toList();
    final allIdentical = sets.every(
      (s) => s.length == sets.first.length && s.containsAll(sets.first),
    );
    if (allIdentical) return base; // param ignored → single pipeline

    // Merge, de-duplicating by pipeline+stage.
    final merged = <LeadStage>[];
    final seen = <String>{};
    for (final p in knownPipelines) {
      for (final s in perPipeline[p] ?? const <LeadStage>[]) {
        final key = '${s.section ?? p}|${s.stage}';
        if (seen.add(key)) merged.add(s);
      }
    }
    return merged.isNotEmpty ? merged : base;
  }

  /// Force-refresh just the stage list (e.g. after Manage Stages changes) so the
  /// filter chips on the lead list update immediately. Also drops the lead cache
  /// since a stage rename/reorder/delete can change which leads match.
  Future<void> refreshStages() async {
    try {
      _stages = await _fetchAllStages();
      // A renamed/deleted stage may no longer match the active filter.
      if (_selectedStage != null &&
          !_stages.any((s) => s.stage == _selectedStage)) {
        _selectedStage = null;
      }
      _initialLoaded = false;
      _lastLoadedAt = null;
      _boardLoaded = false;
      notifyListeners();
    } catch (_) {
      // ignore — chips keep showing the last known stages
    }
  }

  /// Load stages, products, sources, and users for form dropdowns.
  Future<void> loadSupportingData() async {
    if (_supportingDataLoaded) return;

    try {
      final results = await Future.wait([
        _fetchAllStages(),
        _leadService.getProducts(),
        _leadService.getSources(),
        _leadService.getUsers(),
      ]);

      _stages = results[0] as List<LeadStage>;
      _products = results[1] as List<ProductItem>;
      _sources = results[2] as List<SourceItem>;
      _users = results[3] as List<UserDetail>;
      _supportingDataLoaded = true;
      notifyListeners();
    } catch (e) {
      // Silently fail — we can retry when the form opens
    }
  }

  // ── CRUD Operations ──────────────────────────────────────────────

  /// Create a new lead.
  Future<Lead?> createLead(CreateLeadRequest request) async {
    _isSaving = true;
    notifyListeners();

    try {
      final lead = await _leadService.createLead(request);
      _leads.insert(0, lead);
      _totalCount++;
      _isSaving = false;
      notifyListeners();
      return lead;
    } catch (e) {
      _isSaving = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Resolve the org's "won" / "lost" stage names from the loaded stages,
  /// falling back to the canonical labels if the list isn't available yet.
  String get wonStageName => _stages
      .firstWhere(
        (s) => s.stage.toLowerCase().contains('won'),
        orElse: () => const LeadStage(stage: 'WON', order: 999),
      )
      .stage;

  String get lostStageName => _stages
      .firstWhere(
        (s) => s.stage.toLowerCase().contains('lost'),
        orElse: () => const LeadStage(stage: 'LOST', order: 999),
      )
      .stage;

  /// The stage a new lead should start in so users don't have to pick one
  /// manually every time. Prefers a "raw"/"unqualified" stage, then falls
  /// back to the lowest-order stage in the pipeline.
  String? get defaultStageName {
    if (_stages.isEmpty) return null;
    final rawUnqualified = _stages.where(
      (s) =>
          s.stage.toLowerCase().contains('raw') ||
          s.stage.toLowerCase().contains('unqualified'),
    );
    if (rawUnqualified.isNotEmpty) return rawUnqualified.first.stage;
    return _stages.reduce((a, b) => a.order <= b.order ? a : b).stage;
  }

  /// Update only a lead's stage (used by swipe-to-win / swipe-to-lose),
  /// preserving every other field from the existing lead.
  Future<Lead?> setLeadStage(Lead lead, String stage) async {
    final request = UpdateLeadRequest(
      sourceId: lead.source?.id,
      since: lead.since,
      productIds: lead.products.map((p) => p.id).toList(),
      assignedTo: lead.assignedUser?.id,
      stage: stage,
      tags: lead.tags,
      requirements: lead.requirements,
      notes: lead.notes,
      potential: lead.potential,
      business: lead.business.toJson(),
      customFields: lead.customFields,
    );
    return updateLead(lead.id, request);
  }

  /// Update an existing lead.
  Future<Lead?> updateLead(String id, UpdateLeadRequest request) async {
    _isSaving = true;
    notifyListeners();

    try {
      final updatedLead = await _leadService.updateLead(id, request);
      // Preserve custom field values if any (handled in request)
      final index = _leads.indexWhere((l) => l.id == id);
      if (index != -1) {
        _leads[index] = updatedLead;
      }
      _isSaving = false;
      notifyListeners();
      return updatedLead;
    } catch (e) {
      _isSaving = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a lead by ID.
  Future<bool> deleteLead(String id) async {
    _isDeleting = true;
    notifyListeners();

    try {
      await _leadService.deleteLead(id);
      _leads.removeWhere((l) => l.id == id);
      _totalCount--;
      _isDeleting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isDeleting = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Fetch a single lead by ID (for detail view refresh).
  Future<Lead> getLeadById(String id) async {
    return _leadService.getLeadById(id);
  }
}
