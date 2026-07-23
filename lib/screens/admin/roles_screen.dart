import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/role.dart';
import '../../providers/role_provider.dart';
import '../widgets/empty_state.dart';
import 'admin_add_button.dart';
import 'admin_confirm_dialog.dart';
import 'admin_pagination_bar.dart';
import 'role_form_sheet.dart';

/// Administration → Roles. Lists roles and their permission counts, and lets an
/// admin create, edit or delete non-default roles.
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  static const int _pageSize = 10;
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoleProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _createRole() async {
    final provider = context.read<RoleProvider>();
    if (provider.catalog.isEmpty) await provider.load();
    if (!mounted) return;
    await RoleFormSheet.show(context);
  }

  Future<void> _editRole(Role role) async {
    await RoleFormSheet.show(context, existing: role);
  }

  Future<void> _confirmDelete(Role role) async {
    final confirmed = await AdminConfirmDialog.show(
      context,
      icon: Icons.shield_outlined,
      title: 'Delete role?',
      message:
          'The “${role.name}” role will be permanently removed. Users assigned to it must be re-assigned.',
      confirmLabel: 'Delete',
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<RoleProvider>();
    try {
      await provider.deleteRole(role.id);
      if (mounted) SnackbarHelper.showSuccess(context, 'Role deleted');
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e.toString());
    }
  }

  List<Role> _filtered(List<Role> roles) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return roles;
    return roles
        .where((r) =>
            r.name.toLowerCase().contains(q) ||
            r.description.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Roles',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AdminAddButton(label: 'Create Role', onTap: _createRole),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Consumer<RoleProvider>(
        builder: (context, provider, _) {
          final roles = _filtered(provider.roles);
          final pageCount =
              roles.isEmpty ? 1 : ((roles.length - 1) ~/ _pageSize) + 1;
          if (_page > pageCount) _page = pageCount;
          final start = (_page - 1) * _pageSize;
          final pageItems = roles.length <= start
              ? const <Role>[]
              : roles.sublist(start, math.min(start + _pageSize, roles.length));

          return Column(
            children: [
              _buildHeader(provider),
              Expanded(
                child: RefreshIndicator(
                  color: AppTheme.primaryBlue,
                  onRefresh: () => provider.load(refresh: true),
                  child: _buildBody(provider, pageItems),
                ),
              ),
              if (roles.isNotEmpty)
                AdminPaginationBar(
                  totalItems: roles.length,
                  currentPage: _page,
                  pageSize: _pageSize,
                  unitLabel: 'role',
                  onPageChanged: (p) => setState(() => _page = p),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(RoleProvider provider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Access Roles',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${provider.roles.length} total',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() {
              _query = v;
              _page = 1;
            }),
            decoration: InputDecoration(
              hintText: 'Search by name',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _query = '';
                          _page = 1;
                        });
                      },
                    ),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(RoleProvider provider, List<Role> roles) {
    if (provider.isLoading && !provider.loadedOnce) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (provider.error != null && provider.roles.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Couldn\'t load roles',
            subtitle: provider.error!,
            actionLabel: 'Retry',
            onAction: () => provider.load(refresh: true),
          ),
        ],
      );
    }
    if (roles.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          EmptyState(
            icon: _query.isEmpty
                ? Icons.shield_outlined
                : Icons.search_off_rounded,
            title: _query.isEmpty ? 'No roles yet' : 'No matches',
            subtitle: _query.isEmpty
                ? 'Create a role to define what your team can access.'
                : 'Try a different search term.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: roles.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _RoleCard(
        role: roles[i],
        onEdit: () => _editRole(roles[i]),
        onDelete: () => _confirmDelete(roles[i]),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final Role role;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoleCard({
    required this.role,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9ECF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.shield_outlined,
                    color: AppTheme.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          role.name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (role.isDefault)
                          _badge('Default', AppTheme.primaryBlue),
                        if (role.isAssignedOnly)
                          _badge('Assigned Only', const Color(0xFFF59E0B)),
                      ],
                    ),
                    if (role.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        role.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.vpn_key_outlined,
                  size: 15, color: AppTheme.textTertiary),
              const SizedBox(width: 6),
              Text(
                '${role.permissionCount} permission${role.permissionCount == 1 ? '' : 's'} assigned',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              _actionButton(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: AppTheme.primaryBlue,
                onTap: onEdit,
              ),
              const SizedBox(width: 4),
              _actionButton(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: const Color(0xFFEF4444),
                // Built-in roles can't be deleted.
                onTap: role.isDefault ? null : onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon,
          size: 17, color: disabled ? AppTheme.textTertiary : color),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: disabled ? AppTheme.textTertiary : color,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
