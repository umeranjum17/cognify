import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/subscriptions_config.dart';
import '../../providers/subscription_provider.dart';
import '../../services/revenuecat_service.dart';

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
    final subs = context.read<SubscriptionProvider>();
    if (!subs.initialized) {
      await subs.initialize();
    } else {
      await subs.refreshOfferings();
    }
    final offerings = subs.offerings;
    setState(() {
      _selected = offerings?.current?.availablePackages.isNotEmpty == true
          ? offerings!.current!.availablePackages.first
          : null;
    });
  }

  Future<void> _purchase() async {
    final subs = context.read<SubscriptionProvider>();
    final selected = _selected;
    if (selected == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await RevenueCatService.instance.purchasePackage(selected);

    setState(() {
      _busy = false;
      if (!result.success) {
        _error = result.errorMessage ?? 'Purchase failed';
      }
    });

    if (result.success && mounted) {
      Navigator.of(context).maybePop(); // return to previous screen
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await RevenueCatService.instance.restorePurchases();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subs = context.watch<SubscriptionProvider>();
    final offerings = subs.offerings;

    final packages = offerings?.current?.availablePackages ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Go Premium'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.star, size: 56),
                  const SizedBox(height: 12),
                  Text('Unlock Premium',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Enjoy all premium features with an active subscription.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (packages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ...[
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