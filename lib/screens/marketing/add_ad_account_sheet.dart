import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_theme.dart';
import '../../core/facebook_connection.dart';
import '../../models/meta_account.dart';
import '../../services/meta_service.dart';
import 'facebook_login_webview.dart';

const Color _fbBlue = Color(0xFF1877F2);

enum _Step { login, select, complete }

/// Three-step "Add Ad Accounts" flow shown as a bottom sheet:
///   1. Login    — open Facebook OAuth in a WebView, capture the user token
///   2. Select   — list the user's ad accounts, let them choose
///   3. Complete — POST selections to the backend, show success
///
/// Pops with the number of accounts successfully connected (0 / null = none).
class AddAdAccountSheet extends StatefulWidget {
  const AddAdAccountSheet({super.key});

  @override
  State<AddAdAccountSheet> createState() => _AddAdAccountSheetState();
}

class _AddAdAccountSheetState extends State<AddAdAccountSheet> {
  final MetaService _service = MetaService();

  _Step _step = _Step.login;
  bool _busy = false;
  String? _error;

  String? _userToken;
  List<FacebookAdAccountOption> _options = [];
  final Set<String> _selected = {};
  int _connectedCount = 0;

  @override
  void initState() {
    super.initState();
    // Reuse a login already cached by the other Facebook submodule this session.
    final cached = FacebookConnection.instance.userToken;
    if (cached != null) {
      _userToken = cached;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions(cached));
    }
  }

  // ── Step 1: Facebook login ─────────────────────────────────────────

  Future<void> _startLogin() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final token = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const FacebookLoginWebView()),
    );

    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() {
        _busy = false;
        _error = 'Login was cancelled.';
      });
      return;
    }
    _userToken = token;
    FacebookConnection.instance.setUserToken(token);
    await _loadOptions(token);
  }

  /// Fetch the user's selectable ad accounts and advance to the Select step.
  Future<void> _loadOptions(String token) async {
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
        _step = _Step.select;
      });
    }
    try {
      final options = await _service.fetchAvailableAdAccounts(token);
      if (!mounted) return;
      setState(() {
        _options = options;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  // ── Step 3: connect selected accounts ──────────────────────────────

  Future<void> _connectSelected() async {
    if (_selected.isEmpty || _userToken == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    var connected = 0;
    final failures = <String>[];
    for (final id in _selected) {
      try {
        await _service.addAdAccount(userToken: _userToken!, adAccountId: id);
        connected++;
      } catch (e) {
        final name = _options
            .firstWhere((o) => o.adAccountId == id,
                orElse: () => FacebookAdAccountOption(
                    adAccountId: id,
                    name: id,
                    currency: '',
                    timezone: '',
                    accountStatus: 0))
            .name;
        failures.add(name);
      }
    }

    if (!mounted) return;
    setState(() {
      _connectedCount = connected;
      _busy = false;
      _step = _Step.complete;
      _error = failures.isEmpty
          ? null
          : 'Could not connect: ${failures.join(', ')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            _buildHeader(),
            _buildStepper(),
            const Divider(height: 1),
            Flexible(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _fbBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.facebook_rounded, color: _fbBlue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Ad Accounts',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Connect your Facebook ad accounts to view campaign data',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: AppTheme.textSecondary,
            onPressed: () => Navigator.pop(context, _connectedCount),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          _stepNode(1, 'Login', _Step.login),
          _stepConnector(_step.index >= _Step.select.index),
          _stepNode(2, 'Select', _Step.select),
          _stepConnector(_step.index >= _Step.complete.index),
          _stepNode(3, 'Complete', _Step.complete),
        ],
      ),
    );
  }

  Widget _stepNode(int number, String label, _Step step) {
    final reached = _step.index >= step.index;
    final isPast = _step.index > step.index;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: reached ? _fbBlue : const Color(0xFFE5E7EB),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isPast
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : Text(
                    '$number',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: reached ? Colors.white : AppTheme.textTertiary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: reached ? _fbBlue : AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _stepConnector(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: active ? _fbBlue : const Color(0xFFE5E7EB),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.login:
        return _buildLoginStep();
      case _Step.select:
        return _buildSelectStep();
      case _Step.complete:
        return _buildCompleteStep();
    }
  }

  // ── Step 1 UI ──────────────────────────────────────────────────────

  Widget _buildLoginStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 40, color: _fbBlue),
          const SizedBox(height: 16),
          Text(
            'Connect Facebook',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in with Facebook and grant ads access so we can fetch your ad accounts.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _errorBox(_error!),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _startLogin,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.facebook_rounded, size: 20),
              label: Text(
                _busy ? 'Please wait…' : 'Continue with Facebook',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _fbBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2 UI ──────────────────────────────────────────────────────

  Widget _buildSelectStep() {
    if (_busy && _options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 40, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final t = _userToken;
                if (t != null) _loadOptions(t);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No ad accounts found on this Facebook profile.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Select the ad accounts you want to connect:',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: _options.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _accountOption(_options[i]),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _errorBox(_error!),
          ),
        _buildSelectActions(),
      ],
    );
  }

  Widget _accountOption(FacebookAdAccountOption account) {
    final checked = _selected.contains(account.adAccountId);
    return InkWell(
      onTap: () => setState(() {
        if (checked) {
          _selected.remove(account.adAccountId);
        } else {
          _selected.add(account.adAccountId);
        }
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: checked ? _fbBlue.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: checked ? _fbBlue : Colors.grey.shade200,
            width: checked ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            _checkbox(checked),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ID: ${account.adAccountId.replaceFirst('act_', '')}'
                    '${account.currency.isNotEmpty ? ' • ${account.currency}' : ''}'
                    '${account.timezone.isNotEmpty ? ' • ${account.timezone}' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              account.isActive ? 'Active' : 'Inactive',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: account.isActive
                    ? const Color(0xFF10B981)
                    : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkbox(bool checked) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? _fbBlue : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? _fbBlue : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }

  Widget _buildSelectActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, _connectedCount),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (_selected.isEmpty || _busy) ? null : _connectSelected,
              style: ElevatedButton.styleFrom(
                backgroundColor: _fbBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _selected.isEmpty
                          ? 'Connect Accounts'
                          : 'Connect ${_selected.length} Account${_selected.length == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3 UI ──────────────────────────────────────────────────────

  Widget _buildCompleteStep() {
    final success = _connectedCount > 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: (success ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 36,
              color: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            success ? 'Successfully connected' : 'Nothing connected',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            success
                ? '$_connectedCount ad account${_connectedCount == 1 ? '' : 's'} '
                    'connected to your organization.'
                : 'No ad accounts were connected.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _errorBox(_error!),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _connectedCount),
              style: ElevatedButton.styleFrom(
                backgroundColor: _fbBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFFEF4444)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
