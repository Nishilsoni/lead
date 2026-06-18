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
    notifyListeners();
  }

  // ── Supporting Data ──────────────────────────────────────────────

  /// Force-refresh just the stage list (e.g. after Manage Stages changes) so the
  /// filter chips on the lead list update immediately. Also drops the lead cache
  /// since a stage rename/reorder/delete can change which leads match.
  Future<void> refreshStages() async {
    try {
      _stages = await _leadService.getLeadStages();
      // A renamed/deleted stage may no longer match the active filter.
      if (_selectedStage != null &&
          !_stages.any((s) => s.stage == _selectedStage)) {
        _selectedStage = null;
      }
      _initialLoaded = false;
      _lastLoadedAt = null;
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
        _leadService.getLeadStages(),
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
