/// lib/features/auth/presentation/screens/splash_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/router/app_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    // Fallback: manually navigate after a timeout in case the
    // auth state stream doesn't fire (e.g. web / secure_storage issues)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _checkAndNavigate();
    });
  }

  Future<void> _checkAndNavigate() async {
    try {
      final authService = ref.read(authServiceProvider);
      final hasSession = await authService.hasSession();
      if (!mounted) return;
      if (hasSession) {
        context.go(Routes.home);
      } else {
        context.go(Routes.login);
      }
    } catch (_) {
      if (mounted) context.go(Routes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Also listen to auth state changes (fires on mobile / if storage loads fast)
    ref.listen(authNotifierProvider, (_, next) {
      if (next.isLoading) return;
      final status = next.valueOrNull?.status;
      if (status == AuthStatus.authenticated) {
        context.go(Routes.home);
      } else if (status == AuthStatus.unauthenticated) {
        context.go(Routes.login);
      }
    });

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.smart_toy_outlined,
                      color: Colors.black, size: 44),
                ),
                const SizedBox(height: 16),
                Text('WaziBot',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    )),
                const SizedBox(height: 6),
                Text('AI Business OS',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
