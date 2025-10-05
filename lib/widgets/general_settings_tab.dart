import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/firebase_auth_provider.dart';
import '../services/access_service.dart';
import '../providers/usage_quota_provider.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../services/data_deletion_service.dart';

class GeneralSettingsTab extends StatefulWidget {
  const GeneralSettingsTab({super.key});

  @override
  State<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends State<GeneralSettingsTab> {
  bool _signingOut = false;

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to sign out? You can sign back in anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _signingOut = true);
      try {
        final authProvider = Provider.of<FirebaseAuthProvider>(
          context,
          listen: false,
        );
        await authProvider.signOut();

        if (mounted) {
          context.go('/sign-in');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _signingOut = false);
        }
      }
    }
  }

  Future<void> _deleteAllData() async {
    // Show detailed information dialog first
    final proceed = await _showDataDeletionInfoDialog();
    if (!proceed) return;

    // Final confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete All Data'),
          ],
        ),
        content: const Text(
          'This action is PERMANENT and cannot be undone. All your data will be deleted immediately.\n\nAre you absolutely sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting all data...'),
            ],
          ),
        ),
      );

      try {
        final authProvider = Provider.of<FirebaseAuthProvider>(
          context,
          listen: false,
        );
        final deletionService = DataDeletionService();

        final success = await deletionService.requestDataDeletion(
          firebaseAuth: authProvider,
          includeFirebaseAccount: true,
        );

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog

          if (success) {
            // Show success and redirect
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Data Deleted'),
                  ],
                ),
                content: const Text(
                  'All your data has been successfully deleted.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/sign-in');
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error deleting data. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<bool> _showDataDeletionInfoDialog() async {
    final deletionService = DataDeletionService();
    final dataTypes = deletionService.getDataTypesToDelete();
    final retentionInfo = deletionService.getDataRetentionInfo();

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Data Deletion Information'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The following data types will be permanently deleted:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...dataTypes.map(
                      (type) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Row(
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: Text(
                                type,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Data Retention Policy:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...retentionInfo.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                '${entry.key}:',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This action is permanent and cannot be undone.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<FirebaseAuthProvider>();
    final quotaProvider = context.watch<UsageQuotaProvider>();
    final user = authProvider.user;

    final quota = quotaProvider.quota;
    final int totalTokens =
        quota?.totalTokens ?? AppSecrets.initialTokenAllocation;
    final bool isTester = AccessService.instance.isTester;
    final int remainingTokens = isTester
        ? totalTokens
        : quota?.remaining ?? totalTokens;
    final int consumedTokens = isTester
        ? 0
        : quota?.tokensConsumed ?? (totalTokens - remainingTokens);

    String tokenValue;
    String tokenSubtitle;
    if (isTester) {
      tokenValue = 'Unlimited';
      tokenSubtitle = 'Tester access • tokens are not limited';
    } else if (quotaProvider.isLoading && quota == null) {
      tokenValue = 'Calculating…';
      tokenSubtitle = 'Fetching your current token balance';
    } else {
      tokenValue = '$remainingTokens tokens';
      tokenSubtitle =
          '$consumedTokens used • $totalTokens available since signup';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(theme, isDark, 'Account', [
            _buildInfoCard(
              theme,
              isDark,
              icon: Icons.person_outline,
              title: 'Signed in as',
              value: user?.email ?? user?.displayName ?? 'Anonymous session',
              subtitle: user?.uid != null
                  ? 'UID: ${user!.uid.substring(0, 8)}…'
                  : null,
            ),
          ]),

          const SizedBox(height: 24),

          _buildSection(theme, isDark, 'Usage', [
            _buildInfoCard(
              theme,
              isDark,
              icon: Icons.token_outlined,
              title: 'Token Balance',
              value: tokenValue,
              subtitle: tokenSubtitle,
            ),
          ]),

          const SizedBox(height: 24),

          _buildSection(theme, isDark, 'Data & Privacy', [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _deleteAllData,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete All My Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _signingOut ? null : _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _signingOut ? 'Signing out…' : 'Sign out',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme,
    bool isDark,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoCard(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.darkDivider.withValues(alpha: 0.2)
              : AppColors.lightDivider.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkTextSecondary.withValues(alpha: 0.1)
                  : AppColors.lightTextSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color:
                        valueColor ??
                        (isDark ? AppColors.darkText : AppColors.lightText),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
