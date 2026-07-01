/// lib/features/inbox/presentation/screens/inbox_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../shared/widgets/loading_shimmer.dart';

final conversationsProvider =
    FutureProvider.family<List<Conversation>, String?>((ref, search) async {
  final api = ref.watch(apiClientProvider);
  final params = <String, dynamic>{};
  if (search != null && search.isNotEmpty) params['search'] = search;
  final resp = await api.get('/chat/conversations', params: params);
  final list = resp.data as List<dynamic>;
  return list
      .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
      .toList();
});

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});
  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _searchCtrl = TextEditingController();
  String? _search;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final convAsync = ref.watch(conversationsProvider(_search));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = null);
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                isDense: true,
              ),
              onChanged: (v) =>
                  setState(() => _search = v.isEmpty ? null : v),
            ),
          ),
        ),
      ),
      body: convAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: ShimmerList(count: 8, itemHeight: 72),
        ),
        error: (e, _) => _EmptyState(
          icon: Icons.wifi_off_outlined,
          title: 'Could not load conversations',
          subtitle: apiErrorMessage(e),
          onRetry: () => ref.invalidate(conversationsProvider(_search)),
        ),
        data: (convs) => convs.isEmpty
            ? const _EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No conversations yet',
                subtitle:
                    'When customers message your WhatsApp, they appear here.',
              )
            : RefreshIndicator(
                color: WaziBotColors.primary,
                onRefresh: () async {
                  await Haptics.refresh();
                  ref.invalidate(conversationsProvider(_search));
                },
                child: ListView.separated(
                  itemCount: convs.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 0,
                    color: theme.colorScheme.outline,
                    indent: 72,
                  ),
                  itemBuilder: (_, i) =>
                      _ConversationTile(conv: convs[i]),
                ),
              ),
      ),
      bottomSheet: const _WebBanner(),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conv;
  const _ConversationTile({required this.conv});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = conv.customerName ?? conv.phone;
    final time = _formatTime(conv.lastMessageAt);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor:
                WaziBotColors.primary.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: WaziBotColors.primary),
            ),
          ),
          if (conv.hasUnread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: WaziBotColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: theme.scaffoldBackgroundColor, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: conv.hasUnread
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text(time,
              style: theme.textTheme.bodySmall?.copyWith(
                color: conv.hasUnread
                    ? WaziBotColors.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              )),
        ],
      ),
      subtitle: Row(children: [
        if (conv.isAiPaused)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: WaziBotColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Agent',
                style: TextStyle(
                    fontSize: 9,
                    color: WaziBotColors.warning,
                    fontWeight: FontWeight.w600)),
          ),
        Expanded(
          child: Text(
            conv.lastMessage ?? 'No messages',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: conv.hasUnread
                  ? FontWeight.w500
                  : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
      onTap: () {
        Haptics.light();
        context.go('/inbox/${conv.phone}');
      },
    );
  }

  String _formatTime(String? ts) {
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat.jm().format(dt.toLocal());
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat.E().format(dt.toLocal());
    return DateFormat.MMMd().format(dt.toLocal());
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 52,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class _WebBanner extends StatelessWidget {
  const _WebBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border:
            Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline,
            size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Need advanced chatbot configuration? Continue on WaziBot Web.',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
          ),
          child: const Text('Open',
              style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}
