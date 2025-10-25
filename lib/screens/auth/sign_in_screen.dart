import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../services/analytics_service.dart';
import '../../widgets/cognify_logo.dart';
import '../../api/api.dart';

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
  String? _pendingCreditTransferFromUid;

  @override
  void initState() {
    super.initState();
    _checkPendingCreditTransfer();
  }

  Future<void> _checkPendingCreditTransfer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pendingCreditTransferFromUid = prefs.getString('pending_credit_transfer_from');
      if (_pendingCreditTransferFromUid != null) {
        debugPrint('🔄 [SignIn] Found pending credit transfer from: $_pendingCreditTransferFromUid');
      }
    } catch (e) {
      debugPrint('⚠️ [SignIn] Failed to check pending credit transfer: $e');
    }
  }

  Future<void> _handleGoogle(BuildContext context) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<FirebaseAuthProvider>();
    try {
      await auth.signInWithGoogle();

      // Check if we need to transfer credits from a previous anonymous account
      if (_pendingCreditTransferFromUid != null) {
        debugPrint('🔄 [SignIn] Transferring credits after successful Google sign-in...');
        setState(() {
          _error = 'Transferring your credits...';
        });

        try {
          await API.instance.transferCredits(sourceUid: _pendingCreditTransferFromUid!);
          debugPrint('✅ [SignIn] Credits transferred successfully');

          // Clear the pending transfer
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pending_credit_transfer_from');
          _pendingCreditTransferFromUid = null;

          if (mounted) {
            setState(() {
              _error = null;
            });
          }
        } catch (transferError) {
          debugPrint('⚠️ [SignIn] Credit transfer failed: $transferError');
          // Don't block sign-in if transfer fails
        }
      }

      await AnalyticsService.instance.logLogin(method: 'google');
      await _markFirstLaunchComplete();
      if (!mounted) return;
      _handlePostSignIn(context);
    } catch (e) {
      final errorString = e.toString();

      // Check if this is the special "account exists" error
      if (errorString.contains('GOOGLE_ACCOUNT_EXISTS:')) {
        final anonymousUid = errorString.split(':')[1];
        debugPrint('🔄 [SignIn] Storing anonymous UID for credit transfer: $anonymousUid');

        // Store the anonymous UID for credit transfer
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_credit_transfer_from', anonymousUid);
          _pendingCreditTransferFromUid = anonymousUid;
        } catch (e) {
          debugPrint('⚠️ [SignIn] Failed to store pending credit transfer: $e');
        }

        if (mounted) {
          setState(() {
            _busy = false;
            _error = 'This Google account is already registered. Please tap "Continue with Google" again to sign in and transfer your credits.';
          });
        }
        return;
      }

      setState(() {
        _error = _getUserFriendlyErrorMessage(errorString);
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

      // Check if we need to transfer credits from a previous anonymous account
      if (_pendingCreditTransferFromUid != null) {
        debugPrint('🔄 [SignIn] Transferring credits after successful Apple sign-in...');
        setState(() {
          _error = 'Transferring your credits...';
        });

        try {
          await API.instance.transferCredits(sourceUid: _pendingCreditTransferFromUid!);
          debugPrint('✅ [SignIn] Credits transferred successfully');

          // Clear the pending transfer
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pending_credit_transfer_from');
          _pendingCreditTransferFromUid = null;

          if (mounted) {
            setState(() {
              _error = null;
            });
          }
        } catch (transferError) {
          debugPrint('⚠️ [SignIn] Credit transfer failed: $transferError');
          // Don't block sign-in if transfer fails
        }
      }

      await AnalyticsService.instance.logLogin(method: 'apple');
      await _markFirstLaunchComplete();
      if (!mounted) return;
      _handlePostSignIn(context);
    } catch (e) {
      final errorString = e.toString();

      // Check if this is the special "account exists" error
      if (errorString.contains('APPLE_ACCOUNT_EXISTS:')) {
        final anonymousUid = errorString.split(':')[1];
        debugPrint('🔄 [SignIn] Storing anonymous UID for credit transfer: $anonymousUid');

        // Store the anonymous UID for credit transfer
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_credit_transfer_from', anonymousUid);
          _pendingCreditTransferFromUid = anonymousUid;
        } catch (e) {
          debugPrint('⚠️ [SignIn] Failed to store pending credit transfer: $e');
        }

        if (mounted) {
          setState(() {
            _busy = false;
            _error = 'This Apple ID is already registered. Please tap "Continue with Apple" again to sign in and transfer your credits.';
          });
        }
        return;
      } else if (errorString.contains('APPLE_ACCOUNT_EXISTS_NO_TRANSFER')) {
        // Apple account exists but no credits to transfer
        debugPrint('🔄 [SignIn] Apple account exists, no credits to transfer');

        if (mounted) {
          setState(() {
            _busy = false;
            _error = 'This Apple ID is already registered. Please tap "Continue with Apple" again to sign in.';
          });
        }
        return;
      }

      String errorMessage = _getUserFriendlyErrorMessage(errorString);
      setState(() {
        _error = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _getUserFriendlyErrorMessage(String error) {
    // Strip "Exception: " prefix if present
    final cleanError = error.replaceFirst(RegExp(r'^Exception:\s*'), '');

    // Don't show ACCOUNT_EXISTS errors - they're handled separately
    if (cleanError.contains('APPLE_ACCOUNT_EXISTS:') ||
        cleanError.contains('GOOGLE_ACCOUNT_EXISTS:')) {
      return '';
    } else if (cleanError.contains('already registered') && cleanError.contains('sign out')) {
      return cleanError; // Use our custom message as-is
    } else if (error.contains('Sign in with Apple is only available on iOS') ||
        error.contains('Sign in with Apple not available')) {
      return 'Apple Sign-In is not available on this device. Please try again or use a different sign-in method.';
    } else if (error.contains('Apple Sign-In failed') &&
        error.contains('iCloud')) {
      return 'Apple Sign-In failed. Please ensure you\'re signed into iCloud in Settings > Sign-In to your iPhone, or try on a real device.';
    } else if (error.contains('Apple did not return an identity token')) {
      return 'Apple Sign-In failed. Please make sure you\'re signed into iCloud and try again.';
    } else if (error.contains('credential-already-in-use')) {
      return 'This Apple ID is already in use. Please try signing out and signing in again.';
    } else if (error.contains('invalid-credential')) {
      return 'Apple Sign-In failed. Please try signing in with Apple again.';
    } else if (error.contains('account-exists-with-different-credential')) {
      return 'An account already exists with this email. Please try signing in with the original method.';
    } else if (error.contains('network') || error.contains('connection')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (error.contains('AuthorizationErrorCode.canceled') ||
        error.contains('error 1001') ||
        error.contains('canceled')) {
      return ''; // Don't show error for user cancellation
    } else if (error.contains('Apple Sign-In failed')) {
      return 'Apple Sign-In failed. Please try again or use a different sign-in method.';
    } else if (cleanError.isNotEmpty) {
      return cleanError;
    } else {
      return 'Sign-in failed. Please try again. If the problem persists, contact support.';
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
      await _markFirstLaunchComplete();
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

  Future<void> _handleSkip(BuildContext context) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final authProvider = context.read<FirebaseAuthProvider>();

      // If not signed in, sign in anonymously directly
      if (!authProvider.isSignedIn) {
        debugPrint('🔄 [SignIn] Signing in anonymously via skip...');
        await fb.FirebaseAuth.instance.signInAnonymously();
        debugPrint('✅ [SignIn] Anonymous sign-in successful');

        // Wait a bit for the auth state to propagate
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify sign-in succeeded
        if (fb.FirebaseAuth.instance.currentUser == null) {
          throw Exception('Failed to sign in anonymously. Please try again.');
        }
      }

      if (!mounted) return;
      await AnalyticsService.instance.logLogin(method: 'anonymous_skip');
      await _markFirstLaunchComplete();
      _handlePostSignIn(context);
    } catch (e) {
      debugPrint('❌ [SignIn] Skip error: $e');
      setState(() {
        _error = 'Failed to continue anonymously. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _markFirstLaunchComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_first_launch', true);
      debugPrint('✅ [SignIn] First launch marked as complete');
    } catch (e) {
      debugPrint('⚠️ [SignIn] Failed to mark first launch as complete: $e');
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
                  CognifyLogo(size: 120),
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
                  const Icon(Icons.cloud_sync, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Sign in for extra benefits',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Keep your credits synced across devices and get access to priority support.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  if (_error != null && _error!.isNotEmpty) ...[
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
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 14,
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
                  _SignInButton(
                    label: 'Continue with Google',
                    icon: Icons.login,
                    onPressed: _busy ? null : () => _handleGoogle(context),
                  ),
                  const SizedBox(height: 24),
                  // Skip button
                  TextButton(
                    onPressed: _busy ? null : () => _handleSkip(context),
                    child: Text(
                      'Skip for now',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
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
