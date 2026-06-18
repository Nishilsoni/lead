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
  static const String leadStages = '/v1/lead/stage/';
  static const String leadStageCreate = '/v1/lead/stage';
  static String leadStageDelete(String id) => '/v1/lead/stage/$id';

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
  static const String shopifyAccounts = '/v1/shopify/';
  static const String indiamartAccounts = '/v1/indiamart/';
  static const String metaAccounts = '/v1/meta/account';
  static const String calendarStatus = '/v1/calendar/status';

  // ── Attachments ──────────────────────────────────────────────────
  // List: embedded in GET /v1/lead/{id} response (attachments field)
  // Upload: POST /v1/lead/{id}/attachments (multipart, file field only)
  // Delete: DELETE /v1/lead/{id}/attachments/{attachmentId}
  static String leadAttachments(String leadId) => '/v1/lead/$leadId/attachments';
  static String leadAttachmentById(String leadId, String attachmentId) =>
      '/v1/lead/$leadId/attachments/$attachmentId';

  // ── AI ───────────────────────────────────────────────────────────
  static const String aiParseLead = '/v1/ai/parse-lead';

  // ── Supporting Resources ─────────────────────────────────────────
  static const String products = '/v1/product';
  static const String sources = '/v1/source';
  static const String users = '/v1/user';
  static const String leadSettings = '/v1/lead/settings';
  static const String currentOrg = '/v1/org/current';
  static const String currentUser = '/v1/user/logged';
}
