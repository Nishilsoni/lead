import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/role.dart';
import '../../providers/role_provider.dart';
import 'permission_matrix_screen.dart';

/// Bottom sheet for creating a new role or editing an existing one.
///
/// The API's UpdateRole payload has no `name` field, so a role's name is fixed
/// after creation — we show it read-only in edit mode. "Assigned Data Only" is
/// surfaced as a dedicated switch and, when enabled, its permission id is folded
/// into the submitted permission set.
class RoleFormSheet extends StatefulWidget {
  final Role? existing;
  const RoleFormSheet({super.key, this.existing});

  static Future<bool?> show(BuildContext context, {Role? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoleFormSheet(existing: existing),
    );
  }

  @override
  State<RoleFormSheet> createState() => _RoleFormSheetState();
}

class _RoleFormSheetState extends State<RoleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late Set<int> _selectedModuleIds;
  bool _assignedOnly = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final catalog = context.read<RoleProvider>().catalog;
    if (_isEdit) {
      final role = widget.existing!;
      _nameCtrl.text = role.name;
      _descCtrl.text = role.description;
      _assignedOnly = role.isAssignedOnly;
      // Keep only ids that live in the matrix; the assigned-only id is tracked
      // by its own switch.
      final assignedId = catalog.assignedOnly?.id;
      _selectedModuleIds = role.permissionIds
          .where((id) => id != assignedId)
          .toSet();
    } else {
      _selectedModuleIds = {};
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _openMatrix() async {
    final catalog = context.read<RoleProvider>().catalog;
    if (catalog.isEmpty) {
      SnackbarHelper.showError(context, 'Permissions are still loading.');
      return;
    }
    final result = await PermissionMatrixScreen.show(
      context,
      catalog: catalog,
      selected: _selectedModuleIds,
    );
    if (result != null) setState(() => _selectedModuleIds = result);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final roleProvider = context.read<RoleProvider>();
    final catalog = roleProvider.catalog;

    final ids = {..._selectedModuleIds};
    final assignedId = catalog.assignedOnly?.id;
    if (_assignedOnly && assignedId != null) {
      ids.add(assignedId);
    }

    if (ids.isEmpty) {
      SnackbarHelper.showError(
          context, 'Select at least one permission for this role.');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await roleProvider.updateRole(
          id: widget.existing!.id,
          description: _descCtrl.text.trim(),
          permissionIds: ids.toList(),
        );
      } else {
        await roleProvider.createRole(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          permissionIds: ids.toList(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      SnackbarHelper.showSuccess(
        context,
        _isEdit ? 'Role updated' : 'Role created successfully',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarHelper.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final catalog = context.watch<RoleProvider>().catalog;
    final selectedCount =
        _selectedModuleIds.length + (_assignedOnly ? 1 : 0);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: AppTheme.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEdit ? 'Edit Role' : 'Create New Role',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _label('Role Name', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                enabled: !_isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('e.g. Manager, Sales', Icons.badge_outlined),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Role name is required'
                    : null,
              ),
              if (_isEdit) ...[
                const SizedBox(height: 6),
                Text(
                  'A role\'s name can\'t be changed after creation.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _label('Description', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: _dec('Describe what this role can do', null),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : null,
              ),
              if (catalog.assignedOnly != null) ...[
                const SizedBox(height: 16),
                _buildAssignedOnly(),
              ],
              const SizedBox(height: 20),
              _label('Permissions', required: true),
              const SizedBox(height: 8),
              _buildPermissionsCard(selectedCount),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEdit ? 'Save Changes' : 'Create Role'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignedOnly() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned Data Only',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Restrict users in this role to only the records assigned to them.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _assignedOnly,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (v) => setState(() => _assignedOnly = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(int selectedCount) {
    final configured = selectedCount > 0;
    return InkWell(
      onTap: _openMatrix,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: configured
              ? AppTheme.primaryBlue.withValues(alpha: 0.06)
              : AppTheme.surfaceGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: configured
                ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: configured
                    ? AppTheme.primaryBlue.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                configured
                    ? Icons.verified_user_rounded
                    : Icons.shield_outlined,
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
                    configured
                        ? '$selectedCount permission${selectedCount == 1 ? '' : 's'} selected'
                        : 'No permissions configured',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to select and configure access',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) => RichText(
        text: TextSpan(
          text: text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
          children: required
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                ]
              : null,
        ),
      );

  InputDecoration _dec(String hint, IconData? icon) => InputDecoration(
        hintText: hint,
        prefixIcon:
            icon == null ? null : Icon(icon, size: 20, color: AppTheme.textTertiary),
      );
}
