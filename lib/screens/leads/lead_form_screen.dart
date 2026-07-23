import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/country_codes.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/lead.dart';
import '../../models/lead_field_settings.dart';
import '../../providers/lead_provider.dart';
import '../../providers/tag_provider.dart';
import '../../services/ai_service.dart';

/// Shared form screen for creating and editing leads.
class LeadFormScreen extends StatefulWidget {
  final Lead? lead; // null = create mode
  final String? initialStage; // pre-select a stage when creating from the board
  final Set<String>?
  initialTags; // pre-select tags when creating from a tag column
  const LeadFormScreen({
    super.key,
    this.lead,
    this.initialStage,
    this.initialTags,
  });

  @override
  State<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends State<LeadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool get isEditing => widget.lead != null;
  final Map<String, TextEditingController> _customFieldCtrls = {};

  TextEditingController _getCustomFieldCtrl(String key) {
    if (!_customFieldCtrls.containsKey(key)) {
      final initialValue = widget.lead?.customFields[key]?.toString() ?? '';
      _customFieldCtrls[key] = TextEditingController(text: initialValue);
    }
    return _customFieldCtrls[key]!;
  }

  // AI Smart Paste
  final TextEditingController _aiPasteCtrl = TextEditingController();
  bool _aiLoading = false;

  // Business fields
  late TextEditingController _businessNameCtrl;
  late TextEditingController _contactNameCtrl;
  CountryCode _selectedCountryCode =
      kCountryCodes.first; // defaults to India +91
  late TextEditingController _mobileCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _designationCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;

  // Lead fields
  late TextEditingController _requirementsCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _potentialCtrl;

  String? _selectedTitle;
  String? _selectedStage;
  int? _selectedSourceId;
  String? _selectedAssignedTo;
  List<int> _selectedProductIds = [];
  final Set<String> _selectedTags = {};
  late DateTime _sinceDate;

  @override
  void initState() {
    super.initState();
    final lead = widget.lead;

    _businessNameCtrl = TextEditingController(
      text: lead?.business.business ?? '',
    );
    _contactNameCtrl = TextEditingController(text: lead?.business.name ?? '');
    final rawMobile = lead?.business.mobile ?? '';
    String initCode = '+91';
    String initNumber = rawMobile;
    if (rawMobile.startsWith('+')) {
      final spaceIdx = rawMobile.indexOf(' ');
      if (spaceIdx != -1) {
        initCode = rawMobile.substring(0, spaceIdx);
        initNumber = rawMobile.substring(spaceIdx + 1);
      } else if (rawMobile.length > 3) {
        initCode = rawMobile.substring(0, 3);
        initNumber = rawMobile.substring(3);
      }
    }
    _selectedCountryCode = kCountryCodes.firstWhere(
      (c) => c.dialCode == initCode,
      orElse: () => kCountryCodes.first,
    );
    _mobileCtrl = TextEditingController(text: initNumber);
    _emailCtrl = TextEditingController(text: lead?.business.email ?? '');
    _designationCtrl = TextEditingController(
      text: lead?.business.designation ?? '',
    );
    _websiteCtrl = TextEditingController(text: lead?.business.website ?? '');
    _addressCtrl = TextEditingController(
      text: lead?.business.addressLine1 ?? '',
    );
    _cityCtrl = TextEditingController(text: lead?.business.city ?? '');
    _requirementsCtrl = TextEditingController(text: lead?.requirements ?? '');
    _notesCtrl = TextEditingController(text: lead?.notes ?? '');
    _potentialCtrl = TextEditingController(
      text: lead != null && lead.potential > 0 ? lead.potential.toString() : '',
    );

    _selectedTitle = lead?.business.title;
    _selectedStage = lead?.stage ?? widget.initialStage;
    _selectedSourceId = lead?.source?.id;
    _selectedAssignedTo = lead?.assignedUser?.id;
    _selectedProductIds = lead?.products.map((p) => p.id).toList() ?? [];
    if (lead != null) _selectedTags.addAll(lead.tags);
    if (lead == null && widget.initialTags != null) {
      _selectedTags.addAll(widget.initialTags!);
    }
    _sinceDate = lead?.since ?? DateTime.now();

    // Ensure supporting data is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final leadProvider = context.read<LeadProvider>();
      leadProvider.loadSupportingData().then((_) {
        if (!mounted) return;
        // New leads default to the pipeline's "raw/unqualified" stage so
        // users aren't forced to pick one manually every time.
        if (!isEditing && _selectedStage == null) {
          final fallback = leadProvider.defaultStageName;
          if (fallback != null) setState(() => _selectedStage = fallback);
        }
      });
      context.read<TagProvider>().loadTags();
    });
  }

  @override
  void dispose() {
    _aiPasteCtrl.dispose();
    _businessNameCtrl.dispose();
    _contactNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _designationCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _requirementsCtrl.dispose();
    _notesCtrl.dispose();
    _potentialCtrl.dispose();
    for (var ctrl in _customFieldCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          isEditing ? 'Edit Lead' : 'New Lead',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          Consumer<LeadProvider>(
            builder: (context, provider, child) => TextButton(
              onPressed: provider.isSaving ? null : _save,
              child: provider.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isEditing ? 'Update' : 'Create',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // AI Smart Paste Button
            _buildAiSmartPasteButton(),
            const SizedBox(height: 20),

            _buildSectionHeader('Business Information'),
            const SizedBox(height: 8),
            _buildCard([
              _buildTextField(
                _businessNameCtrl,
                'Business Name',
                Icons.store_rounded,
              ),
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedTitle,
                      decoration: const InputDecoration(labelText: 'Title'),
                      items: ['Mr.', 'Ms.']
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => _selectedTitle = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _contactNameCtrl,
                      'Contact Name *',
                      Icons.person_rounded,
                      required: true,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _pickCountryCode,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedCountryCode.flag,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _selectedCountryCode.dialCode,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTextField(
                      _mobileCtrl,
                      'Mobile',
                      Icons.phone_rounded,
                      keyboard: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _mobilePasteFormatter,
                      ],
                      maxLength: 10,
                      validator: (v) => v != null && v.isNotEmpty && v.length != 10
                          ? 'Enter a valid 10-digit mobile number'
                          : null,
                    ),
                  ),
                ],
              ),
              _buildTextField(
                _emailCtrl,
                'Email',
                Icons.email_rounded,
                keyboard: TextInputType.emailAddress,
              ),
              _buildTextField(
                _designationCtrl,
                'Designation',
                Icons.work_rounded,
              ),
            ]),

            const SizedBox(height: 20),
            _buildSectionHeader('Lead Information'),
            const SizedBox(height: 8),
            _buildCard([
              // Stage dropdown
              Consumer<LeadProvider>(
                builder: (context, provider, child) =>
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStage,
                      decoration: const InputDecoration(
                        labelText: 'Stage *',
                        prefixIcon: Icon(Icons.flag_rounded, size: 20),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Stage is required' : null,
                      items: provider.stages
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.stage,
                              child: Text(s.stage),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedStage = v),
                    ),
              ),
              // Since date
              _buildDatePicker(),
              // Potential
              _buildTextField(
                _potentialCtrl,
                'Potential Value (₹)',
                Icons.monetization_on_rounded,
                keyboard: TextInputType.number,
              ),
              // Source dropdown
              Consumer<LeadProvider>(
                builder: (context, provider, child) =>
                    DropdownButtonFormField<int>(
                      initialValue: _selectedSourceId,
                      decoration: const InputDecoration(
                        labelText: 'Source',
                        prefixIcon: Icon(Icons.source_rounded, size: 20),
                      ),
                      items: provider.sources
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => _selectedSourceId = v,
                    ),
              ),
              // Assigned To dropdown
              Consumer<LeadProvider>(
                builder: (context, provider, child) =>
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAssignedTo,
                      decoration: const InputDecoration(
                        labelText: 'Assigned To',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                        ),
                      ),
                      items: provider.users
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(u.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => _selectedAssignedTo = v,
                    ),
              ),
            ]),

            const SizedBox(height: 20),
            _buildSectionHeader('Products / Services'),
            const SizedBox(height: 8),
            _buildProductSelector(),

            const SizedBox(height: 20),
            _buildSectionHeader('Tags'),
            const SizedBox(height: 8),
            _buildTagSelector(),

            Consumer<LeadProvider>(
              builder: (context, provider, child) {
                if (!provider.showCustomFields ||
                    provider.leadFieldSettings == null ||
                    provider.leadFieldSettings!.customFields.isEmpty) {
                  return const SizedBox.shrink();
                }
                final customFields = provider.leadFieldSettings!.customFields;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildSectionHeader('Additional Information'),
                    const SizedBox(height: 8),
                    _buildCard(
                      customFields.map((field) {
                        if (field.fieldType.toLowerCase() == 'select') {
                          return _buildCustomSelectField(field);
                        }
                        return _buildTextField(
                          _getCustomFieldCtrl(field.key),
                          '${field.label}${field.isRequired ? ' *' : ''}',
                          Icons.dashboard_customize_rounded,
                          required: field.isRequired,
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),
            _buildSectionHeader('Additional Details'),
            const SizedBox(height: 8),
            _buildCard([
              _buildTextField(_websiteCtrl, 'Website', Icons.language_rounded),
              _buildTextField(
                _addressCtrl,
                'Address',
                Icons.location_on_rounded,
              ),
              _buildTextField(_cityCtrl, 'City', Icons.location_city_rounded),
              _buildTextField(
                _requirementsCtrl,
                'Requirements',
                Icons.list_alt_rounded,
                maxLines: 3,
              ),
              _buildTextField(
                _notesCtrl,
                'Notes',
                Icons.note_rounded,
                maxLines: 3,
              ),
            ]),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: child,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int maxLines = 1,
    bool required = false,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        counterText: maxLength != null ? '' : null,
      ),
      validator: validator ??
          (required
              ? (v) => v == null || v.isEmpty ? '$label is required' : null
              : null),
    );
  }

  static const _addNewOptionSentinel = '__add_new_option__';

  /// Dropdown for a `select`-type custom field (e.g. Port of Loading),
  /// with a trailing "Add new" entry that lets the user extend the org's
  /// shared option list on the fly.
  Widget _buildCustomSelectField(CustomField field) {
    final ctrl = _getCustomFieldCtrl(field.key);
    final options = List<String>.from(field.options ?? []);
    // The lead's current value may predate this field's option list (older
    // freeform data, or an option since removed) — keep it selectable so
    // editing doesn't silently wipe it.
    if (ctrl.text.isNotEmpty && !options.contains(ctrl.text)) {
      options.insert(0, ctrl.text);
    }

    return DropdownButtonFormField<String>(
      initialValue: ctrl.text.isEmpty ? null : ctrl.text,
      decoration: InputDecoration(
        labelText: '${field.label}${field.isRequired ? ' *' : ''}',
        prefixIcon: const Icon(
          Icons.arrow_drop_down_circle_outlined,
          size: 20,
        ),
      ),
      isExpanded: true,
      validator: field.isRequired
          ? (v) => v == null || v.isEmpty ? '${field.label} is required' : null
          : null,
      items: [
        ...options.map(
          (o) => DropdownMenuItem(
            value: o,
            child: Text(o, overflow: TextOverflow.ellipsis),
          ),
        ),
        DropdownMenuItem(
          value: _addNewOptionSentinel,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 18, color: AppTheme.primaryBlue),
              const SizedBox(width: 6),
              Text(
                'Add new',
                style: GoogleFonts.inter(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      onChanged: (value) async {
        if (value == _addNewOptionSentinel) {
          await _promptAddCustomOption(field);
        } else if (value != null) {
          setState(() => ctrl.text = value);
        }
      },
    );
  }

  /// Prompts for a new option value, persists it to the org's shared field
  /// config (visible in this dropdown for every user from then on), and
  /// selects it on this lead. Leaves the field's current value untouched
  /// on cancel or failure.
  Future<void> _promptAddCustomOption(CustomField field) async {
    final provider = context.read<LeadProvider>();
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add ${field.label}',
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: field.label),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return;

    final fieldCtrl = _getCustomFieldCtrl(field.key);
    try {
      await provider.addCustomFieldOption(field.key, trimmed);
      if (mounted) setState(() => fieldCtrl.text = trimmed);
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not add option: $e');
      }
    }
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _sinceDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) setState(() => _sinceDate = date);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Enquiry Date',
          prefixIcon: Icon(Icons.event_rounded, size: 20),
        ),
        child: Text(
          DateFormat('MMM d, yyyy').format(_sinceDate),
          style: GoogleFonts.inter(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildProductSelector() {
    return Consumer<LeadProvider>(
      builder: (context, provider, child) {
        if (provider.products.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'No products available',
              style: GoogleFonts.inter(color: AppTheme.textTertiary),
            ),
          );
        }
        final selected = provider.products
            .where((p) => _selectedProductIds.contains(p.id))
            .toList();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selected.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'No products selected',
                    style: GoogleFonts.inter(color: AppTheme.textTertiary),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selected.map((product) {
                    return Chip(
                      label: Text(
                        product.name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: AppTheme.primaryBlue,
                      deleteIcon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      onDeleted: () => setState(
                          () => _selectedProductIds.remove(product.id)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _openProductPicker(provider.products),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded,
                            size: 16, color: AppTheme.primaryBlue),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Add Products / Services',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Bottom sheet with a search field to filter the (potentially long)
  /// products/services list instead of rendering every chip inline.
  void _openProductPicker(List<ProductItem> products) {
    final searchCtrl = TextEditingController();
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = query.isEmpty
              ? products
              : products
                  .where((p) =>
                      p.name.toLowerCase().contains(query.toLowerCase()))
                  .toList();
          final count = _selectedProductIds.length;
          return FractionallySizedBox(
            heightFactor: 0.8,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Products / Services',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  AppTheme.primaryBlue.withValues(alpha: 0.1),
                              foregroundColor: AppTheme.primaryBlue,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              count > 0 ? 'Done ($count)' : 'Done',
                              style: GoogleFonts.inter(
                                  fontSize: 13.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        onChanged: (v) => setSheetState(() => query = v),
                        style: GoogleFonts.inter(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          hintStyle:
                              GoogleFonts.inter(color: AppTheme.textTertiary),
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18, color: AppTheme.textTertiary),
                                  onPressed: () => setSheetState(() {
                                    searchCtrl.clear();
                                    query = '';
                                  }),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceGrey,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.search_off_rounded,
                                          size: 26,
                                          color: AppTheme.textTertiary),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No matching products',
                                      style: GoogleFonts.inter(
                                          color: AppTheme.textTertiary),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 12),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (_, i) {
                                final product = filtered[i];
                                final sel =
                                    _selectedProductIds.contains(product.id);
                                return _pickerRow(
                                  name: product.name,
                                  selected: sel,
                                  onTap: () {
                                    setSheetState(() {
                                      setState(() {
                                        if (sel) {
                                          _selectedProductIds
                                              .remove(product.id);
                                        } else {
                                          _selectedProductIds
                                              .add(product.id);
                                        }
                                      });
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pickerRow({
    required String name,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryBlue.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      selected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTheme.primaryBlue : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppTheme.primaryBlue
                      : const Color(0xFFD1D5DB),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 15, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagSelector() {
    return Consumer<TagProvider>(
      builder: (context, provider, child) {
        // Show every org tag plus any tag already on the lead that isn't yet
        // in the loaded list (e.g. legacy free-text tags).
        final names = <String>{...provider.tagNames, ..._selectedTags}.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        final selected = names.where(_selectedTags.contains).toList();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider.isLoading && names.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading tags…',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              else if (selected.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'No tags selected',
                    style: GoogleFonts.inter(color: AppTheme.textTertiary),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selected.map((name) {
                    return Chip(
                      label: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: AppTheme.primaryBlue,
                      deleteIcon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      onDeleted: () =>
                          setState(() => _selectedTags.remove(name)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _openTagPicker(names),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded,
                            size: 16, color: AppTheme.primaryBlue),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Add Tags',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Bottom sheet with a search field to filter the tags list, mirroring
  /// _openProductPicker. Also exposes "New Tag" creation inline.
  void _openTagPicker(List<String> names) {
    final searchCtrl = TextEditingController();
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = query.isEmpty
              ? names
              : names
                  .where((n) => n.toLowerCase().contains(query.toLowerCase()))
                  .toList();
          final count = _selectedTags.length;
          return FractionallySizedBox(
            heightFactor: 0.8,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Tags',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await _addTagInline();
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: Text(
                              'New',
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryBlue,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  AppTheme.primaryBlue.withValues(alpha: 0.1),
                              foregroundColor: AppTheme.primaryBlue,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              count > 0 ? 'Done ($count)' : 'Done',
                              style: GoogleFonts.inter(
                                  fontSize: 13.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        onChanged: (v) => setSheetState(() => query = v),
                        style: GoogleFonts.inter(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search tags...',
                          hintStyle:
                              GoogleFonts.inter(color: AppTheme.textTertiary),
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18, color: AppTheme.textTertiary),
                                  onPressed: () => setSheetState(() {
                                    searchCtrl.clear();
                                    query = '';
                                  }),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceGrey,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.search_off_rounded,
                                          size: 26,
                                          color: AppTheme.textTertiary),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      names.isEmpty
                                          ? 'No tags yet. Tap "New" to create one.'
                                          : 'No matching tags',
                                      style: GoogleFonts.inter(
                                          color: AppTheme.textTertiary),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 12),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (_, i) {
                                final name = filtered[i];
                                final sel = _selectedTags.contains(name);
                                return _pickerRow(
                                  name: name,
                                  selected: sel,
                                  onTap: () {
                                    setSheetState(() {
                                      setState(() {
                                        if (sel) {
                                          _selectedTags.remove(name);
                                        } else {
                                          _selectedTags.add(name);
                                        }
                                      });
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Prompt for a new tag, create it as a real org tag, and select it.
  Future<void> _addTagInline() async {
    final tagProvider = context.read<TagProvider>();
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Tag',
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Tag name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;

    setState(() => _selectedTags.add(trimmed));
    // Persist it as an org tag so it appears in the manager and filters.
    await tagProvider.ensureTag(trimmed);
  }

  /// Pasting a number copied with its country code (e.g. "+911234567890")
  /// leaves 12 digits after [FilteringTextInputFormatter.digitsOnly], which
  /// would otherwise just get truncated to the first 10 ("9112345678").
  /// Strip a matching country-code prefix first so the real 10-digit number
  /// ("1234567890") survives instead.
  TextInputFormatter get _mobilePasteFormatter =>
      TextInputFormatter.withFunction((oldValue, newValue) {
        var digits = newValue.text;
        if (digits.length > 10) {
          final candidates = <String>{
            _selectedCountryCode.dialCode.replaceAll('+', ''),
            ...kCountryCodes.map((c) => c.dialCode.replaceAll('+', '')),
          }.toList()
            ..sort((a, b) => b.length.compareTo(a.length));
          for (final code in candidates) {
            if (digits.startsWith(code) && digits.length - code.length == 10) {
              digits = digits.substring(code.length);
              break;
            }
          }
        }
        return TextEditingValue(
          text: digits,
          selection: TextSelection.collapsed(offset: digits.length),
        );
      });

  Future<void> _pickCountryCode() async {
    final query = ValueNotifier('');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Select Country Code',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search country...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (v) => query.value = v.toLowerCase(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: query,
                builder: (_, q, _) {
                  final filtered = q.isEmpty
                      ? kCountryCodes
                      : kCountryCodes
                            .where(
                              (c) =>
                                  c.name.toLowerCase().contains(q) ||
                                  c.dialCode.contains(q),
                            )
                            .toList();
                  return ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final cc = filtered[i];
                      final selected =
                          cc.dialCode == _selectedCountryCode.dialCode &&
                          cc.name == _selectedCountryCode.name;
                      return ListTile(
                        leading: Text(
                          cc.flag,
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text(
                          cc.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Text(
                          cc.dialCode,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        selected: selected,
                        selectedTileColor: AppTheme.primaryBlue.withValues(
                          alpha: 0.06,
                        ),
                        onTap: () {
                          setState(() => _selectedCountryCode = cc);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStage == null) {
      SnackbarHelper.showError(context, 'Please select a stage');
      return;
    }
    if (_mobileCtrl.text.trim().isEmpty && _emailCtrl.text.trim().isEmpty) {
      SnackbarHelper.showError(
        context,
        'Please provide a mobile number or email',
      );
      return;
    }

    final business = {
      'business': _businessNameCtrl.text.trim(),
      'name': _contactNameCtrl.text.trim(),
      'title': _selectedTitle,
      'designation': _designationCtrl.text.trim(),
      'mobile': _mobileCtrl.text.trim().isEmpty
          ? ''
          : '${_selectedCountryCode.dialCode}${_mobileCtrl.text.trim()}',
      'email': _emailCtrl.text.trim(),
      'website': _websiteCtrl.text.trim(),
      'address_line_1': _addressCtrl.text.trim(),
      'address_line_2': '',
      'country': '',
      'city': _cityCtrl.text.trim(),
      'gstin': '',
      'code': '',
    };

    final provider = context.read<LeadProvider>();
    final Map<String, dynamic> customFieldsData = {};
    if (provider.showCustomFields && provider.leadFieldSettings != null) {
      for (var field in provider.leadFieldSettings!.customFields) {
        customFieldsData[field.key] = _getCustomFieldCtrl(
          field.key,
        ).text.trim();
      }
    }

    try {
      if (isEditing) {
        business['id'] = widget.lead!.business.id;
        await provider.updateLead(
          widget.lead!.id,
          UpdateLeadRequest(
            sourceId: _selectedSourceId,
            since: _sinceDate,
            productIds: _selectedProductIds,
            assignedTo: _selectedAssignedTo,
            stage: _selectedStage!,
            tags: _selectedTags,
            requirements: _requirementsCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            potential: int.tryParse(_potentialCtrl.text) ?? 0,
            business: business,
            customFields: customFieldsData,
          ),
        );
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Lead updated');
          Navigator.pop(context, true);
        }
      } else {
        await provider.createLead(
          CreateLeadRequest(
            sourceId: _selectedSourceId,
            since: _sinceDate,
            productIds: _selectedProductIds,
            assignedTo: _selectedAssignedTo,
            stage: _selectedStage!,
            tags: _selectedTags,
            requirements: _requirementsCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            potential: int.tryParse(_potentialCtrl.text) ?? 0,
            business: business,
            customFields: customFieldsData,
          ),
        );
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Lead created');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e.toString());
    }
  }

  Widget _buildAiSmartPasteButton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.1),
            AppTheme.primaryBlue.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: _handleAiSmartPaste,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Smart Paste',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Paste business details and let AI extract the information',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.primaryBlue.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAiSmartPaste() async {
    _aiPasteCtrl.clear();
    if (mounted) setState(() => _aiLoading = false);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final keyboardH = MediaQuery.of(ctx).viewInsets.bottom;
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: keyboardH + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Smart Paste',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Paste any message or business card text',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _aiPasteCtrl,
                  maxLines: 6,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText:
                        'Paste email, WhatsApp message, business card text…',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _aiLoading
                        ? null
                        : () async {
                            final text = _aiPasteCtrl.text.trim();
                            if (text.isEmpty) return;
                            setSheetState(() => _aiLoading = true);
                            try {
                              final parsed = await AiService().parseLead(text);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              _fillFromParsed(parsed);
                              SnackbarHelper.showSuccess(
                                context,
                                'Fields filled from AI',
                              );
                            } catch (e) {
                              if (ctx.mounted) {
                                setSheetState(() => _aiLoading = false);
                                SnackbarHelper.showError(ctx, e.toString());
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _aiLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Extract & Fill',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _fillFromParsed(ParsedLeadData parsed) {
    // TextEditingController.text notifies its own listeners — no setState needed.
    // Only setState for non-controller state (_selectedTitle, _selectedCountryCode).
    if (parsed.businessName != null)
      _businessNameCtrl.text = parsed.businessName!;
    if (parsed.contactName != null) _contactNameCtrl.text = parsed.contactName!;
    if (parsed.email != null) _emailCtrl.text = parsed.email!;
    if (parsed.designation != null) _designationCtrl.text = parsed.designation!;
    if (parsed.website != null) _websiteCtrl.text = parsed.website!;
    if (parsed.addressLine1 != null) _addressCtrl.text = parsed.addressLine1!;
    if (parsed.city != null) _cityCtrl.text = parsed.city!;
    if (parsed.requirements != null)
      _requirementsCtrl.text = parsed.requirements!;
    if (parsed.notes != null) _notesCtrl.text = parsed.notes!;
    if (parsed.potential != null)
      _potentialCtrl.text = parsed.potential.toString();

    // Mobile: split country code from number
    if (parsed.mobile != null) {
      final raw = parsed.mobile!;
      if (raw.startsWith('+')) {
        CountryCode? match;
        for (final cc in kCountryCodes) {
          if (raw.startsWith(cc.dialCode)) {
            if (match == null || cc.dialCode.length > match.dialCode.length)
              match = cc;
          }
        }
        if (match != null) {
          _mobileCtrl.text = raw.substring(match.dialCode.length);
          setState(() {
            _selectedCountryCode = match!;
            if (parsed.title != null &&
                const ['Mr.', 'Ms.'].contains(parsed.title)) {
              _selectedTitle = parsed.title;
            }
          });
          return;
        } else {
          _mobileCtrl.text = raw;
        }
      } else {
        _mobileCtrl.text = raw;
      }
    }

    const validTitles = ['Mr.', 'Ms.'];
    if (parsed.title != null && validTitles.contains(parsed.title)) {
      setState(() => _selectedTitle = parsed.title);
    }
  }
}
