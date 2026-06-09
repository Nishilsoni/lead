import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/lead.dart';
import '../../providers/lead_provider.dart';

/// Shared form screen for creating and editing leads.
class LeadFormScreen extends StatefulWidget {
  final Lead? lead; // null = create mode
  const LeadFormScreen({super.key, this.lead});

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

  // Business fields
  late TextEditingController _businessNameCtrl;
  late TextEditingController _contactNameCtrl;
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
  late DateTime _sinceDate;

  @override
  void initState() {
    super.initState();
    final lead = widget.lead;

    _businessNameCtrl = TextEditingController(text: lead?.business.business ?? '');
    _contactNameCtrl = TextEditingController(text: lead?.business.name ?? '');
    _mobileCtrl = TextEditingController(text: lead?.business.mobile ?? '');
    _emailCtrl = TextEditingController(text: lead?.business.email ?? '');
    _designationCtrl = TextEditingController(text: lead?.business.designation ?? '');
    _websiteCtrl = TextEditingController(text: lead?.business.website ?? '');
    _addressCtrl = TextEditingController(text: lead?.business.addressLine1 ?? '');
    _cityCtrl = TextEditingController(text: lead?.business.city ?? '');
    _requirementsCtrl = TextEditingController(text: lead?.requirements ?? '');
    _notesCtrl = TextEditingController(text: lead?.notes ?? '');
    _potentialCtrl = TextEditingController(text: lead != null && lead.potential > 0 ? lead.potential.toString() : '');

    _selectedTitle = lead?.business.title;
    _selectedStage = lead?.stage;
    _selectedSourceId = lead?.source?.id;
    _selectedAssignedTo = lead?.assignedUser?.id;
    _selectedProductIds = lead?.products.map((p) => p.id).toList() ?? [];
    _sinceDate = lead?.since ?? DateTime.now();

    // Ensure supporting data is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeadProvider>().loadSupportingData();
    });
  }

  @override
  void dispose() {
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
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      isEditing ? 'Update' : 'Create',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
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
              _buildTextField(_businessNameCtrl, 'Business Name', Icons.store_rounded),
              Row(children: [
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedTitle,
                    decoration: const InputDecoration(labelText: 'Title'),
                    items: ['Mr.', 'Ms.'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => _selectedTitle = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField(_contactNameCtrl, 'Contact Name *', Icons.person_rounded, required: true)),
              ]),
              _buildTextField(_mobileCtrl, 'Mobile', Icons.phone_rounded, keyboard: TextInputType.phone),
              _buildTextField(_emailCtrl, 'Email *', Icons.email_rounded, keyboard: TextInputType.emailAddress, required: true),
              _buildTextField(_designationCtrl, 'Designation', Icons.work_rounded),
            ]),

            const SizedBox(height: 20),
            _buildSectionHeader('Lead Information'),
            const SizedBox(height: 8),
            _buildCard([
              // Stage dropdown
              Consumer<LeadProvider>(
                builder: (context, provider, child) => DropdownButtonFormField<String>(
                  initialValue: _selectedStage,
                  decoration: const InputDecoration(labelText: 'Stage *', prefixIcon: Icon(Icons.flag_rounded, size: 20)),
                  validator: (v) => v == null || v.isEmpty ? 'Stage is required' : null,
                  items: provider.stages.map((s) => DropdownMenuItem(value: s.stage, child: Text(s.stage))).toList(),
                  onChanged: (v) => setState(() => _selectedStage = v),
                ),
              ),
              // Since date
              _buildDatePicker(),
              // Potential
              _buildTextField(_potentialCtrl, 'Potential Value (₹)', Icons.monetization_on_rounded, keyboard: TextInputType.number),
              // Source dropdown
              Consumer<LeadProvider>(
                builder: (context, provider, child) => DropdownButtonFormField<int>(
                  initialValue: _selectedSourceId,
                  decoration: const InputDecoration(labelText: 'Source', prefixIcon: Icon(Icons.source_rounded, size: 20)),
                  items: provider.sources.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (v) => _selectedSourceId = v,
                ),
              ),
              // Assigned To dropdown
              Consumer<LeadProvider>(
                builder: (context, provider, child) => DropdownButtonFormField<String>(
                  initialValue: _selectedAssignedTo,
                  decoration: const InputDecoration(labelText: 'Assigned To', prefixIcon: Icon(Icons.person_outline_rounded, size: 20)),
                  items: provider.users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                  onChanged: (v) => _selectedAssignedTo = v,
                ),
              ),
            ]),

            const SizedBox(height: 20),
            _buildSectionHeader('Products / Services'),
            const SizedBox(height: 8),
            _buildProductSelector(),

            Consumer<LeadProvider>(
              builder: (context, provider, child) {
                if (!provider.showCustomFields || provider.leadFieldSettings == null || provider.leadFieldSettings!.customFields.isEmpty) {
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
              _buildTextField(_addressCtrl, 'Address', Icons.location_on_rounded),
              _buildTextField(_cityCtrl, 'City', Icons.location_city_rounded),
              _buildTextField(_requirementsCtrl, 'Requirements', Icons.list_alt_rounded, maxLines: 3),
              _buildTextField(_notesCtrl, 'Notes', Icons.note_rounded, maxLines: 3),
            ]),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary));
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
        children: children.map((child) => Padding(padding: const EdgeInsets.only(bottom: 12), child: child)).toList(),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboard, int maxLines = 1, bool required = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
      validator: required ? (v) => v == null || v.isEmpty ? '$label is required' : null : null,
    );
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
        decoration: const InputDecoration(labelText: 'Enquiry Date', prefixIcon: Icon(Icons.event_rounded, size: 20)),
        child: Text(DateFormat('MMM d, yyyy').format(_sinceDate), style: GoogleFonts.inter(fontSize: 14)),
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
            child: Text('No products available', style: GoogleFonts.inter(color: AppTheme.textTertiary)),
          );
        }
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
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: provider.products.map((product) {
              final selected = _selectedProductIds.contains(product.id);
              return FilterChip(
                label: Text(product.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : AppTheme.textSecondary)),
                selected: selected,
                selectedColor: AppTheme.primaryBlue,
                checkmarkColor: Colors.white,
                backgroundColor: AppTheme.surfaceGrey,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: selected ? AppTheme.primaryBlue : const Color(0xFFF3F4F6), width: 1.5)),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedProductIds.add(product.id);
                    } else {
                      _selectedProductIds.remove(product.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStage == null) {
      SnackbarHelper.showError(context, 'Please select a stage');
      return;
    }

    final business = {
      'business': _businessNameCtrl.text.trim(),
      'name': _contactNameCtrl.text.trim(),
      'title': _selectedTitle,
      'designation': _designationCtrl.text.trim(),
      'mobile': _mobileCtrl.text.trim(),
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
        customFieldsData[field.key] = _getCustomFieldCtrl(field.key).text.trim();
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
            tags: widget.lead!.tags,
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
            tags: {},
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'AI Smart Paste',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste business information (email, phone, website, etc.) and our AI will automatically extract and fill the form fields.',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Paste business details here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (text) {
                // AI processing logic would go here
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              SnackbarHelper.showSuccess(context, 'Information extracted and filled!');
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: Text(
              'Extract & Fill',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
