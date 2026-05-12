/// Central location for all API-related constants.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api-test.crm.oceantechnolab.com/api';

  // Demo org for test environment
  static const String orgId = '0199d939-d1cd-7001-add3-8991fb795d55';

  // ── Authentication ───────────────────────────────────────────────
  static const String login = '/v1/auth/login';
  static const String refresh = '/v1/auth/refresh';
  static const String logout = '/v1/auth/logout';

  // ── Leads ────────────────────────────────────────────────────────
  static const String leads = '/v1/lead';
  static String leadById(String id) => '/v1/lead/$id';
  static const String leadStages = '/v1/lead/stage/';

  // ── Supporting Resources ─────────────────────────────────────────
  static const String products = '/v1/product';
  static const String sources = '/v1/source';
  static const String users = '/v1/user';
  static const String cities = '/v1/city';
  static const String currentOrg = '/v1/org/current';
  static const String currentUser = '/v1/user/logged';
}
