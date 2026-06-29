/// Facebook OAuth configuration for the in-app "Add Ad Account" login flow.
///
/// The login uses Facebook's OAuth *implicit* flow inside a WebView: we open
/// the OAuth dialog, the user logs in and grants ad permissions, and Facebook
/// redirects back with a short-lived `access_token` in the URL fragment. That
/// token is sent to our backend (`POST /v1/meta/ad-account`) which exchanges it
/// for a long-lived one server-side.
///
/// ──────────────────────────────────────────────────────────────────────────
/// SETUP (one-time): fill in [appId] and make sure [redirectUri] is listed as a
/// "Valid OAuth Redirect URI" in your Facebook App → Facebook Login → Settings.
/// Until [appId] is set, the screens show a friendly "not configured" message
/// instead of opening a broken WebView — everything else (listing, removing,
/// campaigns, marketing insights) works against the live API regardless.
/// ──────────────────────────────────────────────────────────────────────────
class FacebookConfig {
  FacebookConfig._();

  /// Facebook App ID (public — required by Facebook's login dialog as client_id).
  /// The App *Secret* is never stored here; the backend holds it and exchanges
  /// the user token for a long-lived one. Can be overridden per build with
  /// --dart-define=FB_APP_ID=…, otherwise falls back to the org's app id.
  static const String appId = String.fromEnvironment(
    'FB_APP_ID',
    defaultValue: '1829640818431818',
  );

  /// Graph API version used for the OAuth dialog and account lookups.
  static const String graphVersion = 'v19.0';

  /// OAuth redirect target. Must be on a domain listed in the Facebook App's
  /// "App Domains" (Settings → Basic) and "Valid OAuth Redirect URIs"
  /// (Facebook Login → Settings). We use the CRM's own domain — the same one
  /// the web app logs in with, so it's already whitelisted. The WebView
  /// intercepts this redirect before it loads and reads the token from the URL
  /// fragment, so no real page needs to exist at this path.
  static const String redirectUri = String.fromEnvironment(
    'FB_REDIRECT_URI',
    defaultValue: 'https://crm.oceantechnolab.com/',
  );

  /// Permissions requested at login. Union of what both Facebook submodules
  /// need so a single login works for Ad Accounts (Marketing) *and* Auto Import
  /// page/lead-form connections (Administration):
  ///  • ads_read / ads_management / business_management → ad accounts, campaigns
  ///  • pages_show_list / pages_read_engagement / pages_manage_metadata → pages
  ///  • leads_retrieval → read Lead Ads form submissions
  static const List<String> scopes = [
    'ads_read',
    'ads_management',
    'business_management',
    'pages_show_list',
    'pages_read_engagement',
    'pages_manage_metadata',
    'leads_retrieval',
  ];

  /// True once an App ID has been configured.
  static bool get isConfigured => appId.isNotEmpty;

  /// Full OAuth dialog URL for the implicit token flow.
  static Uri oauthUrl() {
    return Uri.parse(
      'https://www.facebook.com/$graphVersion/dialog/oauth',
    ).replace(queryParameters: {
      'client_id': appId,
      'redirect_uri': redirectUri,
      'response_type': 'token',
      'scope': scopes.join(','),
      // Always show the account chooser so users can switch FB accounts.
      'auth_type': 'rerequest',
    });
  }

  /// Graph endpoint that lists the ad accounts the logged-in user can access.
  static Uri adAccountsUrl(String userToken) {
    return Uri.parse(
      'https://graph.facebook.com/$graphVersion/me/adaccounts',
    ).replace(queryParameters: {
      'fields': 'name,currency,account_status,timezone_name',
      'access_token': userToken,
      'limit': '200',
    });
  }

  /// Graph endpoint that lists the Facebook pages the user manages, each with a
  /// page access token used to read its lead forms.
  static Uri pagesUrl(String userToken) {
    return Uri.parse(
      'https://graph.facebook.com/$graphVersion/me/accounts',
    ).replace(queryParameters: {
      'fields': 'id,name,access_token,category',
      'access_token': userToken,
      'limit': '200',
    });
  }

  /// Graph endpoint that lists the Lead Ads forms for a page.
  static Uri leadFormsUrl(String pageId, String pageAccessToken) {
    return Uri.parse(
      'https://graph.facebook.com/$graphVersion/$pageId/leadgen_forms',
    ).replace(queryParameters: {
      'fields': 'id,name,status',
      'access_token': pageAccessToken,
      'limit': '200',
    });
  }
}
