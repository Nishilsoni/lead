import 'package:flutter/material.dart';
import '../../screens/leads/lead_activities_screen.dart';
import '../../services/lead_service.dart';

/// Global navigator key so services that live outside the widget tree
/// (push notification taps, local notification taps) can push a screen
/// without a [BuildContext] of their own. Registered on [MaterialApp] in
/// main.dart.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  static final LeadService _leadService = LeadService();

  /// Opens the lead a notification refers to. Notifications only carry an
  /// id, so the lead is fetched first for its name/assignee before pushing
  /// [LeadActivitiesScreen]; the screen self-fetches mobile/email/stage.
  static Future<void> openLead(String leadId) async {
    final navState = key.currentState;
    if (navState == null || leadId.isEmpty) return;
    try {
      final lead = await _leadService.getLeadById(leadId);
      navState.push(MaterialPageRoute(
        builder: (_) => LeadActivitiesScreen(
          leadId: lead.id,
          leadName: lead.business.name,
          assignedUserId: lead.assignedUser?.id ?? '',
        ),
      ));
    } catch (_) {
      // Lead may have been deleted or reassigned out of view — fail
      // silently rather than crash on a stale notification tap.
    }
  }
}
