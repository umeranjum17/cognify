import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'providers/app_access_provider.dart';
import 'providers/firebase_auth_provider.dart';
import 'providers/credits_purchase_provider.dart';
import 'providers/usage_quota_provider.dart';
import 'providers/credits_provider.dart';
import 'services/revenuecat_service.dart';

import 'providers/mode_config_provider.dart';
import 'providers/tab_provider.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'utils/logger.dart';
import 'config/app_config.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'services/service_cache_manager.dart';
import 'services/service_migration_helper.dart';
import 'services/request_usage_estimator.dart';
import 'api/api.dart';
import 'utils/version.dart';
import 'widgets/update_required_screen.dart';
import 'widgets/update_soft_prompt.dart';
import 'widgets/cognify_logo.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable Provider debug checks to prevent subtype warnings
  Provider.debugCheckInvalidValueType = null;

  // Initialize logger with appropriate verbosity
  Logger.setLevel(LogLevel.info);

  // Initialize WebView platform implementation (synchronous)
  if (defaultTargetPlatform == TargetPlatform.android) {
    WebViewPlatform.instance ??= AndroidWebViewPlatform();
  }

  // CRITICAL: Await cache warm-ups BEFORE runApp so providers have data
  // This is fast (~10-50ms) since SharedPreferences caches internally
  await SharedPreferences.getInstance();
  await Future.wait([
    CreditsProvider.warmUp(),
    RequestUsageEstimator.warmUp(),
  ]);

  // Now start app - providers will have cached data ready
  runApp(const CognifyApp());

  // Fire off remaining async initializations (non-blocking)
  _initializeServicesInBackground();
}

/// Runs all async initialization work in the background after the app has started.
void _initializeServicesInBackground() {
  // Note: SharedPreferences and cache warm-ups are kicked off before runApp() for faster startup

  // Load environment variables (optional, non-blocking)
  unawaited(() async {
    try {
      const compileTimeBackend = String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
      if (compileTimeBackend.isEmpty) {
        await dotenv.load(fileName: ".env");
      }
    } catch (_) {
      // Silent: we have sane fallbacks
    }
  }());

  // Initialize Firebase (non-blocking - CognifyApp handles waiting for it)
  unawaited(() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Optional: connect to Firestore emulator when env is set
      final emulator = dotenv.maybeGet('FIRESTORE_EMULATOR_HOST');
      if (emulator != null && emulator.isNotEmpty && !kIsWeb) {
        final parts = emulator.split(':');
        final host = parts.first;
        final port = int.tryParse(parts.length > 1 ? parts[1] : '8080') ?? 8080;
        FirebaseFirestore.instance.useFirestoreEmulator(host, port);
        Logger.info('🧪 Using Firestore emulator at $host:$port', tag: 'Firebase');
      }
      // Enable offline persistence for efficient sync
      try {
        FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
        Logger.info('📦 Firestore persistence enabled', tag: 'Firebase');
      } catch (e) {
        Logger.warn('⚠️ Could not enable Firestore persistence: $e', tag: 'Firebase');
      }
    } catch (e) {
      Logger.error('❌ Firebase initialization failed early: $e', tag: 'Firebase');
    }
  }());

  // Stop any lingering background service (non-blocking)
  unawaited(() async {
    try {
      final backgroundService = FlutterBackgroundService();
      final isRunning = await backgroundService.isRunning();
      if (isRunning) {
        backgroundService.invoke('stopService');
      }
    } catch (_) {
      // Ignore - service might not be initialized yet
    }
  }());
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
  late GoRouter _router;
  late AppLinks _appLinks;
  StreamSubscription? _linkSubscription;
  late final ThemeProvider _themeProvider;
  late final FirebaseAuthProvider _firebaseAuthProvider;
  bool _hardBlocked = false;
  String _updateUrl = '';
  String _lastSoftPromptVersion = '';

  @override
  Widget build(BuildContext context) {
    // Hard block for forced updates - rare case
    if (_hardBlocked && _updateUrl.isNotEmpty) {
      return MaterialApp(
        theme: lightTheme,
        darkTheme: darkTheme,
        home: UpdateRequiredScreen(updateUrl: _updateUrl),
        debugShowCheckedModeBanner: false,
      );
    }

    // Render the app immediately - no loading screen!
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeProvider),
        ChangeNotifierProvider.value(value: _firebaseAuthProvider),
        ChangeNotifierProvider(create: (_) => ModeConfigProvider()),
        ChangeNotifierProvider(create: (_) => TabProvider()),
        // Provide CreditsPurchaseProvider app-wide and wire it to FirebaseAuthProvider.
        ChangeNotifierProxyProvider<FirebaseAuthProvider, CreditsPurchaseProvider>(
          create: (_) => CreditsPurchaseProvider(),
          update: (_, auth, provider) {
            final instance = provider ?? CreditsPurchaseProvider();
            instance.wireAuth(auth);
            return instance;
          },
        ),
        ChangeNotifierProxyProvider<FirebaseAuthProvider, UsageQuotaProvider>(
          create: (_) => UsageQuotaProvider(),
          update: (_, auth, quota) {
            quota ??= UsageQuotaProvider();
            quota.attach(auth: auth);
            return quota;
          },
        ),
        ChangeNotifierProxyProvider<FirebaseAuthProvider, CreditsProvider>(
          create: (_) => CreditsProvider(),
          update: (_, auth, credits) {
            credits ??= CreditsProvider();
            credits.attach(auth: auth);
            return credits;
          },
        ),
        // Anonymous limit gating removed; purchases work without login
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
    if (state == AppLifecycleState.resumed) {
      _recheckRemoteConfig();
    }
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

    // Create providers synchronously - they initialize in background and notify listeners
    _themeProvider = ThemeProvider();
    _firebaseAuthProvider = FirebaseAuthProvider();

    // Create router immediately - it handles "initializing" state via redirect
    final defaultRouteName =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final initialLocation = AppRouter.normalizeInitialLocation(defaultRouteName);
    _router = AppRouter.createRouter(
      initialLocation: initialLocation,
      authProvider: _firebaseAuthProvider,
    );

    // Kick off background initialization (non-blocking)
    _initializeApp();

    // Initialize app links for deep linking
    _initializeAppLinks();
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

  void _initializeApp() {
    Logger.info('🚀 Starting instant app initialization...', tag: 'AppInit');

    // Auth provider initializes in background and notifies listeners when ready
    unawaited(_firebaseAuthProvider.initialize().then((_) {
      Logger.info('✅ Firebase auth provider initialized', tag: 'AppInit');
    }));

    // Warm up service cache in background (non-blocking)
    // Note: CreditsProvider and RequestUsageEstimator warm-up is done earlier in _initializeServicesInBackground
    unawaited(_initializeServiceCache());

    // Fetch remote config in background, apply when ready
    unawaited(_fetchRemoteConfigGateResult().then((gateResult) {
      _applyRemoteConfigGateResult(gateResult);
      _maybePromptForSoftUpdate(gateResult);
    }));

    // Initialize secondary services after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeSecondaryServices();
    });

    Logger.info('✅ Instant initialization complete', tag: 'AppInit');
  }

  /// Initialize service cache manager for faster subsequent loads
  Future<void> _initializeServiceCache() async {
    try {
      // Perform migration if needed
      await ServiceMigrationHelper.performMigrationIfNeeded();
      
      // Initialize the service cache manager
      final serviceCacheManager = ServiceCacheManager();
      await serviceCacheManager.initialize();
      Logger.info('✅ Service cache manager initialized', tag: 'AppInit');
    } catch (e) {
      Logger.warn('⚠️ Service cache initialization failed, continuing without cache: $e', tag: 'AppInit');
    }
  }

  Future<_RemoteConfigGateResult> _fetchRemoteConfigGateResult({bool forceRefresh = false}) async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: _resolveRemoteConfigInterval(forceRefresh: forceRefresh),
        ),
      );
      await rc.setDefaults({
        'backend_base_url': AppConfig.backendBaseUrl,
        'min_supported_version': AppConfig.defaultMinSupportedVersion,
        'soft_min_version': AppConfig.defaultSoftMinVersion,
        'update_url_android': AppConfig.defaultUpdateUrlAndroid,
        'update_url_ios': AppConfig.defaultUpdateUrlIOS,
        'update_url_web': AppConfig.defaultUpdateUrlWeb,
      });

      final versionFuture = VersionInfo.current();

      try {
        await rc.fetchAndActivate().timeout(const Duration(seconds: 3));
      } on TimeoutException catch (_) {
        Logger.warn('⚠️ Remote Config fetch timed out, using cached values', tag: 'RemoteConfig');
        await rc.activate();
      } catch (e) {
        Logger.warn('⚠️ Remote Config fetch failed: $e', tag: 'RemoteConfig');
        await rc.activate();
      }

      final backendUrl = rc.getString('backend_base_url');
      final updateUrl = _resolveUpdateUrl(rc);
      final current = await versionFuture;
      final hard = Version.parse(rc.getString('min_supported_version'));
      final soft = Version.parse(rc.getString('soft_min_version'));

      final hardBlocked = updateUrl.isNotEmpty && current < hard;
      final shouldSoftPrompt =
          !hardBlocked && updateUrl.isNotEmpty && current < soft;

      return _RemoteConfigGateResult(
        backendBaseUrl: Uri.tryParse(backendUrl)?.hasScheme == true ? backendUrl : null,
        updateUrl: updateUrl,
        hardBlock: hardBlocked,
        shouldSoftPrompt: shouldSoftPrompt,
        currentVersion: current,
        softVersion: soft,
        hardVersion: hard,
      );
    } catch (e) {
      Logger.warn('⚠️ Remote Config unavailable or failed: $e', tag: 'RemoteConfig');
      return const _RemoteConfigGateResult.fallback();
    }
  }

  void _applyRemoteConfigGateResult(_RemoteConfigGateResult gateResult) {
    final backendUrl = gateResult.backendBaseUrl;
    if (backendUrl != null) {
      AppConfig.setRemoteBackendBaseUrl(backendUrl);
      API.instance.updateBaseUrl(backendUrl);
      Logger.info('🔄 Applied Remote Config backend_base_url: $backendUrl', tag: 'RemoteConfig');
    }

    _hardBlocked = gateResult.hardBlock && gateResult.updateUrl.isNotEmpty;
    _updateUrl = gateResult.updateUrl;
  }

  void _maybePromptForSoftUpdate(_RemoteConfigGateResult gateResult) {
    if (!gateResult.shouldSoftPrompt ||
        gateResult.updateUrl.isEmpty ||
        !mounted) {
      return;
    }

    final requiredVersion = gateResult.softVersion.toString();
    if (_lastSoftPromptVersion == requiredVersion) {
      return;
    }
    _lastSoftPromptVersion = requiredVersion;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => UpdateSoftPrompt(
          updateUrl: gateResult.updateUrl,
          currentVersion: gateResult.currentVersion.toString(),
          requiredVersion: requiredVersion,
        ),
      );
    });
  }

  Duration _resolveRemoteConfigInterval({required bool forceRefresh}) {
    if (forceRefresh) {
      return Duration.zero;
    }
    if (AppConfig.defaultRcFetchMinIntervalSec > 0) {
      return Duration(seconds: AppConfig.defaultRcFetchMinIntervalSec);
    }
    return kReleaseMode ? const Duration(hours: 1) : const Duration(minutes: 1);
  }

  String _resolveUpdateUrl(FirebaseRemoteConfig rc) {
    if (kIsWeb) {
      return rc.getString('update_url_web');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return rc.getString('update_url_ios');
    }
    return rc.getString('update_url_android');
  }

  Future<void> _recheckRemoteConfig() async {
    final gateResult = await _fetchRemoteConfigGateResult(forceRefresh: true);
    if (!mounted) return;

    setState(() {
      _applyRemoteConfigGateResult(gateResult);
    });

    _maybePromptForSoftUpdate(gateResult);
  }

  Future<void> _initializeSecondaryServices() async {
    try {
      // Initialize Analytics
      try {
        await AnalyticsService.instance.initialize();
        await AnalyticsService.instance.setUserId(_firebaseAuthProvider?.uid);
      } catch (e) {
        Logger.error('❌ [Analytics] Error initializing analytics: $e', tag: 'Analytics');
      }

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

class _RemoteConfigGateResult {
  final String? backendBaseUrl;
  final bool hardBlock;
  final bool shouldSoftPrompt;
  final String updateUrl;
  final Version currentVersion;
  final Version softVersion;
  final Version hardVersion;

  const _RemoteConfigGateResult({
    this.backendBaseUrl,
    required this.hardBlock,
    required this.shouldSoftPrompt,
    required this.updateUrl,
    required this.currentVersion,
    required this.softVersion,
    required this.hardVersion,
  });

  const _RemoteConfigGateResult.fallback()
      : backendBaseUrl = null,
        hardBlock = false,
        shouldSoftPrompt = false,
        updateUrl = '',
        currentVersion = const Version(0, 0, 0),
        softVersion = const Version(0, 0, 0),
        hardVersion = const Version(0, 0, 0);
}
