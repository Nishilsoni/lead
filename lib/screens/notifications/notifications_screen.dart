import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';

/// Full-screen notification panel — modern card list with a header that carries
/// the three actions: refresh, mark all read, delete all.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Consumer<NotificationProvider>(
          builder: (context, p, _) => Row(
            children: [
              Text(
                'Notifications',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (p.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${p.unreadCount}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, p, _) {
              final hasItems = p.items.isNotEmpty;
              return Row(
                children: [
                  // Refresh
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppTheme.textSecondary),
                    onPressed: p.isLoading
                        ? null
                        : () => p.load(refresh: true),
                  ),
                  // Mark all read
                  IconButton(
                    tooltip: 'Mark all read',
                    icon: Icon(
                      Icons.done_all_rounded,
                      color: hasItems && p.hasUnread
                          ? AppTheme.textSecondary
                          : AppTheme.textTertiary,
                    ),
                    onPressed: hasItems && p.hasUnread
                        ? () async {
                            try {
                              await p.markAllRead();
                              if (context.mounted) {
                                SnackbarHelper.showSuccess(
                                    context, 'All notifications marked read');
                              }
                            } catch (_) {
                              if (context.mounted) {
                                SnackbarHelper.showError(
                                    context, 'Could not mark all read');
                              }
                            }
                          }
                        : null,
                  ),
                  // Delete all
                  IconButton(
                    tooltip: 'Delete all',
                    icon: Icon(
                      Icons.delete_sweep_rounded,
                      color: hasItems
                          ? const Color(0xFFEF4444)
                          : AppTheme.textTertiary,
                    ),
                    onPressed:
                        hasItems ? () => _confirmDeleteAll(context, p) : null,
                  ),
                  const SizedBox(width: 4),
                ],
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, p, _) {
          if (p.isLoading && p.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (p.error != null && p.items.isEmpty) {
            return _ErrorState(message: p.error!, onRetry: () => p.load(refresh: true));
          }
          if (p.items.isEmpty) {
            return _EmptyState(onRefresh: () => p.load(refresh: true));
          }
          return RefreshIndicator(
            onRefresh: () => p.load(refresh: true),
            color: AppTheme.primaryBlue,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              itemCount: p.items.length,
              separatorBuilder: (_, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = p.items[i];
                return Dismissible(
                  key: ValueKey('notif_${n.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    try {
                      await p.deleteOne(n.id);
                    } catch (_) {
                      if (context.mounted) {
                        SnackbarHelper.showError(
                            context, 'Could not delete notification');
                      }
                    }
                  },
                  child: _NotificationCard(
                    notification: n,
                    read: p.isRead(n),
                    onTap: () => p.markRead(n.id).catchError((_) {}),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteAll(
      BuildContext context, NotificationProvider p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete all notifications?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          'This clears every notification from your list. This can\'t be undone.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete all',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await p.clearAll();
        if (context.mounted) {
          SnackbarHelper.showSuccess(context, 'All notifications cleared');
        }
      } catch (_) {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Could not clear notifications');
        }
      }
    }
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool read;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.read,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = notification.accent;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: read ? const Color(0xFFE9EDF3) : accent.withValues(alpha: 0.35),
              width: 1,
            ),
            color: read ? Colors.white : accent.withValues(alpha: 0.04),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon chip
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(notification.icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight:
                                  read ? FontWeight.w600 : FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (!read) ...[
                          const SizedBox(width: 8),
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (notification.message.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        notification.message,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.4,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[time.month - 1]} ${time.day}';
  }
}

// ── Empty / error states ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryBlue,
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.28),
          Icon(Icons.notifications_off_rounded,
              size: 52, color: AppTheme.textTertiary),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'You\'re all caught up',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'No notifications right now',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 44, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
