import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/firebase_auth_provider.dart';

import '../screens/auth/sign_in_screen.dart';
import '../screens/conversation_history_screen.dart';
import '../screens/editor_screen.dart';
import '../screens/tabbed_editor_screen.dart';
import '../widgets/auth_guard.dart';
import '../services/analytics_service.dart';

class AppRouter {
  AppRouter._();

  static GoRouter createRouter({
    required String initialLocation,
    required FirebaseAuthProvider authProvider,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      debugLogDiagnostics: true,
      refreshListenable: authProvider,
      observers: [AnalyticsRouteObserver()],
      redirect: (context, state) {
        final loc = state.uri.toString();
        final isInitializing =
            authProvider.initializing && !authProvider.initialized;
        if (isInitializing) {
          return null;
        }

        final signedIn = authProvider.isSignedIn;
        final loggingIn = state.matchedLocation == '/sign-in';

        if (!signedIn) {
          if (loggingIn) {
            return null;
          }
          final qp = Map<String, String>.from(state.uri.queryParameters);
          return Uri(
            path: '/sign-in',
            queryParameters: qp.isEmpty ? null : qp,
          ).toString();
        }

        if (signedIn && loggingIn) {
          return '/editor';
        }

        if (loc.contains('://')) {
          final u = Uri.tryParse(loc);
          debugPrint(
            '🧯 [RouterRedirect] Intercepted location="$loc" parsed="$u"',
          );
          if (u != null && u.scheme == 'cognify') {
            debugPrint(
              '🧯 [RouterRedirect] Rerouting custom-scheme to /editor',
            );
            return '/editor';
          }
          if (u != null && (u.scheme == 'http' || u.scheme == 'https')) {
            final pathOnly = Uri(
              path: u.path,
              queryParameters: u.queryParameters,
            ).toString();
            final fixed = pathOnly.startsWith('/') ? pathOnly : '/$pathOnly';
            debugPrint('🧯 [RouterRedirect] Rerouting http(s) to "$fixed"');
            return fixed;
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (context, state) {
            final firebaseAuth = context.read<FirebaseAuthProvider>();
            final sharedUrl = state.uri.queryParameters['sharedUrl'];

            if (!firebaseAuth.initialized || firebaseAuth.initializing) {
              return const MaterialPage(
                child: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (!firebaseAuth.isSignedIn) {
              return MaterialPage(
                key: state.pageKey,
                child: SignInScreen(pendingSharedUrl: sharedUrl),
              );
            }

            return const MaterialPage(child: TabbedEditorScreen());
          },
        ),
        GoRoute(
          path: '/sign-in',
          name: 'sign_in',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: SignInScreen(
              pendingSharedUrl: state.uri.queryParameters['sharedUrl'],
            ),
          ),
        ),
        GoRoute(
          path: '/editor',
          name: 'editor',
          pageBuilder: (context, state) {
            final prompt = state.uri.queryParameters['prompt'];
            final conversationId = state.uri.queryParameters['conversationId'];
            final role = state.uri.queryParameters['role'];
            final contextInfo = state.uri.queryParameters['contextInfo'];
            return MaterialPage(
              key: state.pageKey,
              child: AuthGuard(
                redirectTo: '/',
                child: TabbedEditorScreen(
                  prompt: prompt,
                  conversationId: conversationId,
                  role: role,
                  contextInfo: contextInfo,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/history',
          name: 'history',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const AuthGuard(
              redirectTo: '/',
              child: ConversationHistoryScreen(),
            ),
          ),
        ),
        // Paywall removed; access is quota/token based.
      ],
    );
  }

  static String normalizeInitialLocation(String defaultRouteName) {
    try {
      String incoming = defaultRouteName;
      debugPrint('🔍 [DL] defaultRouteName(raw): $incoming');
      debugPrint('🔍 [DL] Uri.base at init: ${Uri.base}');
      if (incoming.contains('://')) {
        final u = Uri.parse(incoming);
        debugPrint(
          '🔍 [DL] Parsed incoming => scheme=${u.scheme}, host=${u.host}, path=${u.path}, query=${u.query}',
        );
        if (u.scheme == 'cognify') {
          debugPrint('🛡️ [DL] Custom scheme detected. Rerouting to /editor');
          return '/editor';
        } else {
          final normalized = Uri(
            path: u.path,
            queryParameters: u.queryParameters,
          ).toString();
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
