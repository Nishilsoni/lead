/// Central location for all API path constants.
/// Base URL and org ID are managed by EnvironmentService — not hardcoded here.
class ApiConstants {
  ApiConstants._();

  // ── Authentication ───────────────────────────────────────────────
  static const String login = '/v1/auth/login';
  static const String refresh = '/v1/auth/refresh';
  static const String logout = '/v1/auth/logout';

  // ── Leads ────────────────────────────────────────────────────────
  static const String leads = '/v1/lead';
  static String leadById(String id) => '/v1/lead/$id';
  static const String leadExport = '/v1/lead/export';
  static const String leadBulkUpload = '/v1/lead/bulk-upload';
  static const String leadBulkAssign = '/v1/lead/bulk-assign';
  static const String leadStages = '/v1/lead/stage/';
  static const String leadStageCreate = '/v1/lead/stage';
  static String leadStageDelete(String id) => '/v1/lead/stage/$id';
  static const String leadStageRename = '/v1/lead/stage/rename';
  static const String leadStageMove = '/v1/lead/stage/move';

  // ── Activities / Interactions ─────────────────────────────────────
  static const String interactions = '/v1/interaction';
  static String interactionById(String id) => '/v1/interaction/$id';

  // ── Appointments ──────────────────────────────────────────────────
  static const String appointments = '/v1/appointment';
  static String appointmentById(String id) => '/v1/appointment/$id';

  // ── Dashboard ───────────────────────────────────────────────────
  static const String dashboardStats = '/v1/dashboard/stats';

  // ── Plan & Integrations ──────────────────────────────────────────
  static const String orgPlans = '/v1/org/plans/';

  // ── Billing (Razorpay subscription payments) ─────────────────────
  static const String razorpayOrder = '/v1/billing/razorpay/order';
  static const String razorpayVerify = '/v1/billing/razorpay/verify';
  static String billingInvoice(String orderId) =>
      '/v1/billing/invoice/$orderId';
  static const String shopifyAccounts = '/v1/shopify/';
  static const String indiamartAccounts = '/v1/indiamart/';
  static const String metaAccounts = '/v1/meta/account';
  static const String calendarStatus = '/v1/calendar/status';

  // ── Meta / Facebook Ad Accounts & Marketing ──────────────────────
  static const String metaAdAccounts = '/v1/meta/ad-account';
  static String metaAdAccountById(String id) => '/v1/meta/ad-account/$id';
  static String metaAdAccountCampaigns(String id) =>
      '/v1/meta/ad-account/$id/campaigns';
  static String metaAdAccountCampaignById(String id, String campaignId) =>
      '/v1/meta/ad-account/$id/campaigns/$campaignId';
  static const String metaRefreshTokens = '/v1/meta/refresh-tokens';

  // ── Facebook Lead Ads auto-import (page + form connections) ──────
  // NOTE: this route is not yet in the published OpenAPI spec. It is isolated
  // here as a single constant so it can be corrected the moment the real path
  // is confirmed — the rest of the auto-import flow (FB login, page & form
  // pickers via the Graph API) works regardless.
  static const String facebookLeadImport = '/v1/facebook/lead-import';
  static String facebookLeadImportById(String id) =>
      '/v1/facebook/lead-import/$id';

  // ── Attachments ──────────────────────────────────────────────────
  // List: embedded in GET /v1/lead/{id} response (attachments field)
  // Upload: POST /v1/lead/{id}/attachments (multipart, file field only)
  // Delete: DELETE /v1/lead/{id}/attachments/{attachmentId}
  static String leadAttachments(String leadId) => '/v1/lead/$leadId/attachments';
  static String leadAttachmentById(String leadId, String attachmentId) =>
      '/v1/lead/$leadId/attachments/$attachmentId';

  // ── AI ───────────────────────────────────────────────────────────
  static const String aiParseLead = '/v1/ai/parse-lead';

  // ── Contacts ─────────────────────────────────────────────────────
  static const String contacts = '/v1/contact';
  static String contactById(String id) => '/v1/contact/$id';

  // ── Tags ─────────────────────────────────────────────────────────
  static const String tags = '/v1/tag';
  static String tagById(int id) => '/v1/tag/$id';

  // ── Supporting Resources ─────────────────────────────────────────
  static const String products = '/v1/product';
  static const String sources = '/v1/source';
  static const String users = '/v1/user';
  static const String leadSettings = '/v1/lead/settings';
  static const String currentOrg = '/v1/org/current';
  static const String currentUser = '/v1/user/logged';

  // ── Notifications ─────────────────────────────────────────────────
  // baseUrl already ends with /api and switches by environment (test/prod),
  // so these paths are identical across both — only the domain changes.
  static const String notifications = '/v1/notifications';
  static const String notificationsUnreadCount =
      '/v1/notifications/unread-count';
  static const String notificationsReadAll = '/v1/notifications/read-all';
  static const String notificationsClearAll = '/v1/notifications/clear-all';
  static String notificationRead(String id) => '/v1/notifications/$id/read';
  static String notificationById(String id) => '/v1/notifications/$id';
}
