// Models for the Facebook Lead Ads auto-import flow (Administration → Facebook).
//
// A user logs in, picks a Page they manage, then a Lead Ad Form on that page.
// The connection is saved on our backend so new form submissions auto-import
// as leads. FacebookPage / FacebookLeadForm come from the Graph API during the
// connect flow; AutoImportAccount is a saved connection returned by our backend.

/// A Facebook Page the logged-in user manages (Graph /me/accounts).
class FacebookPage {
  final String id;
  final String name;

  /// Page access token — required to read the page's lead forms.
  final String accessToken;
  final String category;

  const FacebookPage({
    required this.id,
    required this.name,
    required this.accessToken,
    this.category = '',
  });

  factory FacebookPage.fromJson(Map<String, dynamic> json) {
    return FacebookPage(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Untitled page').toString(),
      accessToken: (json['access_token'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
    );
  }
}

/// A Lead Ads form on a page (Graph /{page_id}/leadgen_forms).
class FacebookLeadForm {
  final String id;
  final String name;
  final String status;

  const FacebookLeadForm({
    required this.id,
    required this.name,
    this.status = '',
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory FacebookLeadForm.fromJson(Map<String, dynamic> json) {
    return FacebookLeadForm(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Untitled form').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

/// A saved page+form auto-import connection (our backend record).
class AutoImportAccount {
  final String id;
  final String pageId;
  final String pageName;
  final String formId;
  final String formName;
  final DateTime? createdAt;

  const AutoImportAccount({
    required this.id,
    required this.pageId,
    required this.pageName,
    required this.formId,
    required this.formName,
    this.createdAt,
  });

  factory AutoImportAccount.fromJson(Map<String, dynamic> json) {
    final created = json['created_at']?.toString();
    return AutoImportAccount(
      id: (json['id'] ?? json['account_id'] ?? '').toString(),
      pageId: (json['page_id'] ?? '').toString(),
      pageName: (json['page_name'] ?? json['name'] ?? 'Untitled page').toString(),
      formId: (json['form_id'] ?? '').toString(),
      formName: (json['form_name'] ?? '').toString(),
      createdAt: created != null ? DateTime.tryParse(created) : null,
    );
  }
}
