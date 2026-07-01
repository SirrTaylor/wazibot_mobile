/// lib/features/qr/presentation/screens/qr_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/api/api_client.dart';

final storeUrlProvider = FutureProvider<String?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/me');
  final data = resp.data as Map<String, dynamic>;
  return data['store_url'] as String? ?? data['website_url'] as String?;
});

class QrScreen extends ConsumerWidget {
  const QrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(storeUrlProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('QR Code')),
      body: urlAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiErrorMessage(e))),
        data: (url) =>
            url == null ? const _EmptyQr() : _QrDisplay(url: url),
      ),
    );
  }
}

class _QrDisplay extends StatelessWidget {
  final String url;
  const _QrDisplay({required this.url});

  void _share() => Share.share('Check out my store: $url');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Text('Scan to visit your store',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: url,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(url,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.download_outlined,
                    size: 18, color: Colors.black),
                label: const Text('Download'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: const Text('View QR Analytics'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44)),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Store URL',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Text(url,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      onPressed: () {},
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyQr extends StatelessWidget {
  const _EmptyQr();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2,
                size: 60,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No store URL set',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Set up your store URL on the web dashboard to generate a QR code.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.open_in_browser, size: 16),
              label: const Text('Open Web Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
