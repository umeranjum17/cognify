import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:go_router/go_router.dart';
import 'router/app_router.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'providers/app_access_provider.dart';
import 'providers/firebase_auth_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/usage_quota_provider.dart';
import 'services/revenuecat_service.dart';

import 'providers/mode_config_provider.dart';
import 'providers/tab_provider.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'utils/logger.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable Provider debug checks to prevent subtype warnings
  Provider.debugCheckInvalidValueType = null;

  // Initialize WebView platform implementation
  if (defaultTargetPlatform == TargetPlatform.android) {
    WebViewPlatform.instance ??= AndroidWebViewPlatform();
  }

  // Initialize logger with appropriate verbosity
  Logger.setLevel(LogLevel.info);

  // Ensure any previously running background service is stopped on launch
  // This prevents crashes if a lingering service tries to post a notification without permission
  try {
    final backgroundService = FlutterBackgroundService();
    final isRunning = await backgroundService.isRunning();
    if (isRunning) {
      backgroundService.invoke('stopService');
    }
  } catch (_) {
    // Ignore - service might not be initialized yet in this install
  }

  // Background service disabled to prevent permission crashes
  // Users can manually enable "Allow background activity" in Android settings if needed
  // await initializeServiceSafely();

  runApp(const CognifyApp());
}

// Resilient background service initialization with graceful error handling
Future<void> initializeServiceSafely() async {
  try {
    Logger.info(
      '🚀 Initializing background service...',
      tag: 'BackgroundService',
    );

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

    Logger.info(
      '✅ Background service configured successfully',
      tag: 'BackgroundService',
    );

    // Only start service on explicit user action, not automatically
    Logger.info(
      '📋 Background service ready - will start when needed',
      tag: 'BackgroundService',
    );
  } catch (e, stackTrace) {
    Logger.error(
      '❌ Failed to initialize background service: $e',
      tag: 'BackgroundService',
    );
    Logger.error('📍 Stack trace: $stackTrace', tag: 'BackgroundService');

    // Log the specific error for debugging
    if (e.toString().contains('permission')) {
      Logger.warn(
        '🔐 Permission-related error - app will continue without background functionality',
        tag: 'BackgroundService',
      );
    } else if (e.toString().contains('service')) {
      Logger.warn(
        '⚙️ Service configuration error - app will continue without background functionality',
        tag: 'BackgroundService',
      );
    } else {
      Logger.warn(
        '❓ Unknown error - app will continue without background functionality',
        tag: 'BackgroundService',
      );
    }

    // Critical: Don't rethrow - allow app to continue without background service
    // This ensures the app doesn't crash even if background service fails
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  Logger.info('🚀 Background service started', tag: 'BackgroundService');

  // Background service will maintain network connections
  Logger.info(
    '🔧 Initializing background networking...',
    tag: 'BackgroundService',
  );

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
      Logger.warn(
        '🚨 Max WebSocket reconnect attempts reached in background',
        tag: 'BackgroundService',
      );
      return;
    }

    reconnectTimer?.cancel();
    final delay = Duration(seconds: 2 * (reconnectAttempts + 1));

    reconnectTimer = Timer(delay, () {
      reconnectAttempts++;
      Logger.info(
        '🔄 Attempting WebSocket reconnect in background (attempt $reconnectAttempts)',
        tag: 'BackgroundService',
      );
      connectWebSocket();
    });
  };

  connectWebSocket = () async {
    try {
      // Replace with your actual WebSocket endpoint
      const wsUrl =
          'wss://echo.websocket.events'; // or your server's WebSocket URL
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      Logger.info(
        '📡 WebSocket connected in background',
        tag: 'BackgroundService',
      );
      reconnectAttempts = 0;

      channel!.stream.listen(
        (message) {
          Logger.debug(
            '📨 Background received: $message',
            tag: 'BackgroundService',
          );

          // Update notification with latest activity
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'Cognify Active',
              content:
                  'Last activity: ${DateTime.now().toLocal().toString().split('.')[0]}',
            );
          }
        },
        onError: (error) {
          Logger.error(
            '❌ Background WebSocket error: $error',
            tag: 'BackgroundService',
          );
          scheduleReconnect();
        },
        onDone: () {
          Logger.info(
            '🔒 Background WebSocket closed',
            tag: 'BackgroundService',
          );
          scheduleReconnect();
        },
      );
    } catch (e) {
      Logger.error(
        '❌ Failed to connect WebSocket in background: $e',
        tag: 'BackgroundService',
      );
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
          channel?.sink.add(
            jsonEncode({
              'type': 'heartbeat',
              'timestamp': DateTime.now().toIso8601String(),
              'backgroundService': true,
              'activeStreams': activeStreams,
            }),
          );
        } catch (e) {
          Logger.error(
            '❌ Failed to send heartbeat: $e',
            tag: 'BackgroundService',
          );
        }

        // Update notification with simple status
        service.setForegroundNotificationInfo(
          title: 'Cognify Background 🔄',
          content:
              'Active streams: $activeStreams | ${DateTime.now().toLocal().toString().split('.')[0]}',
        );

        Logger.debug(
          '💓 Background heartbeat sent - Active streams: $activeStreams',
          tag: 'BackgroundService',
        );
      }
    }
  });

  // Handle service stop
  service.on('stopService').listen((event) {
    Logger.info('🛑 Background service stopping...', tag: 'BackgroundService');
    channel?.sink.close();
    reconnectTimer?.cancel();
    service.stopSelf();
  });

  Logger.info(
    '✅ Background service fully initialized',
    tag: 'BackgroundService',
  );
}

class CognifyApp extends StatefulWidget {
  const CognifyApp({super.key});

  @override
  State<CognifyApp> createState() => _CognifyAppState();
}

class _CognifyAppState extends State<CognifyApp> with WidgetsBindingObserver {
  GoRouter? _router;
  late AppLinks _appLinks;
  StreamSubscription? _linkSubscription;
  ThemeProvider? _themeProvider;
  FirebaseAuthProvider? _firebaseAuthProvider;
  bool _isInitializing = true;

  @override
  Widget build(BuildContext context) {
    // Show consistent loading screen while initializing
    if (_isInitializing ||
        _themeProvider == null ||
        _firebaseAuthProvider == null ||
        _router == null) {
      return MaterialApp(
        theme: lightTheme,
        darkTheme: darkTheme,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.smart_toy, size: 48, color: Colors.white),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Starting Cognify...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeProvider!),
        ChangeNotifierProvider.value(value: _firebaseAuthProvider!),
        ChangeNotifierProvider(create: (_) => ModeConfigProvider()),
        ChangeNotifierProvider(create: (_) => TabProvider()),
        ChangeNotifierProxyProvider<FirebaseAuthProvider, UsageQuotaProvider>(
          create: (_) => UsageQuotaProvider(),
          update: (_, auth, quota) {
            quota ??= UsageQuotaProvider();
            quota.attach(auth: auth);
            return quota;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'Cognify Flutter',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: _router!,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return PopScope(
                canPop: true,
                onPopInvokedWithResult: (didPop, result) async {
                  if (didPop) return;

                  final router = GoRouter.of(context);
                  final currentLocation = GoRouterState.of(
                    context,
                  ).uri.toString();

                  Logger.debug(
                    '🔙 Back button pressed. Current location: $currentLocation',
                    tag: 'Navigation',
                  );
                  Logger.debug(
                    '🔙 Can pop: ${router.canPop()}',
                    tag: 'Navigation',
                  );

                  // Check if we're on the home screen (root route)
                  if (currentLocation == '/' || currentLocation == '/home') {
                    // If we're on the home screen, show exit confirmation
                    Logger.debug(
                      '🔙 On home screen, showing exit confirmation...',
                      tag: 'Navigation',
                    );
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
                      Logger.info('🔙 Exiting app...', tag: 'Navigation');
                      SystemNavigator.pop();
                    }
                  } else if (router.canPop()) {
                    // If we can pop, do it
                    Logger.debug('🔙 Popping route...', tag: 'Navigation');
                    router.pop();
                  } else {
                    // Fallback: navigate to home
                    Logger.debug('🔙 Navigating to home...', tag: 'Navigation');
                    router.go('/');
                  }
                },
                child: child!,
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _firebaseAuthProvider = FirebaseAuthProvider();

    // Initialize everything before building UI
    _initializeApp();

    // Initialize app links for deep linking
    _initializeAppLinks();

    // Delay router creation until after auth provider is initialized
    // This prevents the onboarding screen from flashing for authenticated users
  }

  void _initializeAppLinks() {
    if (!kIsWeb) {
      _appLinks = AppLinks();

      // Handle links when app is already running
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          Logger.info('🔗 Deep link received: $uri', tag: 'DeepLink');
          _handleDeepLink(uri);
        },
        onError: (err) {
          Logger.error('🔗 Deep link error: $err', tag: 'DeepLink');
        },
      );

      // Handle initial link if app was launched from a link
      _appLinks
          .getInitialLink()
          .then((uri) {
            if (uri != null) {
              Logger.info('🔗 Initial deep link: $uri', tag: 'DeepLink');
              _handleDeepLink(uri);
            }
          })
          .catchError((err) {
            Logger.error('🔗 Initial deep link error: $err', tag: 'DeepLink');
          });
    }
  }

  void _handleDeepLink(Uri uri) {
    Logger.info('🔗 Deep link received: $uri', tag: 'DeepLink');
    // Additional deep-link handling (e.g., magic links) can be wired here.
  }

  Future<void> _initializeApp() async {
    try {
      Logger.info('🚀 Starting app initialization...', tag: 'AppInit');

      // Initialize theme provider first (synchronously)
      _themeProvider = await ThemeProvider.create();
      Logger.info('✅ Theme provider initialized', tag: 'AppInit');

      await _firebaseAuthProvider!.initialize();
      Logger.info('✅ Firebase auth provider initialized', tag: 'AppInit');

      // Create router after auth provider is initialized
      final defaultRouteName =
          WidgetsBinding.instance.platformDispatcher.defaultRouteName;
      final initialLocation = AppRouter.normalizeInitialLocation(
        defaultRouteName,
      );
      Logger.debug(
        '🚀 Initial location (normalized): $initialLocation',
        tag: 'AppInit',
      );
      Logger.debug('🚀 Base URI: ${Uri.base}', tag: 'AppInit');
      Logger.debug('🚀 defaultRouteName: $defaultRouteName', tag: 'AppInit');
      _router = AppRouter.createRouter(
        initialLocation: initialLocation,
        authProvider: _firebaseAuthProvider!,
      );
      Logger.info('✅ Router initialized', tag: 'AppInit');

      // Mark initialization complete
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }

      Logger.info('✅ Core initialization complete', tag: 'AppInit');

      // Initialize other services after UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeSecondaryServices();
      });
    } catch (e) {
      Logger.error('❌ Error during app initialization: $e', tag: 'AppInit');
      // Fallback initialization
      _themeProvider ??= ThemeProvider();
      _firebaseAuthProvider ??= FirebaseAuthProvider();

      // Create fallback router
      if (_router == null) {
        final defaultRouteName =
            WidgetsBinding.instance.platformDispatcher.defaultRouteName;
        final initialLocation = AppRouter.normalizeInitialLocation(
          defaultRouteName,
        );
        _router = AppRouter.createRouter(
          initialLocation: initialLocation,
          authProvider: _firebaseAuthProvider!,
        );
      }

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _initializeSecondaryServices() async {
    try {
      // Initialize user service
      try {
        final userId = await UserService().initializeUser();
        Logger.info(
          '👤 [USER] Initialized user with ID: $userId',
          tag: 'UserService',
        );
      } catch (e) {
        Logger.error(
          '❌ [USER] Error initializing user service: $e',
          tag: 'UserService',
        );
      }

      // RevenueCat/subscription initialization removed; access is quota/token-based.
    } catch (e) {
      Logger.error(
        '❌ Error initializing secondary services: $e',
        tag: 'AppInit',
      );
    }
  }
}
