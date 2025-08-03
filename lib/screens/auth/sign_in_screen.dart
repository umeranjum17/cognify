import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/firebase_auth_provider.dart';

/// SignInScreen()
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _handleGoogle(BuildContext context) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<FirebaseAuthProvider>();
    try {
      await auth.initialize();
      await auth.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).maybePop();
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
      await auth.initialize();
      await auth.signInWithApple();
      if (!mounted) return;
      Navigator.of(context).maybePop();
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
      appBar: AppBar(
        title: const Text('Sign in'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_open, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in to continue',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Use a native sign-in provider to sync your subscription and restore across devices.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
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
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                  _SignInButton(
                    label: 'Continue with Google',
                    icon: Icons.login,
                    onPressed: _busy ? null : () => _handleGoogle(context),
                  ),
                  const SizedBox(height: 24),
                  if (_busy) const CircularProgressIndicator(),
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
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}