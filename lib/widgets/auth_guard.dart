import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/oauth_auth_provider.dart';
import '../screens/oauth_onboarding_screen.dart';

/// A reusable authentication guard widget that protects routes from unauthorized access
class AuthGuard extends StatelessWidget {
  final Widget child;
  final String? redirectTo;

  const AuthGuard({
    super.key,
    required this.child,
    this.redirectTo,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OAuthAuthProvider>(
      builder: (context, authProvider, _) {
        // If authenticated, show the protected child widget immediately
        if (authProvider.isAuthenticated) {
          return child;
        }
        
        // Show minimal loading during actual initialization
        if (authProvider.isLoading) {
          return const SizedBox.shrink(); // Minimal loading handled by main app
        }
        
        // Not authenticated - redirect immediately without showing loading
        if (redirectTo != null) {
          // Immediate redirect to avoid flash
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go(redirectTo!);
            }
          });
          
          // Return minimal widget to avoid flash
          return const SizedBox.shrink();
        }
        
        // Show onboarding screen directly if no redirect specified
        return const OAuthOnboardingScreen();
      },
    );
  }
}