import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'screens/editor_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sources_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return CupertinoPageRoute(builder: (_) => const HomeScreen());
      case '/editor':
        // Extract prompt from query string if present (support web hash routing)
        String? prompt;
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null && uri.queryParameters.containsKey('prompt')) {
          prompt = uri.queryParameters['prompt'];
        } else if (Uri.base.queryParameters.containsKey('prompt')) {
          prompt = Uri.base.queryParameters['prompt'];
        } else {
          final args = settings.arguments as Map<String, dynamic>?;
          prompt = args != null ? args['prompt'] as String? : null;
        }
        return CupertinoPageRoute(
          builder: (_) => EditorScreen(
            prompt: prompt,
          ),
        );
      case '/sources':
        // Extract shared URL from query parameters
        String? sharedUrl;
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null && uri.queryParameters.containsKey('sharedUrl')) {
          sharedUrl = uri.queryParameters['sharedUrl'];
        } else if (Uri.base.queryParameters.containsKey('sharedUrl')) {
          sharedUrl = Uri.base.queryParameters['sharedUrl'];
        } else {
          // GoRouter: sharedUrl is extracted from state.uri.queryParameters in main.dart, not here.
        }
        return CupertinoPageRoute(
          builder: (_) => SourcesScreen(initialUrl: sharedUrl),
        );
      case '/onboarding':
        return CupertinoPageRoute(builder: (_) => const OnboardingScreen());
      default:
        return CupertinoPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
