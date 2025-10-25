import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../api/api.dart';
import '../config/subscriptions_config.dart';
import '../providers/credits_purchase_provider.dart';
import '../providers/firebase_auth_provider.dart';
import '../services/revenuecat_service.dart';
import '../services/credit_event_service.dart';
import '../theme/app_theme.dart';

/// Quick credit purchase bottom sheet for fast, prominent credit purchases
class QuickCreditPurchaseSheet extends StatefulWidget {
  final int? currentCredits;

  const QuickCreditPurchaseSheet({super.key, this.currentCredits});

  @override
  State<QuickCreditPurchaseSheet> createState() =>
      _QuickCreditPurchaseSheetState();
}

class _QuickCreditPurchaseSheetState extends State<QuickCreditPurchaseSheet> {
  Package? _selectedPackage;
  bool _busy = false;
  bool _waitingForCredits = false;
  String? _error;
  String? _statusMessage;
  int _creditsToAdd = 0;
  int _currentCredits = 0;

  @override
  void initState() {
    super.initState();
    _currentCredits = widget.currentCredits ?? 0;
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final subs = context.read<CreditsPurchaseProvider>();

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
    final subs = context.read<CreditsPurchaseProvider>();
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
      // Step 1: Identify user with RevenueCat if signed in (optional, not required)
      // Anonymous users can purchase - credits are linked to Apple ID via RevenueCat
      if (auth.uid != null && auth.uid!.isNotEmpty && !auth.isAnonymous) {
        setState(() {
          _statusMessage = 'Setting up your account...';
        });
        await RevenueCatService.instance.identify(auth.uid!);
      }

      // Step 2: Proceed with purchase (works for both anonymous and signed-in users)
      setState(() {
        _statusMessage = 'Processing purchase...';
      });

      final result = await RevenueCatService.instance.purchasePackage(selected);

      setState(() {
        _busy = false;
        _statusMessage = null;
      });

      if (result.success) {
        // Calculate expected credits to add based on package
        final expectedCredits = _getExpectedCreditsFromPackage(selected);
        _creditsToAdd = expectedCredits;

        // Start waiting for webhook to process the purchase
        await _waitForCreditsUpdate();
      } else {
        // Handle different error types
        String? userFriendlyError;
        if (result.errorMessage == 'cancelled') {
          // Don't show error for user cancellation - just log it
          debugPrint('User cancelled the purchase');
          userFriendlyError = null;
        } else {
          userFriendlyError =
              result.errorMessage ?? 'Purchase failed. Please try again.';
        }

        setState(() {
          _error = userFriendlyError;
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

  /// Get expected credits from package based on package identifier
  int _getExpectedCreditsFromPackage(Package package) {
    // Map package identifiers to credit amounts
    // This should match your RevenueCat package configuration
    final identifier = package.identifier.toLowerCase();

    if (identifier.contains('100')) return 100;
    if (identifier.contains('500')) return 500;
    if (identifier.contains('1000')) return 1000;
    if (identifier.contains('2500')) return 2500;
    if (identifier.contains('5000')) return 5000;
    if (identifier.contains('10000')) return 10000;

    // Fallback: try to extract number from identifier
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(identifier);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 100;
    }

    return 100; // Default fallback
  }

  /// Wait for credits to be updated via webhook with smart polling and UX
  Future<void> _waitForCreditsUpdate() async {
    if (!mounted) return;

    setState(() {
      _waitingForCredits = true;
      _statusMessage = 'Processing your purchase...';
    });

    try {
      final startTime = DateTime.now();
      final maxWaitTime = const Duration(seconds: 30); // Increased timeout
      final initialBalance = _currentCredits;
      final expectedFinalBalance = initialBalance + _creditsToAdd;

      int pollCount = 0;
      double lastKnownBalance = initialBalance.toDouble();

      while (DateTime.now().difference(startTime) < maxWaitTime) {
        await Future.delayed(
          const Duration(milliseconds: 1500),
        ); // Poll every 1.5s
        pollCount++;

        if (!mounted) return;

        try {
          final currentBalance = await API.instance.getCreditsBalance();

          // Update status message with progress
          if (mounted) {
            setState(() {
              if (pollCount <= 3) {
                _statusMessage = 'Processing your purchase...';
              } else if (pollCount <= 8) {
                _statusMessage =
                    'Adding $_creditsToAdd credits to your wallet...';
              } else {
                _statusMessage = 'Almost done, finalizing...';
              }
            });
          }

          // Check if we got the expected credits
          if (currentBalance >= expectedFinalBalance) {
            lastKnownBalance = currentBalance;
            break;
          }

          // Check if we got any credits (partial success)
          if (currentBalance > lastKnownBalance) {
            lastKnownBalance = currentBalance;
            // Continue waiting for the full amount
          }
        } catch (e) {
          // API error, continue waiting
          debugPrint('Credit polling error: $e');
        }
      }

      // Final check and completion
      if (mounted) {
        final finalBalance = lastKnownBalance.toInt();
        final actualCreditsAdded = finalBalance - initialBalance;

        setState(() {
          _waitingForCredits = false;
          _statusMessage = null;
        });

        if (actualCreditsAdded > 0) {
          // Success - credits were added
          CreditEventService.instance.emitCreditsPurchased(
            amount: actualCreditsAdded,
            newBalance: finalBalance,
          );

          // Show success message with actual credits added
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('+$actualCreditsAdded credits added to your wallet!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );

          Navigator.of(context).pop(true);
        } else {
          // Timeout or no credits added
          setState(() {
            _error =
                'Purchase completed but credits are still processing. They should appear in your wallet shortly.';
          });

          // Still emit event for partial success
          CreditEventService.instance.emitCreditsPurchased(
            amount: _creditsToAdd,
            newBalance: finalBalance,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _waitingForCredits = false;
          _statusMessage = null;
          _error =
              'Purchase completed but there was an issue updating your credits. Please refresh the app.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subs = context.watch<CreditsPurchaseProvider>();
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
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
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
                    color: _waitingForCredits
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _waitingForCredits
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _waitingForCredits ? Colors.green : Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _waitingForCredits
                                ? Colors.green
                                : Colors.blue,
                            fontWeight: _waitingForCredits
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_waitingForCredits) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.account_balance_wallet,
                          size: 16,
                          color: Colors.green,
                        ),
                      ],
                    ],
                  ),
                ),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
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

              // Simplified info - no confusing sign-in prompts
              // Credits are automatically linked via RevenueCat to Apple ID

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
                  onPressed: (_busy || _waitingForCredits) ? null : _purchase,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _waitingForCredits
                        ? Colors.green
                        : theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_busy || _waitingForCredits)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.shopping_cart, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _busy
                            ? 'Processing...'
                            : _waitingForCredits
                            ? 'Adding Credits...'
                            : 'Purchase Credits',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

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
      onTap: (_busy || _waitingForCredits)
          ? null
          : () {
              setState(() {
                _selectedPackage = package;
              });
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (_busy || _waitingForCredits)
              ? theme.colorScheme.surface.withValues(alpha: 0.3)
              : isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : theme.colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (_busy || _waitingForCredits)
                ? theme.dividerColor.withValues(alpha: 0.2)
                : isSelected
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
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.dividerColor,
                  width: 2,
                ),
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          package.storeProduct.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        package.storeProduct.priceString,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.storeProduct.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Model capabilities description similar to modal switcher
                  if (package.storeProduct.description.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Credits never expire and can be used for any AI model or feature',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                              fontSize: 10,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.info_outline,
                          size: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Restore purchases functionality removed per product decision
}
