/// lib/features/home/domain/briefing_generator.dart
///
/// Generates "Today's Business Briefing" — the 3-5 most important things
/// a business owner needs to know right now, derived from real backend
/// data. Every bullet is conditional: if the data isn't meaningful
/// (zero, null, unavailable), the bullet is simply omitted. We never
/// show a placeholder or empty insight.
///
/// This is pure logic — no widgets, no Riverpod — so it's easy to reason
/// about and won't break the UI layer if data shapes shift slightly.
library;

import 'package:flutter/material.dart';
import 'briefing_item.dart';
import '../../../shared/models/business_models.dart';

class BriefingGenerator {
  BriefingGenerator._();

  /// Builds the full candidate list of insights, then returns only the
  /// top [maxItems] sorted by priority (highest first).
  static List<BriefingItem> generate({
    required BusinessProfile? profile,
    required DashboardStats? stats,
    required List<Order>? orders,
    required List<Conversation>? conversations,
    required List<LowStockProduct>? lowStock,
    Map<String, dynamic>? acquisition,
    Map<String, dynamic>? repeatCustomers,
    Map<String, dynamic>? paymentReminders,
    int maxItems = 5,
  }) {
    final items = <BriefingItem>[];

    // ── Trial / subscription urgency (highest priority — business risk) ──────
    if (profile != null && profile.isOnTrial && profile.trialEndsAt != null) {
      final end = DateTime.tryParse(profile.trialEndsAt!);
      if (end != null) {
        final days = end.difference(DateTime.now()).inDays;
        if (days <= 0) {
          items.add(const BriefingItem(
            priority: 100,
            text: 'Your trial has expired — upgrade to keep WaziBot running.',
            icon: Icons.warning_amber_rounded,
            tone: BriefingTone.urgent,
            route: '/more/settings',
          ));
        } else if (days <= 3) {
          items.add(BriefingItem(
            priority: 95,
            text:
                'Trial expires in $days day${days == 1 ? '' : 's'} — upgrade to avoid interruption.',
            icon: Icons.schedule_rounded,
            tone: BriefingTone.warning,
            route: '/more/settings',
          ));
        }
      }
    }

    // ── Failed / overdue payments ──────────────────────────────────────────────
    if (paymentReminders != null) {
      final count = (paymentReminders['count'] as num?)?.toInt() ?? 0;
      if (count > 0) {
        items.add(BriefingItem(
          priority: 88,
          text:
              '$count payment${count == 1 ? '' : 's'} need${count == 1 ? 's' : ''} a reminder.',
          icon: Icons.payments_outlined,
          tone: BriefingTone.warning,
          route: '/reminders',
        ));
      }
    }

    // ── New orders waiting ─────────────────────────────────────────────────────
    if (orders != null) {
      final newCount = orders.where((o) => o.status == 'new').length;
      if (newCount > 0) {
        items.add(BriefingItem(
          priority: 90,
          text:
              'You have $newCount new order${newCount == 1 ? '' : 's'} waiting.',
          icon: Icons.receipt_long_rounded,
          tone: BriefingTone.urgent,
          route: '/orders',
        ));
      }

      final preparingCount =
          orders.where((o) => o.status == 'preparing').length;
      if (preparingCount > 0 && newCount == 0) {
        // Only surface this if there's nothing more urgent — avoids clutter
        items.add(BriefingItem(
          priority: 60,
          text:
              '$preparingCount order${preparingCount == 1 ? ' is' : 's are'} being prepared.',
          icon: Icons.outdoor_grill_outlined,
          tone: BriefingTone.neutral,
          route: '/orders',
        ));
      }
    }

    // ── Customers waiting for a reply ──────────────────────────────────────────
    if (conversations != null) {
      final unread = conversations.where((c) => c.hasUnread).length;
      if (unread > 0) {
        items.add(BriefingItem(
          priority: 85,
          text:
              '$unread customer${unread == 1 ? ' is' : 's are'} waiting for a reply.',
          icon: Icons.chat_bubble_outline_rounded,
          tone: BriefingTone.urgent,
          route: '/inbox',
        ));
      }
    }

    // ── Low stock warning ──────────────────────────────────────────────────────
    if (lowStock != null && lowStock.isNotEmpty) {
      if (lowStock.length == 1) {
        items.add(BriefingItem(
          priority: 70,
          text: '${lowStock.first.name} is running low.',
          icon: Icons.inventory_2_outlined,
          tone: BriefingTone.warning,
          route: '/more/products',
        ));
      } else {
        items.add(BriefingItem(
          priority: 70,
          text: '${lowStock.length} products are running low on stock.',
          icon: Icons.inventory_2_outlined,
          tone: BriefingTone.warning,
          route: '/more/products',
        ));
      }
    }

    // ── Revenue trend (only if we have a meaningful signal) ───────────────────
    if (stats != null && stats.totalRevenue > 0) {
      // We don't have yesterday's revenue from this endpoint, so we use
      // a qualitative signal instead: paid vs total orders as a health proxy.
      if (stats.totalOrders > 0) {
        final payRate = stats.paidOrders / stats.totalOrders;
        if (payRate >= 0.8 && stats.paidOrders >= 3) {
          items.add(const BriefingItem(
            priority: 50,
            text: 'Most of your orders are getting paid — nice work.',
            icon: Icons.trending_up_rounded,
            tone: BriefingTone.positive,
            route: '/analytics',
          ));
        }
      }
    }

    // ── Repeat customers (positive signal) ─────────────────────────────────────
    if (repeatCustomers != null) {
      final rate = (repeatCustomers['repeat_rate_pct'] as num?)?.toDouble() ?? 0;
      final total = (repeatCustomers['total_customers'] as num?)?.toInt() ?? 0;
      if (rate >= 30 && total >= 3) {
        items.add(BriefingItem(
          priority: 45,
          text:
              '${rate.toStringAsFixed(0)}% of your customers are coming back.',
          icon: Icons.favorite_outline_rounded,
          tone: BriefingTone.positive,
          route: '/analytics',
        ));
      }
    }

    // ── Website / QR traffic ───────────────────────────────────────────────────
    if (acquisition != null) {
      final today = acquisition['today'] as Map?;
      final qrToday = (today?['qr_scans'] as num?)?.toInt() ?? 0;
      final clicksToday = (today?['whatsapp_clicks'] as num?)?.toInt() ?? 0;
      final visitorsToday = qrToday + clicksToday;
      if (visitorsToday > 0) {
        items.add(BriefingItem(
          priority: 40,
          text:
              'Your store had $visitorsToday visitor${visitorsToday == 1 ? '' : 's'} today.',
          icon: Icons.qr_code_scanner_rounded,
          tone: BriefingTone.neutral,
          route: '/more/qr',
        ));
      }
    }

    // ── Business health (only if something needs attention) ───────────────────
    if (stats != null && stats.healthScore > 0 && stats.healthScore < 50) {
      items.add(const BriefingItem(
        priority: 65,
        text: 'Your business health needs attention — check what\'s missing.',
        icon: Icons.health_and_safety_outlined,
        tone: BriefingTone.warning,
      ));
    }

    // ── Sort highest priority first, cap the list ──────────────────────────────
    items.sort((a, b) => b.priority.compareTo(a.priority));
    return items.take(maxItems).toList();
  }

  /// Short closing line shown beneath the briefing list.
  /// Reassures the owner that anything not mentioned is fine.
  static String closingLine(List<BriefingItem> items) {
    if (items.isEmpty) {
      return 'Everything looks good today. No action needed.';
    }
    return 'Everything else is looking good.';
  }

  /// Time-of-day appropriate greeting.
  static String greeting(String? ownerName) {
    final h = DateTime.now().hour;
    final time = h < 12
        ? 'Good morning'
        : h < 17
            ? 'Good afternoon'
            : 'Good evening';
    final name = (ownerName != null && ownerName.trim().isNotEmpty)
        ? ', ${ownerName.trim()}'
        : '';
    return '$time$name 👋';
  }
}
