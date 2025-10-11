import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/subscriptions_config.dart';
import '../providers/subscription_provider.dart';
import '../providers/firebase_auth_provider.dart';
import '../services/revenuecat_service.dart';
import '../theme/app_theme.dart';

/// Quick credit purchase bottom sheet for fast, prominent credit purchases
class QuickCreditPurchaseSheet extends StatefulWidget {
  final int? currentCredits;
  
  const QuickCreditPurchaseSheet({
    super.key,
    this.currentCredits,
  });

  @override
  State<QuickCreditPurchaseSheet> createState() => _QuickCreditPurchaseSheetState();
}

class _QuickCreditPurchaseSheetState extends State<QuickCreditPurchaseSheet> {
  Package? _selectedPackage;
  bool _busy = false;
  String? _error;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final subs = context.read<SubscriptionProvider>();
    
    setState(() {
      _statusMessage = 'Loading credit options...';
    });

    if (!subs.initialized) {
      await subs.initialize();
    } else {
      await subs.refreshOfferings();
    }

    final offerings = subs.offerings;
    
    setState(() {
      _statusMessage = null;
      if (offerings?.current?.availablePackages.isNotEmpty == true) {
        // Select the first package by default
        _selectedPackage = offerings!.current!.availablePackages.first;
      } else {
        _error = 'No credit packs available at the moment';
      }
    });
  }

  Future<void> _purchase() async {
    final subs = context.read<SubscriptionProvider>();
    final auth = context.read<FirebaseAuthProvider>();
    final selected = _selectedPackage;
    
    if (selected == null) {
      setState(() {
        _error = 'Please select a credit pack';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      // Step 1: Ensure user is signed in
      if (auth.uid == null || auth.uid!.isEmpty) {
        final isIOS = Platform.isIOS;
        setState(() {
          _statusMessage = isIOS
              ? 'Signing in with Apple...'
              : 'Signing in with Google...';
        });

        if (isIOS) {
          await auth.signInWithApple();
        } else {
          await auth.signInWithGoogle();
        }

        // After sign-in, identify with RevenueCat
        if (auth.uid != null && auth.uid!.isNotEmpty) {
          setState(() {
            _statusMessage = 'Setting up your account...';
          });

          await RevenueCatService.instance.identify(auth.uid!);
          await subs.refreshOfferings();
          await _loadOfferings();
        } else {
          setState(() {
            _busy = false;
            _error = 'Sign-in failed. Please try again.';
          });
          return;
        }
      }

      // Step 2: Proceed with purchase
      setState(() {
        _statusMessage = 'Processing purchase...';
      });

      final result = await RevenueCatService.instance.purchasePackage(selected);

      setState(() {
        _busy = false;
        _statusMessage = null;
      });

      if (result.success) {
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Credits purchased successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      } else {
        setState(() {
          _error = result.errorMessage ?? 'Purchase failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _statusMessage = null;
        _error = 'Purchase error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subs = context.watch<SubscriptionProvider>();
    final auth = context.watch<FirebaseAuthProvider>();
    final offerings = subs.offerings;
    final packages = offerings?.current?.availablePackages ?? [];

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buy Credits',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.currentCredits != null)
                          Text(
                            'Current balance: ${widget.currentCredits} credits',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Status/Error messages
              if (_statusMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_statusMessage != null || _error != null)
                const SizedBox(height: 16),

              // Sign-in prompt if not signed in
              if (!auth.isSignedIn) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.security,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Secure Your Purchase',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        Platform.isIOS
                            ? 'Sign in with Apple to link your credits to your Apple ID and restore on any device.'
                            : 'Sign in with Google to link your credits to your account and restore on any device.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Credit pack options
              if (packages.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading credit packs...',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Select a Credit Pack',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...packages.map((pkg) => _buildCreditPackCard(theme, pkg)),
                  ],
                ),

              const SizedBox(height: 24),

              // Purchase button
              if (packages.isNotEmpty)
                ElevatedButton(
                  onPressed: _busy ? null : _purchase,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_busy)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else
                        const Icon(Icons.shopping_cart, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _busy ? 'Processing...' : 'Purchase Credits',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Restore purchases
              TextButton(
                onPressed: _busy ? null : _restorePurchases,
                child: const Text('Restore Previous Purchases'),
              ),

              const SizedBox(height: 8),

              // Info text
              Text(
                'Credits never expire and can be used for any AI model or feature.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditPackCard(ThemeData theme, Package package) {
    final isSelected = _selectedPackage?.identifier == package.identifier;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPackage = package;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : theme.colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                  width: 2,
                ),
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.storeProduct.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.storeProduct.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              package.storeProduct.priceString,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = 'Restoring purchases...';
    });

    try {
      await RevenueCatService.instance.restorePurchases();
      
      setState(() {
        _busy = false;
        _statusMessage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _statusMessage = null;
        _error = 'Restore failed: ${e.toString()}';
      });
    }
  }
}

