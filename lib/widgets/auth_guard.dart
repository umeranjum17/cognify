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
        // Show loading while the provider is initializing
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking authentication...'),
                ],
              ),
            ),
          );
        }
        
        // If authenticated, show the protected child widget
        if (authProvider.isAuthenticated) {
          return child;
        }
        
        // Not authenticated - redirect to onboarding or show onboarding screen
        if (redirectTo != null) {
          // Use post-frame callback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go(redirectTo!);
            }
          });
          
          // Show temporary loading while redirecting
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Redirecting to authentication...'),
                ],
              ),
            ),
          );
        }
        
        // Show onboarding screen directly if no redirect specified
        return const OAuthOnboardingScreen();
      },
    );
  }
}