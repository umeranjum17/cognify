import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/firebase_auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/oauth_auth_provider.dart';
import '../providers/app_access_provider.dart';

import '../screens/home_screen.dart';
import '../screens/editor_screen.dart';
import '../screens/sources_screen.dart';
import '../screens/streaming_test_screen.dart';
import '../screens/conversation_history_screen.dart';
import '../screens/trending_topics_screen.dart';
import '../screens/oauth_onboarding_screen.dart';
import '../screens/oauth_callback_screen.dart';
import '../screens/subscription/paywall_screen.dart';

class AppRouter {
  AppRouter._();

  static GoRouter createRouter({
    required String initialLocation,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      debugLogDiagnostics: true,
      redirect: (context, state) {
        final loc = state.uri.toString();
        // Defensive: catch custom schemes or full URLs and normalize
        if (loc.contains('://')) {
          final u = Uri.tryParse(loc);
          debugPrint('🧯 [RouterRedirect] Intercepted location="$loc" parsed="$u"');
          if (u != null && u.scheme == 'cognify') {
            debugPrint('🧯 [RouterRedirect] Rerouting custom-scheme to /editor');
            return '/editor';
          }
          if (u != null && (u.scheme == 'http' || u.scheme == 'https')) {
            final pathOnly =
                Uri(path: u.path, queryParameters: u.queryParameters).toString();
            final fixed = pathOnly.startsWith('/') ? pathOnly : '/$pathOnly';
            debugPrint('🧯 [RouterRedirect] Rerouting http(s) to "$fixed"');
            return fixed;
          }
        }
        return null;
      },
      routes: [
        // Root route with special behavior:
        // - sharedUrl redirection to SourcesScreen
        // - initialize SubscriptionProvider with Firebase UID (single init)
        GoRoute(
          path: '/',
          pageBuilder: (context, state) {
            debugPrint('🏠 Root route hit with path: ${state.uri.path}');
            debugPrint('🏠 Full URI: ${state.uri}');
            debugPrint('🏠 Query parameters: ${state.uri.queryParameters}');

            final sharedUrl = state.uri.queryParameters['sharedUrl'];
            if (sharedUrl != null && sharedUrl.isNotEmpty) {
              return MaterialPage(
                key: state.pageKey,
                child: SourcesScreen(initialUrl: sharedUrl),
              );
            }

            // Initialize RevenueCat via SubscriptionProvider with Firebase UID
            final firebaseAuth = context.read<FirebaseAuthProvider>();
            final subs = context.read<SubscriptionProvider>();
            if (!subs.initialized) {
              subs.initialize(appUserId: firebaseAuth.uid);
              // Also wire auth to sync identity changes
              subs.wireAuth(firebaseAuth);
            }

            // Legacy OpenRouter auth handling: if authenticated, navigate to editor
            return MaterialPage(
              key: state.pageKey,
              child: Consumer<OAuthAuthProvider>(
                builder: (context, authProvider, child) {
                  if (authProvider.isAuthenticated) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        context.go('/editor');
                      }
                    });
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return const OAuthOnboardingScreen();
                },
              ),
            );
          },
        ),

        // OAuth onboarding
        GoRoute(
          path: '/oauth-onboarding',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const OAuthOnboardingScreen(),
          ),
        ),

        // OAuth callback
        GoRoute(
          path: '/oauth/callback',
          pageBuilder: (context, state) {
            debugPrint('🔄 OAuth callback route DEFINITELY hit!');
            debugPrint('🔄 GoRouter URI: ${state.uri}');
            debugPrint('🔄 Browser URL: ${Uri.base}');

            final actualUri = kIsWeb ? Uri.base : state.uri;
            debugPrint('🔄 Actual URI: $actualUri');
            debugPrint('🔄 Query string: ${actualUri.query}');
            debugPrint('🔄 Query parameters: ${actualUri.queryParameters}');

            final code = actualUri.queryParameters['code'];
            final stateParam = actualUri.queryParameters['state'];
            final error = actualUri.queryParameters['error'];

            debugPrint(
                '🔄 OAuth callback - code: ${code != null && code.length > 10 ? '${code.substring(0, 10)}...' : code}, state: ${stateParam != null && stateParam.length > 20 ? '${stateParam.substring(0, 20)}...' : stateParam}, error: $error');

            return MaterialPage(
              key: state.pageKey,
              child: OAuthCallbackScreen(
                code: code,
                state: stateParam,
                error: error,
              ),
            );
          },
        ),

        // Home/Dashboard route
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const HomeScreen(),
          ),
        ),

        // Editor (supports prompt and conversationId query params)
        GoRoute(
          path: '/editor',
          pageBuilder: (context, state) {
            final prompt = state.uri.queryParameters['prompt'];
            final conversationId = state.uri.queryParameters['conversationId'];
            return MaterialPage(
              key: state.pageKey,
              child: EditorScreen(
                prompt: prompt,
                conversationId: conversationId,
              ),
            );
          },
        ),

        // Sources (supports sharedUrl parameter)
        GoRoute(
          path: '/sources',
          pageBuilder: (context, state) {
            final sharedUrl = state.uri.queryParameters['sharedUrl'];
            return MaterialPage(
              key: state.pageKey,
              child: SourcesScreen(initialUrl: sharedUrl),
            );
          },
        ),

        // Conversation history
        GoRoute(
          path: '/history',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const ConversationHistoryScreen(),
          ),
        ),

        // Streaming test
        GoRoute(
          path: '/streaming-test',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const StreamingTestScreen(),
          ),
        ),

        // Trending topics (premium feature; guard where used with PremiumGuard widget)
        GoRoute(
          path: '/trending-topics',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const TrendingTopicsScreen(),
          ),
        ),

        // Paywall
        GoRoute(
          path: '/paywall',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const PaywallScreen(),
          ),
        ),

        // Subscription management placeholder
        GoRoute(
          path: '/subscription',
          pageBuilder: (context, state) => const MaterialPage(
            child: Scaffold(
              body: Center(
                child: Text('Subscription Screen - Coming Soon'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Normalizes the initial location used by GoRouter to avoid custom scheme pitfalls.
  static String normalizeInitialLocation(String defaultRouteName) {
    try {
      String incoming = defaultRouteName;
      debugPrint('🔍 [DL] defaultRouteName(raw): $incoming');
      debugPrint('🔍 [DL] Uri.base at init: ${Uri.base}');
      if (incoming.contains('://')) {
        final u = Uri.parse(incoming);
        debugPrint(
            '🔍 [DL] Parsed incoming => scheme=${u.scheme}, host=${u.host}, path=${u.path}, query=${u.query}');
        if (u.scheme == 'cognify') {
          debugPrint('🛡️ [DL] Custom scheme detected. Rerouting to /editor');
          return '/editor';
        } else {
          final normalized =
              Uri(path: u.path, queryParameters: u.queryParameters).toString();
          return normalized.startsWith('/') ? normalized : '/$normalized';
        }
      } else if (incoming.startsWith('/')) {
        return incoming;
      } else if (Uri.base.path.isNotEmpty) {
        final base = Uri.base.toString();
        final normalized = base.contains('http')
            ? base.substring(base.indexOf('/', base.indexOf('://') + 3))
            : Uri.base.path;
        return normalized.startsWith('/') ? normalized : '/$normalized';
      } else {
        return '/';
      }
    } catch (e, st) {
      debugPrint('❌ [DL] Error parsing initial location: $e');
      debugPrint('❌ [DL] Stack: $st');
      return '/';
    }
  }
}