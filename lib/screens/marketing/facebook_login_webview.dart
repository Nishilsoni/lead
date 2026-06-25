import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants/app_theme.dart';
import '../../core/constants/facebook_config.dart';

/// In-app Facebook OAuth login. Loads the OAuth dialog, watches navigation for
/// the redirect URI, and pops with the captured short-lived `access_token`
/// (or null if the user cancelled / login failed).
class FacebookLoginWebView extends StatefulWidget {
  const FacebookLoginWebView({super.key});

  @override
  State<FacebookLoginWebView> createState() => _FacebookLoginWebViewState();
}

class _FacebookLoginWebViewState extends State<FacebookLoginWebView> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _done = false; // guards against popping twice
  String? _error;

  /// A real mobile-Safari user agent. Facebook refuses to render its login
  /// dialog inside a default WKWebView/Android WebView (it detects the embedded
  /// "wv" UA and serves a blank page), so we present as Mobile Safari.
  static const String _mobileSafariUa =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 '
      'Mobile/15E148 Safari/604.1';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_mobileSafariUa)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted && _error != null) setState(() => _error = null);
            _maybeCapture(url);
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _maybeCapture(url);
          },
          onProgress: (progress) {
            if (mounted && progress >= 100 && _loading) {
              setState(() => _loading = false);
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // Ignore errors for sub-frames / non-main-frame resources.
            if (error.isForMainFrame == false) return;
            if (_done || !mounted) return;
            setState(() {
              _loading = false;
              _error = error.description.isNotEmpty
                  ? error.description
                  : 'Could not load the Facebook login page.';
            });
          },
          onNavigationRequest: (request) {
            if (_maybeCapture(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(FacebookConfig.oauthUrl());
  }

  void _reload() {
    setState(() {
      _error = null;
      _loading = true;
    });
    _controller.loadRequest(FacebookConfig.oauthUrl());
  }

  /// If [url] is the OAuth redirect, extract the token (or error) and pop.
  /// Returns true when the URL was the redirect (so navigation can be stopped).
  bool _maybeCapture(String url) {
    if (_done) return false;
    if (!url.startsWith(FacebookConfig.redirectUri)) return false;

    final uri = Uri.parse(url);
    // Implicit flow returns the token in the URL fragment:
    //   .../login_success.html#access_token=XXX&expires_in=...
    // Errors come back as query params: ?error=access_denied&...
    final fragment = uri.fragment;
    final params = <String, String>{
      ...uri.queryParameters,
      if (fragment.isNotEmpty) ...Uri.splitQueryString(fragment),
    };

    final token = params['access_token'];
    if (token != null && token.isNotEmpty) {
      _finish(token);
      return true;
    }
    if (params.containsKey('error')) {
      _finish(null);
      return true;
    }
    return false;
  }

  void _finish(String? token) {
    if (_done) return;
    _done = true;
    if (mounted) Navigator.of(context).pop(token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
          onPressed: () => _finish(null),
        ),
        title: Text(
          'Connect Facebook',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Color(0xFFE5E7EB),
              color: Color(0xFF1877F2),
            ),
          if (_error != null) _buildError(),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Positioned.fill(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 14),
            Text(
              'Couldn’t load Facebook login',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => _finish(null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _reload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
