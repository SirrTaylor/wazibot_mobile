/// lib/features/settings/presentation/screens/settings_screen.dart
/// Feature 6: Profile editing — PATCH /me with all supported fields
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/security/security_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/providers/cached_providers.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Profile section — now editable ──────────────────────────────
          const _SectionHeader('Business Profile'),
          _SettingsTile(
            icon: Icons.store_outlined,
            title: 'Edit Profile',
            subtitle: 'Name, phone, email, description',
            onTap: () => _showProfileEdit(context, ref),
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: () => _showWebRedirect(context, 'Password settings'),
          ),
          _SettingsTile(
            icon: Icons.credit_card_outlined,
            title: 'Subscription & Billing',
            onTap: () => _showWebRedirect(context, 'Billing settings'),
          ),

          // ── Preferences ──────────────────────────────────────────────────
          const _SectionHeader('Preferences'),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Theme',
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode, size: 16)),
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode, size: 16)),
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.auto_awesome, size: 16)),
              ],
              selected: {themeMode},
              onSelectionChanged: (modes) =>
                  ref.read(themeModeProvider.notifier).state = modes.first,
              style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Orders, customers, reports',
            onTap: () => _showNotificationSettings(context),
          ),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: 'English',
            onTap: () => _showWebRedirect(context, 'Language'),
          ),

          // ── Security ──────────────────────────────────────────────────────
          const _SectionHeader('Security'),
          Consumer(builder: (context, ref, _) {
            final security = ref.watch(securityProvider);
            return Column(children: [
              _SettingsTile(
                icon: Icons.fingerprint,
                title: 'Biometric Lock',
                subtitle: security.biometricAvailable
                    ? 'Locks after 2 minutes in background'
                    : 'Not available on this device',
                trailing: Switch(
                  value: security.biometricAvailable,
                  onChanged: null,
                  activeThumbColor: WaziBotColors.primary,
                  activeTrackColor:
                      WaziBotColors.primary.withValues(alpha: 0.3),
                ),
              ),
              const _SettingsTile(
                icon: Icons.timer_outlined,
                title: 'Session Timeout',
                subtitle: 'Auto sign-out after 15 minutes of inactivity',
              ),
            ]);
          }),

          // ── Advanced ─────────────────────────────────────────────────────
          const _SectionHeader('Advanced'),
          _SettingsTile(
            icon: Icons.campaign_outlined,
            title: 'Campaign Builder',
            onTap: () => _showWebRedirect(context, 'Campaign Builder'),
          ),
          _SettingsTile(
            icon: Icons.web_outlined,
            title: 'Website Builder',
            onTap: () => _showWebRedirect(context, 'Website Builder'),
          ),
          _SettingsTile(
            icon: Icons.auto_fix_high_outlined,
            title: 'Automation Builder',
            onTap: () => _showWebRedirect(context, 'Automation Builder'),
          ),
          _SettingsTile(
            icon: Icons.webhook_outlined,
            title: 'API & Webhooks',
            onTap: () => _showWebRedirect(context, 'Developer settings'),
          ),

          // ── About ─────────────────────────────────────────────────────────
          const _SectionHeader('About'),
          const _SettingsTile(
              icon: Icons.info_outline, title: 'App Version', subtitle: '1.0.0'),
          const _SettingsTile(
              icon: Icons.privacy_tip_outlined, title: 'Privacy Policy'),
          const _SettingsTile(
              icon: Icons.description_outlined, title: 'Terms of Service'),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout, size: 18, color: WaziBotColors.error),
              label: const Text('Sign Out',
                  style: TextStyle(color: WaziBotColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WaziBotColors.error),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showProfileEdit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProfileEditSheet(ref: ref),
    );
  }

  void _showWebRedirect(BuildContext context, String feature) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _WebRedirectSheet(feature: feature),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _NotificationSheet(),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign Out',
                  style: TextStyle(color: WaziBotColors.error))),
        ],
      ),
    );
    if (confirm == true) ref.read(authNotifierProvider.notifier).logout();
  }
}

// ── Profile edit bottom sheet ─────────────────────────────────────────────────
class _ProfileEditSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _ProfileEditSheet({required this.ref});

  @override
  ConsumerState<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<_ProfileEditSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _supportEmailCtrl = TextEditingController();
  final _welcomeCtrl = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from cached profile
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  void _prefill() {
    final profileAsync = ref.read(cachedProfileProvider);
    profileAsync.whenData((profile) {
      if (!mounted) return;
      _nameCtrl.text = profile.name;
      _phoneCtrl.text = profile.contactPhone ?? '';
      _emailCtrl.text = profile.ownerEmail ?? '';
      setState(() => _loaded = true);
    });
    if (!_loaded) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _descCtrl.dispose();
    _supportEmailCtrl.dispose();
    _welcomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business name cannot be empty')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        if (_phoneCtrl.text.isNotEmpty)
          'contact_phone': _phoneCtrl.text.trim(),
        if (_emailCtrl.text.isNotEmpty)
          'owner_email': _emailCtrl.text.trim(),
        if (_descCtrl.text.isNotEmpty)
          'description': _descCtrl.text.trim(),
        if (_supportEmailCtrl.text.isNotEmpty)
          'support_email': _supportEmailCtrl.text.trim(),
        if (_welcomeCtrl.text.isNotEmpty)
          'welcome_message': _welcomeCtrl.text.trim(),
      };
      await api.patch('/me', data: body);
      await Haptics.success();
      // Invalidate profile cache so home screen refreshes
      ref.invalidate(cachedProfileProvider);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved ✓')),
        );
      }
    } catch (e) {
      await Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: WaziBotColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Profile', style: theme.textTheme.titleMedium),
                Row(children: [
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: WaziBotColors.primary))
                        : const Text('Save',
                            style: TextStyle(
                                color: WaziBotColors.primary,
                                fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                _field('Business Name *', _nameCtrl,
                    hint: 'Your business name'),
                _field('Contact Phone', _phoneCtrl,
                    hint: '+263...', keyboard: TextInputType.phone),
                _field('Owner Email', _emailCtrl,
                    hint: 'owner@example.com',
                    keyboard: TextInputType.emailAddress),
                _field('Support Email', _supportEmailCtrl,
                    hint: 'support@example.com',
                    keyboard: TextInputType.emailAddress),
                _field('Business Description', _descCtrl,
                    hint: 'What your business does...', maxLines: 3),
                _field('Welcome Message', _welcomeCtrl,
                    hint: 'Custom greeting for new customers...',
                    maxLines: 2),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Text('Save Profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, int maxLines = 1, TextInputType? keyboard}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboard,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets (unchanged from before) ────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.8)),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading:
          Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant)
              : null),
      onTap: onTap,
    );
  }
}

class _WebRedirectSheet extends StatelessWidget {
  final String feature;
  const _WebRedirectSheet({required this.feature});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: WaziBotColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.open_in_browser,
                color: WaziBotColors.primary, size: 24),
          ),
          const SizedBox(height: 16),
          Text('Continue on WaziBot Web',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'The desktop dashboard includes $feature and other advanced tools.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.launch, size: 16, color: Colors.black),
            label: const Text('Open Web Dashboard'),
          ),
          const SizedBox(height: 8),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later')),
        ],
      ),
    );
  }
}

class _NotificationSheet extends StatefulWidget {
  const _NotificationSheet();
  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  bool _newOrder = true;
  bool _newCustomer = true;
  bool _payment = true;
  bool _lowStock = true;
  bool _weeklyReport = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notifications', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          _sw('New Orders', _newOrder, (v) => setState(() => _newOrder = v)),
          _sw('New Customers', _newCustomer, (v) => setState(() => _newCustomer = v)),
          _sw('Payment Received', _payment, (v) => setState(() => _payment = v)),
          _sw('Low Stock Alert', _lowStock, (v) => setState(() => _lowStock = v)),
          _sw('Weekly Report', _weeklyReport, (v) => setState(() => _weeklyReport = v)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save Preferences'),
          ),
        ],
      ),
    );
  }

  Widget _sw(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        value: value,
        onChanged: onChanged,
        activeThumbColor: WaziBotColors.primary,
        activeTrackColor: WaziBotColors.primary.withValues(alpha: 0.3),
        contentPadding: EdgeInsets.zero,
      );
}
