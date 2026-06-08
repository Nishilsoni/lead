import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';

/// Color-coded badge indicating the lead's current stage.
class StageBadge extends StatelessWidget {
  final String stage;
  final bool compact;

  const StageBadge({
    super.key,
    required this.stage,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.stageColor(stage);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        stage,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
