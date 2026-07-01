/// lib/features/home/domain/briefing_item.dart
///
/// A single line in "Today's Business Briefing".
/// Each item has a priority so the briefing can show only the
/// top 3-5 most important things — never an overwhelming list.
library;

import 'package:flutter/material.dart';

enum BriefingTone { positive, neutral, warning, urgent }

class BriefingItem {
  /// Higher = more important. Used to sort and truncate the list.
  final int priority;
  final String text;
  final IconData icon;
  final BriefingTone tone;
  /// Optional deep-link route to navigate to when tapped.
  final String? route;

  const BriefingItem({
    required this.priority,
    required this.text,
    required this.icon,
    this.tone = BriefingTone.neutral,
    this.route,
  });
}
