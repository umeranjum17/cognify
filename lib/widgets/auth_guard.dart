import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/firebase_auth_provider.dart';
import '../screens/auth/sign_in_screen.dart';

/// A reusable authentication guard widget that protects routes from unauthorized access
class AuthGuard extends StatelessWidget {
  final Widget child;
  final String? redirectTo;

  const AuthGuard({super.key, required this.child, this.redirectTo});

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.initializing || !authProvider.initialized) {
          return const Center(child: CircularProgressIndicator());
        }

        if (authProvider.isSignedIn) {
          return child;
        }

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

        return const SignInScreen();
      },
    );
  }
}
