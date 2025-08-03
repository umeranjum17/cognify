import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// New imports
import 'firebase_options.dart';
import 'providers/firebase_auth_provider.dart';
import 'providers/subscription_provider.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/subscription/paywall_screen.dart';
import 'services/revenuecat_service.dart';

import 'providers/mode_config_provider.dart';
import 'providers/oauth_auth_provider.dart';
import 'screens/conversation_history_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/home_screen.dart';
import 'screens/oauth_callback_screen.dart';
import 'screens/oauth_onboarding_screen.dart';
import 'screens/sources_screen.dart';
import 'screens/streaming_test_screen.dart';
import 'screens/trending_topics_screen.dart';
import 'services/services_manager.dart';
import 'services/sharing_service.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'widgets/connection_status_indicator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize WebView platform implementation
  WebViewPlatform.instance ??= AndroidWebViewPlatform();

  // Initialize services
  await ServicesManager().initialize();

  // Background service disabled to prevent permission crashes
  // Users can manually enable "Allow background activity" in Android settings if needed
  // await initializeServiceSafely();

  runApp(const CognifyApp());
}

// Resilient background service initialization with graceful error handling
Future<void> initializeServiceSafely() async {
  try {
    debugPrint('🚀 Initializing background service...');

    final service = FlutterBackgroundService();

    // Configure service with graceful error handling
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Don't auto-start to prevent crashes
        isForegroundMode: true,
        notificationChannelId: 'cognify_background',
        initialNotificationTitle: 'Cognify',
        initialNotificationContent: 'Maintaining network connections...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: (service) async => true,
      ),
    );

    debugPrint('✅ Background service configured successfully');

    // Only start service on explicit user action, not automatically
    debugPrint('📋 Background service ready - will start when needed');

  } catch (e, stackTrace) {
    debugPrint('❌ Failed to initialize background service: $e');
    debugPrint('📍 Stack trace: $stackTrace');

    // Log the specific error for debugging
    if (e.toString().contains('permission')) {
      debugPrint('🔐 Permission-related error - app will continue without background functionality');
    } else if (e.toString().contains('service')) {
      debugPrint('⚙️ Service configuration error - app will continue without background functionality');
    } else {
      debugPrint('❓ Unknown error - app will continue without background functionality');
    }

    // Critical: Don't rethrow - allow app to continue without background service
    // This ensures the app doesn't crash even if background service fails
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  print('🚀 Background service started');

  // Background service will maintain network connections
  print('🔧 Initializing background networking...');

  // WebSocket connection for real-time communication
  WebSocketChannel? channel;
  Timer? reconnectTimer;
  int reconnectAttempts = 0;
  const maxReconnectAttempts = 5;
  int activeStreams = 0;

  // Define all functions before using them
  late Function() scheduleReconnect;
  late Function() connectWebSocket;

  scheduleReconnect = () {
    if (reconnectAttempts >= maxReconnectAttempts) {
      print('🚨 Max WebSocket reconnect attempts reached in background');
      return;
    }

    reconnectTimer?.cancel();
    final delay = Duration(seconds: 2 * (reconnectAttempts + 1));

    reconnectTimer = Timer(delay, () {
      reconnectAttempts++;
      print('🔄 Attempting WebSocket reconnect in background (attempt $reconnectAttempts)');
      connectWebSocket();
    });
  };

  connectWebSocket = () async {
    try {
      // Replace with your actual WebSocket endpoint
      const wsUrl = 'wss://echo.websocket.events'; // or your server's WebSocket URL
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      print('📡 WebSocket connected in background');
      reconnectAttempts = 0;

      channel!.stream.listen(
        (message) {
          print('📨 Background received: $message');

          // Update notification with latest activity
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'Cognify Active',
              content: 'Last activity: ${DateTime.now().toLocal().toString().split('.')[0]}',
            );
          }
        },
        onError: (error) {
          print('❌ Background WebSocket error: $error');
          scheduleReconnect();
        },
        onDone: () {
          print('🔒 Background WebSocket closed');
          scheduleReconnect();
        },
      );

    } catch (e) {
      print('❌ Failed to connect WebSocket in background: $e');
      scheduleReconnect();
    }
  };

  // Initial connection
  await connectWebSocket();

  // Periodic heartbeat and connection monitoring
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {

        // Send heartbeat ping
        try {
          channel?.sink.add(jsonEncode({
            'type': 'heartbeat',
            'timestamp': DateTime.now().toIso8601String(),
            'backgroundService': true,
            'activeStreams': activeStreams,
          }));
        } catch (e) {
          print('❌ Failed to send heartbeat: $e');
        }

        // Update notification with simple status
        service.setForegroundNotificationInfo(
          title: 'Cognify Background 🔄',
          content: 'Active streams: $activeStreams | ${DateTime.now().toLocal().toString().split('.')[0]}',
        );

        print('💓 Background heartbeat sent - Active streams: $activeStreams');
      }
    }
  });

  // Handle service stop
  service.on('stopService').listen((event) {
    print('🛑 Background service stopping...');
    channel?.sink.close();
    reconnectTimer?.cancel();
    service.stopSelf();
  });

  print('✅ Background service fully initialized');
}

class CognifyApp extends StatefulWidget {
  const CognifyApp({super.key});

  @override
  State<CognifyApp> createState() => _CognifyAppState();
}

class _CognifyAppState extends State<CognifyApp> with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ModeConfigProvider()),
        ChangeNotifierProvider(create: (_) => OAuthAuthProvider()),
        // New providers
        ChangeNotifierProvider(create: (_) => FirebaseAuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'Cognify Flutter',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return ConnectionStatusBanner(
                  child: PopScope(
                    canPop: true,
                    onPopInvokedWithResult: (didPop, result) async {
                  if (didPop) return;

                  final router = GoRouter.of(context);
                  final currentLocation = GoRouterState.of(context).uri.toString();

                  print('🔙 Back button pressed. Current location: $currentLocation');
                  print('🔙 Can pop: ${router.canPop()}');

                  // Check if we're on the home screen (root route)
                  if (currentLocation == '/' || currentLocation == '/home') {
                    // If we're on the home screen, show exit confirmation
                    print('🔙 On home screen, showing exit confirmation...');
                    final shouldExit = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Exit App'),
                        content: const Text('Are you sure you want to exit?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Exit'),
                          ),
                        ],
                      ),
                    );
                    if (shouldExit == true) {
                      print('🔙 Exiting app...');
                      SystemNavigator.pop();
                    }
                  } else if (router.canPop()) {
                    // If we can pop, do it
                    print('🔙 Popping route...');
                    router.pop();
                  } else {
                    // Fallback: navigate to home
                    print('🔙 Navigating to home...');
                    router.go('/');
                  }
                    },
                    child: child!,
                  ),
                  );
            },
          );
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Check for shared content when app resumes
    if (state == AppLifecycleState.resumed) {
      SharingService().checkForSharedContent().then((_) {
        final sharedUrl = SharingService().getPendingSharedUrl();
        if (sharedUrl != null && sharedUrl.isNotEmpty && mounted) {
          final encodedUrl = Uri.encodeQueryComponent(sharedUrl);
          _router.go('/sources?sharedUrl=$encodedUrl');
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SharingService().dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize sharing service after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });

    final initialLocation = Uri.base.path.isEmpty ? '/' : Uri.base.path;
    print('🚀 Initial location: $initialLocation');
    print('🚀 Base URI: ${Uri.base}');
    
    _router = GoRouter(
      initialLocation: initialLocation,
      debugLogDiagnostics: true,
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) {
            print('🏠 Root route hit with path: ${state.uri.path}');
            print('🏠 Full URI: ${state.uri}');
            print('🏠 Query parameters: ${state.uri.queryParameters}');

            // Check if we have a shared URL to redirect
            final sharedUrl = state.uri.queryParameters['sharedUrl'];
            if (sharedUrl != null && sharedUrl.isNotEmpty) {
              return MaterialPage(
                key: state.pageKey,
                child: SourcesScreen(initialUrl: sharedUrl),
              );
            }

            // If user has Firebase session, initialize RevenueCat with UID
            final firebaseAuth = context.read<FirebaseAuthProvider>();
            final subs = context.read<SubscriptionProvider>();
            if (!subs.initialized) {
              subs.initialize(appUserId: firebaseAuth.uid);
            }

            // Check OpenRouter API auth (legacy) for editor access, otherwise show onboarding
            return MaterialPage(
              key: state.pageKey,
              child: Consumer<OAuthAuthProvider>(
                builder: (context, authProvider, child) {
                  // If authenticated, go directly to editor
                  if (authProvider.isAuthenticated) {
                    // Use a post-frame callback to navigate to avoid navigation during build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        context.go('/editor');
                      }
                    });
                    // Show a loading screen while navigating
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  // If not authenticated, show onboarding
                  return const OAuthOnboardingScreen();
                },
              ),
            );
          },
        ),
        // OAuth onboarding route
        GoRoute(
          path: '/oauth-onboarding',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const OAuthOnboardingScreen(),
          ),
        ),
        // Test route
        GoRoute(
          path: '/test',
          pageBuilder: (context, state) {
            print('🧪 Test route hit!');
            return MaterialPage(
              key: state.pageKey,
              child: const Scaffold(
                body: Center(
                  child: Text('Test route works!'),
                ),
              ),
            );
          },
        ),
        // OAuth callback route
        GoRoute(
          path: '/oauth/callback',
          pageBuilder: (context, state) {
            print('🔄 OAuth callback route DEFINITELY hit!');
            print('🔄 GoRouter URI: ${state.uri}');
            print('🔄 Browser URL: ${Uri.base}');

            // On web, use Uri.base to get the actual browser URL with query parameters
            final actualUri = kIsWeb ? Uri.base : state.uri;
            print('🔄 Actual URI: $actualUri');
            print('🔄 Query string: ${actualUri.query}');
            print('🔄 Query parameters: ${actualUri.queryParameters}');

            // Extract OAuth parameters from the actual browser URL
            final code = actualUri.queryParameters['code'];
            final stateParam = actualUri.queryParameters['state'];
            final error = actualUri.queryParameters['error'];

            print('🔄 OAuth callback route hit - code: ${code != null && code.length > 10 ? '${code.substring(0, 10)}...' : code}, state: ${stateParam != null && stateParam.length > 20 ? '${stateParam.substring(0, 20)}...' : stateParam}, error: $error');

            // Use the dedicated OAuth callback screen
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
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const HomeScreen(),
          ),
        ),
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
        GoRoute(
          path: '/history',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const ConversationHistoryScreen(),
          ),
        ),

        GoRoute(
          path: '/streaming-test',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const StreamingTestScreen(),
          ),
        ),
        // Home/Dashboard route (accessible from menu)
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const HomeScreen(),
          ),
        ),
        // Trending topics route (premium feature)
        GoRoute(
          path: '/trending-topics',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const TrendingTopicsScreen(),
          ),
        ),
        // New: Sign-in and Paywall routes
        GoRoute(
          path: '/sign-in',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const SignInScreen(),
          ),
        ),
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
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const Scaffold(
              body: Center(
                child: Text('Subscription Screen - Coming Soon'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _initializeApp() async {
    await SharingService().initialize(context);

    // Initialize user service
    try {
      final userId = await UserService().initializeUser();
      print('👤 [USER] Initialized user with ID: $userId');
    } catch (e) {
      print('❌ [USER] Error initializing user service: $e');
    }

    // Initialize RevenueCat with Firebase UID if logged-in
    try {
      final firebaseAuth = context.read<FirebaseAuthProvider>();
      if (firebaseAuth.isSignedIn && firebaseAuth.uid != null) {
        await RevenueCatService.instance.initialize(appUserId: firebaseAuth.uid);
      } else {
        await RevenueCatService.instance.initialize();
      }
    } catch (e) {
      print('❌ [RevenueCat] Initialization error: $e');
    }

    // Check for shared content and redirect if needed
    final sharedUrl = SharingService().getPendingSharedUrl();
    if (sharedUrl != null && sharedUrl.isNotEmpty) {
      // Navigate to sources screen with the shared URL
      if (mounted) {
        final encodedUrl = Uri.encodeQueryComponent(sharedUrl);
        _router.go('/sources?sharedUrl=$encodedUrl');
      }
    }
  }
}
