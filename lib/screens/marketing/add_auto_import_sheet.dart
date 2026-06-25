import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_theme.dart';
import '../../core/facebook_connection.dart';
import '../../models/facebook_lead_import.dart';
import '../../services/meta_service.dart';
import 'facebook_login_webview.dart';

const Color _fbBlue = Color(0xFF1877F2);

enum _Step { login, page, form, complete }

/// Four-step "Import Facebook Leads" flow shown as a bottom sheet:
///   1. Login   — Facebook OAuth (skipped if a session login is already cached)
///   2. Page    — choose a page the user manages (Graph /me/accounts)
///   3. Form    — choose a Lead Ad form on that page (Graph leadgen_forms)
///   4. Complete— save the page+form connection on the backend
///
/// Pops with `true` when a connection was saved.
class AddAutoImportSheet extends StatefulWidget {
  const AddAutoImportSheet({super.key});

  @override
  State<AddAutoImportSheet> createState() => _AddAutoImportSheetState();
}

class _AddAutoImportSheetState extends State<AddAutoImportSheet> {
  final MetaService _service = MetaService();

  _Step _step = _Step.login;
  bool _busy = false;
  String? _error;

  String? _userToken;
  List<FacebookPage> _pages = [];
  FacebookPage? _selectedPage;
  List<FacebookLeadForm> _forms = [];
  FacebookLeadForm? _selectedForm;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    // Reuse a cached login from the other Facebook submodule if available.
    final cached = FacebookConnection.instance.userToken;
    if (cached != null) {
      _userToken = cached;
      // Defer to first frame so we can show a spinner while pages load.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPages());
    }
  }

  // ── Step 1: login ──────────────────────────────────────────────────

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
    await _loadPages();
  }

  // ── Step 2: pages ──────────────────────────────────────────────────

  Future<void> _loadPages() async {
    final token = _userToken;
    if (token == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _step = _Step.page;
    });
    try {
      final pages = await _service.fetchPages(token);
      if (!mounted) return;
      setState(() {
        _pages = pages;
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

  Future<void> _choosePage(FacebookPage page) async {
    setState(() {
      _selectedPage = page;
      _busy = true;
      _error = null;
      _step = _Step.form;
      _forms = [];
      _selectedForm = null;
    });
    try {
      final forms = await _service.fetchLeadForms(page.id, page.accessToken);
      if (!mounted) return;
      setState(() {
        _forms = forms;
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

  // ── Step 4: save ───────────────────────────────────────────────────

  Future<void> _connect() async {
    final token = _userToken;
    final page = _selectedPage;
    final form = _selectedForm;
    if (token == null || page == null || form == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.connectAutoImport(userToken: token, page: page, form: form);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _busy = false;
        _step = _Step.complete;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────

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
            _handle(),
            _header(),
            _stepper(),
            const Divider(height: 1),
            Flexible(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _handle() {
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

  Widget _header() {
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
                  'Import Facebook Leads',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Connect your Facebook page to automatically import leads',
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
            onPressed: () => Navigator.pop(context, _saved),
          ),
        ],
      ),
    );
  }

  Widget _stepper() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Row(
        children: [
          _node(1, 'Login', _Step.login),
          _connector(_step.index >= _Step.page.index),
          _node(2, 'Page', _Step.page),
          _connector(_step.index >= _Step.form.index),
          _node(3, 'Form', _Step.form),
          _connector(_step.index >= _Step.complete.index),
          _node(4, 'Done', _Step.complete),
        ],
      ),
    );
  }

  Widget _node(int number, String label, _Step step) {
    final reached = _step.index >= step.index;
    final isPast = _step.index > step.index;
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: reached ? _fbBlue : const Color(0xFFE5E7EB),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isPast
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                : Text(
                    '$number',
                    style: GoogleFonts.inter(
                      fontSize: 12,
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
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: reached ? _fbBlue : AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _connector(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: active ? _fbBlue : const Color(0xFFE5E7EB),
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case _Step.login:
        return _loginStep();
      case _Step.page:
        return _pageStep();
      case _Step.form:
        return _formStep();
      case _Step.complete:
        return _completeStep();
    }
  }

  // ── Step 1 UI ──────────────────────────────────────────────────────

  Widget _loginStep() {
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
            'Sign in with Facebook to import leads from your Facebook Lead Ads.',
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
                _busy ? 'Please wait…' : 'Log in With Facebook',
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

  Widget _pageStep() {
    if (_busy && _pages.isEmpty) return _loading('Loading your pages…');
    if (_error != null && _pages.isEmpty) {
      return _stepError(_error!, _loadPages);
    }
    if (_pages.isEmpty) {
      return _emptyState('No Facebook pages found on this account.');
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepHint('Choose the page to import leads from:'),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _pages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final page = _pages[i];
              return _selectRow(
                title: page.name,
                subtitle: page.category.isNotEmpty ? page.category : 'Page',
                selected: _selectedPage?.id == page.id,
                onTap: () => _choosePage(page),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Step 3 UI ──────────────────────────────────────────────────────

  Widget _formStep() {
    if (_busy && _forms.isEmpty) return _loading('Loading lead forms…');
    if (_error != null && _forms.isEmpty) {
      return _stepError(_error!, () {
        final page = _selectedPage;
        if (page != null) _choosePage(page);
      });
    }
    if (_forms.isEmpty) {
      return _emptyState('No lead forms found on "${_selectedPage?.name ?? ''}".');
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepHint('Choose a lead form on "${_selectedPage?.name ?? ''}":'),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: _forms.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final form = _forms[i];
              return _selectRow(
                title: form.name,
                subtitle: form.status.isNotEmpty ? form.status : 'Form',
                selected: _selectedForm?.id == form.id,
                trailingActive: form.isActive,
                onTap: () => setState(() => _selectedForm = form),
              );
            },
          ),
        ),
        if (_error != null && _forms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _errorBox(_error!),
          ),
        _formActions(),
      ],
    );
  }

  Widget _formActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() {
                _step = _Step.page;
                _error = null;
              }),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Back',
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
              onPressed: (_selectedForm == null || _busy) ? null : _connect,
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
                      'Connect',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 4 UI ──────────────────────────────────────────────────────

  Widget _completeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 36, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 16),
          Text(
            'Successfully connected',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Leads from "${_selectedForm?.name ?? ''}" on "${_selectedPage?.name ?? ''}" '
            'will now import automatically.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
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

  // ── Shared bits ────────────────────────────────────────────────────

  Widget _stepHint(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _selectRow({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool? trailingActive,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _fbBlue.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _fbBlue : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _fbBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.facebook_rounded,
                  color: _fbBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailingActive != null) ...[
              const SizedBox(width: 8),
              Text(
                trailingActive ? 'Active' : 'Inactive',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: trailingActive
                      ? const Color(0xFF10B981)
                      : AppTheme.textTertiary,
                ),
              ),
            ] else if (selected)
              const Icon(Icons.check_circle_rounded, color: _fbBlue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _loading(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(
            text,
            style: GoogleFonts.inter(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _stepError(String message, VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 40, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
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
                  fontSize: 12.5, color: const Color(0xFFB91C1C)),
            ),
          ),
        ],
      ),
    );
  }
}
