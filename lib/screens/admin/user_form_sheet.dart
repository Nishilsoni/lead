import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/country_codes.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/admin_user.dart';
import '../../models/role.dart';
import '../../providers/role_provider.dart';
import '../../providers/user_admin_provider.dart';

/// Bottom sheet for creating a new user, or (when [existing] is set) changing
/// an existing user's role. The API only allows the role to be edited after
/// creation, so in edit mode the identity fields are shown read-only.
class UserFormSheet extends StatefulWidget {
  final AdminUser? existing;
  const UserFormSheet({super.key, this.existing});

  static Future<bool?> show(BuildContext context, {AdminUser? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserFormSheet(existing: existing),
    );
  }

  @override
  State<UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  CountryCode _country = kCountryCodes.first;
  String? _roleId;
  bool _obscure = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final roles = context.read<RoleProvider>().assignableRoles;
    if (_isEdit) {
      _nameCtrl.text = widget.existing!.name;
      _emailCtrl.text = widget.existing!.email;
      final role = roles.firstWhere(
        (r) => r.name.toUpperCase() == widget.existing!.roleName.toUpperCase(),
        orElse: () => roles.isNotEmpty
            ? roles.first
            : const Role(
                id: '', name: '', description: '', permissions: [], isDefault: false),
      );
      _roleId = role.id.isNotEmpty ? role.id : null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roleId == null) {
      SnackbarHelper.showError(context, 'Please select a role.');
      return;
    }

    final userProvider = context.read<UserAdminProvider>();
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await userProvider.updateUserRole(
          userId: widget.existing!.id,
          roleId: _roleId!,
        );
      } else {
        final mobile = _mobileCtrl.text.trim();
        await userProvider.createUser(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          mobile: mobile.isEmpty ? null : '${_country.dialCode}$mobile',
          password: _passwordCtrl.text,
          roleId: _roleId!,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      SnackbarHelper.showSuccess(
        context,
        _isEdit ? 'User role updated' : 'User created successfully',
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
    final roles = context.watch<RoleProvider>().assignableRoles;

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
                    child: Icon(
                      _isEdit ? Icons.manage_accounts_rounded : Icons.person_add_alt_1_rounded,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEdit ? 'Edit User Role' : 'Create New User',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _label('Name', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                enabled: !_isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Full name', Icons.person_outline_rounded),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              _label('Email', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtrl,
                enabled: !_isEdit,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('name@example.com', Icons.mail_outline_rounded),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Email is required';
                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
                  return ok ? null : 'Enter a valid email';
                },
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 16),
                _label('Mobile'),
                const SizedBox(height: 8),
                _buildMobileField(),
                const SizedBox(height: 16),
                _label('Password', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: _dec('At least 6 characters', Icons.lock_outline_rounded)
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                        color: AppTheme.textTertiary,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Use at least 6 characters';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              _label('Role', required: true),
              const SizedBox(height: 8),
              _buildRoleDropdown(roles),
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
                      : Text(_isEdit ? 'Save Changes' : 'Create User'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileField() {
    return Row(
      children: [
        GestureDetector(
          onTap: _pickCountry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Text(_country.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  _country.dialCode,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Icon(Icons.arrow_drop_down_rounded, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: _mobileCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: _dec('Phone number', Icons.phone_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown(List<Role> roles) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: _roleId,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          hint: Text(
            'Select user role',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary),
          ),
          items: roles
              .map(
                (r) => DropdownMenuItem(
                  value: r.id,
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        r.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (r.isDefault) ...[
                        const SizedBox(width: 8),
                        _tinyBadge('Default'),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _roleId = v),
        ),
      ),
    );
  }

  Widget _tinyBadge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryBlue,
          ),
        ),
      );

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

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textTertiary),
      );

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CountryPickerSheet(),
    );
    if (selected != null) setState(() => _country = selected);
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = _query.isEmpty
        ? kCountryCodes
        : kCountryCodes
            .where((c) =>
                c.name.toLowerCase().contains(_query.toLowerCase()) ||
                c.dialCode.contains(_query))
            .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search country...',
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, i) {
                final c = results[i];
                return ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(c.name, style: GoogleFonts.inter(fontSize: 14)),
                  trailing: Text(
                    c.dialCode,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
