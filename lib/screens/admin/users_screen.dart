import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/admin_user.dart';
import '../../providers/role_provider.dart';
import '../../providers/user_admin_provider.dart';
import '../widgets/empty_state.dart';
import 'admin_add_button.dart';
import 'admin_confirm_dialog.dart';
import 'admin_pagination_bar.dart';
import 'user_form_sheet.dart';

/// Administration → Users. Lists the org's members and lets an admin add,
/// re-role or remove them.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const int _pageSize = 10;
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Roles are needed for the create/edit dropdown.
      context.read<RoleProvider>().load();
      context.read<UserAdminProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addUser() async {
    final roleProvider = context.read<RoleProvider>();
    if (roleProvider.roles.isEmpty) await roleProvider.load();
    if (!mounted) return;
    await UserFormSheet.show(context);
  }

  Future<void> _editUser(AdminUser user) async {
    await UserFormSheet.show(context, existing: user);
  }

  Future<void> _confirmDelete(AdminUser user) async {
    final confirmed = await AdminConfirmDialog.show(
      context,
      icon: Icons.person_remove_alt_1_rounded,
      title: 'Remove user?',
      message:
          '${user.name} will lose access to this organization. This can\'t be undone.',
      confirmLabel: 'Remove',
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<UserAdminProvider>();
    try {
      await provider.deleteUser(user.id);
      if (mounted) SnackbarHelper.showSuccess(context, 'User removed');
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Users',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AdminAddButton(label: 'Add User', onTap: _addUser),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Consumer<UserAdminProvider>(
        builder: (context, provider, _) {
          final users = provider.filtered(_query);
          // Clamp the page in case deletes/filters shrank the list.
          final pageCount =
              users.isEmpty ? 1 : ((users.length - 1) ~/ _pageSize) + 1;
          if (_page > pageCount) _page = pageCount;
          final start = (_page - 1) * _pageSize;
          final pageItems = users.length <= start
              ? const <AdminUser>[]
              : users.sublist(start, math.min(start + _pageSize, users.length));

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
              if (users.isNotEmpty)
                AdminPaginationBar(
                  totalItems: users.length,
                  currentPage: _page,
                  pageSize: _pageSize,
                  unitLabel: 'user',
                  onPageChanged: (p) => setState(() => _page = p),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(UserAdminProvider provider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Team Members',
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
                  '${provider.count} total',
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
              hintText: 'Search by name, email or role',
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

  Widget _buildBody(UserAdminProvider provider, List<AdminUser> users) {
    if (provider.isLoading && !provider.loadedOnce) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (provider.error != null && provider.users.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Couldn\'t load users',
            subtitle: provider.error!,
            actionLabel: 'Retry',
            onAction: () => provider.load(refresh: true),
          ),
        ],
      );
    }
    if (users.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          EmptyState(
            icon: _query.isEmpty
                ? Icons.group_outlined
                : Icons.search_off_rounded,
            title: _query.isEmpty ? 'No users yet' : 'No matches',
            subtitle: _query.isEmpty
                ? 'Add your first team member to get started.'
                : 'Try a different search term.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _UserCard(
        user: users[i],
        onEdit: () => _editUser(users[i]),
        onDelete: () => _confirmDelete(users[i]),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.roleName);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9ECF1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue,
                      AppTheme.accentCyan,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  user.initial,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _roleBadge(user.roleName, roleColor),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (user.mobile != null && user.mobile!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.phone_outlined,
                    size: 15, color: AppTheme.textTertiary),
                const SizedBox(width: 6),
                Text(
                  user.mobile!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionButton(
                icon: Icons.edit_outlined,
                label: 'Change role',
                color: AppTheme.primaryBlue,
                onTap: onEdit,
              ),
              const SizedBox(width: 4),
              _actionButton(
                icon: Icons.delete_outline_rounded,
                label: 'Remove',
                color: const Color(0xFFEF4444),
                // Protect the last-standing admin from self-lockout.
                onTap: user.isAdmin ? null : onDelete,
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

  Widget _roleBadge(String role, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return const Color(0xFFEF4444);
      case 'AGENCY':
        return const Color(0xFF8B5CF6);
      case 'USER':
        return AppTheme.primaryBlue;
      default:
        return const Color(0xFF10B981);
    }
  }
}
