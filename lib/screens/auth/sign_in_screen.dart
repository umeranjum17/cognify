import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../services/analytics_service.dart';

/// SignInScreen()
class SignInScreen extends StatefulWidget {
  final String? pendingSharedUrl;

  const SignInScreen({super.key, this.pendingSharedUrl});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;
  String? _error;
  

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleGoogle(BuildContext context) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<FirebaseAuthProvider>();
    try {
      await auth.signInWithGoogle();
      await AnalyticsService.instance.logLogin(method: 'google');
      if (!mounted) return;
      _handlePostSignIn(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handleApple(BuildContext context) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<FirebaseAuthProvider>();
    try {
      await auth.signInWithApple();
      await AnalyticsService.instance.logLogin(method: 'apple');
      if (!mounted) return;
      _handlePostSignIn(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handleDevSignIn(BuildContext context) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<FirebaseAuthProvider>();
    try {
      await auth.devSignIn(email: 'simulator@dev.local');
      await AnalyticsService.instance.logLogin(method: 'dev');
      if (!mounted) return;
      _handlePostSignIn(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cognify Logo
                  Image.asset(
                    'assets/images/cognify_robot_512x512.png',
                    width: 120,
                    height: 120,
                  ),
                  const SizedBox(height: 24),
                  // App Title
                  Text(
                    'Cognify',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Project Pitch
                  Text(
                    'Your AI-powered writing assistant.\nCreate, edit, and enhance content with advanced language models.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Sign-in prompt
                  const Icon(Icons.lock_open, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Sign in to continue',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in to start chatting and access your free credits in Cognify.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (isIOS) ...[
                    _SignInButton(
                      label: 'Continue with Apple',
                      icon: Icons.apple,
                      onPressed: _busy ? null : () => _handleApple(context),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!isIOS)
                    _SignInButton(
                      label: 'Continue with Google',
                      icon: Icons.login,
                      onPressed: _busy ? null : () => _handleGoogle(context),
                    ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 24),
                  if (_busy) const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SignInButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

void _handlePostSignIn(BuildContext context) {
  context.go('/editor');
}
