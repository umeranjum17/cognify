import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/purchases_config.dart';
import '../../providers/credits_purchase_provider.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../services/revenuecat_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// PaywallScreen()
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Package? _selected;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final subs = context.read<CreditsPurchaseProvider>();

    setState(() {
      _error = 'Initializing subscription provider...';
    });

    if (!subs.initialized) {
      setState(() {
        _error = 'Initializing RevenueCat service...';
      });
      await subs.initialize();
    } else {
      setState(() {
        _error = 'Refreshing subscription offerings...';
      });
      await subs.refreshOfferings();
    }

    final offerings = subs.offerings;

    setState(() {
      if (offerings == null) {
        _error =
            'No offerings available. RevenueCat may not be configured properly.\n\nDebug info:\n- RevenueCat configured: ${RevenueCatService.instance.isConfigured}\n- Purchases provider initialized: ${subs.initialized}\n- API Key: ${PurchasesConfig.rcPublicKeyAndroid.substring(0, 10)}...';
      } else if (offerings.current == null) {
        _error =
            'No current offering found. Check RevenueCat dashboard configuration.\n\nDebug info:\n- Total offerings: ${offerings.all.length}';
      } else if (offerings.current!.availablePackages.isEmpty) {
        _error =
            'No packages available in current offering. Check product configuration.\n\nDebug info:\n- Offering ID: ${offerings.current!.identifier}\n- Packages: ${offerings.current!.availablePackages.map((p) => p.identifier).join(', ')}\n- Lifetime packages: ${offerings.current!.lifetime?.identifier ?? 'none'}\n- Annual packages: ${offerings.current!.annual?.identifier ?? 'none'}\n- Monthly packages: ${offerings.current!.monthly?.identifier ?? 'none'}';
      } else {
        _error = null; // Clear error if everything is working
        _selected = offerings.current!.availablePackages.first;
      }
    });
  }

  Future<void> _purchase() async {
    final subs = context.read<CreditsPurchaseProvider>();
    final auth = context.read<FirebaseAuthProvider>();
    final selected = _selected;
    if (selected == null) {
      setState(() {
        _error =
            'No package selected. Available packages: ${subs.offerings?.current?.availablePackages.length ?? 0}';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Step 1: If user is not signed in, trigger native sign-in first (Apple on iOS, Google elsewhere)
      if (auth.uid == null || auth.uid!.isEmpty) {
        final isIOS = Platform.isIOS;
        setState(() {
          _error = isIOS
              ? 'Starting Sign in with Apple...'
              : 'Starting Google Sign-In...';
        });

        if (isIOS) {
          await auth.signInWithApple();
        } else {
          await auth.signInWithGoogle();
        }

        // After sign-in, identify with RevenueCat using the UID
        if (auth.uid != null && auth.uid!.isNotEmpty) {
          setState(() {
            _error = 'Identifying user with RevenueCat...';
          });

          await RevenueCatService.instance.identify(auth.uid!);

          // Refresh offerings to show correct packages
          setState(() {
            _error = 'Refreshing subscription offerings...';
          });

          await subs.refreshOfferings();
          await _loadOfferings();
        } else {
          setState(() {
            _busy = false;
            _error =
                'Sign-in failed: No UID received. Auth state: ${auth.isSignedIn}, UID: ${auth.uid}';
          });
          return;
        }
      }

      // Step 2: Proceed with purchase
      setState(() {
        _error = 'Initiating purchase for package: ${selected.identifier}';
      });

      final result = await RevenueCatService.instance.purchasePackage(selected);

      setState(() {
        _busy = false;
        if (!result.success) {
          _error =
              'Purchase failed: ${result.errorMessage ?? 'Unknown error'}\n\nPackage: ${selected.identifier}\nUser: ${auth.uid}\nRevenueCat configured: ${RevenueCatService.instance.isConfigured}';
        }
      });

      if (result.success && mounted) {
        Navigator.of(context).maybePop(); // return to previous screen
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _error =
            'Purchase error: ${e.toString()}\n\nDebug info:\n- User signed in: ${auth.isSignedIn}\n- UID: ${auth.uid}\n- Selected package: ${selected?.identifier}\n- RevenueCat configured: ${RevenueCatService.instance.isConfigured}\n- Offerings available: ${subs.offerings?.current?.availablePackages.length ?? 0}';
      });
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      setState(() {
        _error = 'Restoring purchases...';
      });

      await RevenueCatService.instance.restorePurchases();

      setState(() {
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error =
            'Restore failed: ${e.toString()}\n\nDebug info:\n- RevenueCat configured: ${RevenueCatService.instance.isConfigured}\n- User: ${context.read<FirebaseAuthProvider>().uid}';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _manageSubscription() async {
    try {
      final info = context.read<CreditsPurchaseProvider>().customerInfo;
      final url = info?.managementURL;
      if (url == null) return;
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      setState(() {
        _error = 'Failed to open manage subscriptions: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subs = context.watch<CreditsPurchaseProvider>();
    final offerings = subs.offerings;

    final packages = offerings?.current?.availablePackages ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Token Access')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.token, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    'Tokens Overview',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cognify now runs on request credits. You can top up credits anytime.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.error,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(context).colorScheme.error,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Debug Information',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                                width: 0.5,
                              ),
                            ),
                            child: SelectableText(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.error,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'This detailed error helps diagnose subscription issues. Copy the text above for support.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (packages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Loading subscription options...',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'If this takes too long, please check your internet connection.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _busy ? null : () => _loadOfferings(),
                            child: const Text('Retry Loading'),
                          ),
                          const SizedBox(height: 8),
                          Builder(builder: (context) {
                            final manageUrl = context
                                .watch<CreditsPurchaseProvider>()
                                .customerInfo
                                ?.managementURL;
                            if (manageUrl == null) return const SizedBox.shrink();
                            return TextButton(
                              onPressed: _busy ? null : _manageSubscription,
                              child: const Text('Manage Subscription'),
                            );
                          })
                        ],
                      ),
                    )
                  else
                    // Sign-in gate: if user is not signed in, show rationale + Google sign-in and return early UI
                    Builder(
                      builder: (context) {
                        final auth = context.watch<FirebaseAuthProvider>();
                        if (auth.isSignedIn) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Keep your access safe',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    Platform.isIOS
                                        ? 'We\'ll link your purchase to your Apple ID so you can restore it on any device.'
                                        : 'We\'ll link your purchase to your Google account so you can restore it on any device.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        setState(() {
                                          _busy = true;
                                          _error = null;
                                        });
                                        try {
                                          final auth = context
                                              .read<FirebaseAuthProvider>();
                                          if (Platform.isIOS) {
                                            await auth.signInWithApple();
                                          } else {
                                            await auth.signInWithGoogle();
                                          }
                                          // After sign-in, identify with RevenueCat using the UID
                                          if (auth.uid != null &&
                                              auth.uid!.isNotEmpty) {
                                            await RevenueCatService.instance
                                                .identify(auth.uid!);
                                            // Refresh offerings to show correct packages
                                            await context
                                                .read<CreditsPurchaseProvider>()
                                                .refreshOfferings();
                                            await _loadOfferings();
                                          }
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
                                      },
                                icon: const Icon(Icons.login),
                                label: Text(
                                  _busy
                                      ? 'Signing in...'
                                      : (Platform.isIOS
                                            ? 'Continue with Apple'
                                            : 'Continue with Google'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _busy ? null : _restore,
                              child: const Text('Restore Purchases'),
                            ),
                            Builder(builder: (context) {
                              final manageUrl = context
                                  .watch<CreditsPurchaseProvider>()
                                  .customerInfo
                                  ?.managementURL;
                              if (manageUrl == null) return const SizedBox.shrink();
                              return TextButton(
                                onPressed: _busy ? null : _manageSubscription,
                                child: const Text('Manage Subscription'),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  if (packages.isNotEmpty) ...[
                    for (final pkg in packages)
                      RadioListTile<Package>(
                        value: pkg,
                        groupValue: _selected,
                        onChanged: (v) => setState(() => _selected = v),
                        title: Text(pkg.storeProduct.title),
                        subtitle: Text(pkg.storeProduct.description),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _purchase,
                        icon: const Icon(Icons.lock_open),
                        label: Text(_busy ? 'Processing...' : 'Continue'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : _restore,
                      child: const Text('Restore Purchases'),
                    ),
                    Builder(builder: (context) {
                      final manageUrl = context
                          .watch<CreditsPurchaseProvider>()
                          .customerInfo
                          ?.managementURL;
                      if (manageUrl == null) return const SizedBox.shrink();
                      return TextButton(
                        onPressed: _busy ? null : _manageSubscription,
                        child: const Text('Manage Subscription'),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
