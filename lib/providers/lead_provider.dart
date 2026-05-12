import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../services/lead_service.dart';

/// Manages lead listing, search, filter, pagination, and CRUD states.
class LeadProvider extends ChangeNotifier {
  final LeadService _leadService = LeadService();

  // ── Lead List State ──────────────────────────────────────────────
  List<Lead> _leads = [];
  bool _isLoading = false;
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

  bool get isSaving => _isSaving;
  bool get isDeleting => _isDeleting;

  // ── Load Leads ───────────────────────────────────────────────────

  /// Initial load / refresh of leads.
  Future<void> loadLeads({bool refresh = false}) async {
    if (_isLoading) return;

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

  // ── Supporting Data ──────────────────────────────────────────────

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

  /// Update an existing lead.
  Future<Lead?> updateLead(String id, UpdateLeadRequest request) async {
    _isSaving = true;
    notifyListeners();

    try {
      final updatedLead = await _leadService.updateLead(id, request);
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
