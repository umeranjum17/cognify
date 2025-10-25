import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/firebase_auth_provider.dart';
import '../services/access_service.dart';
import '../providers/usage_quota_provider.dart';
import '../theme/app_theme.dart';
import '../services/data_deletion_service.dart';
import '../services/analytics_service.dart';

class GeneralSettingsTab extends StatefulWidget {
  const GeneralSettingsTab({super.key});

  @override
  State<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends State<GeneralSettingsTab> {
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
  }

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
        AnalyticsService.instance.logEvent('logout');

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
        AnalyticsService.instance.logEvent('data_deletion_requested');

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
        quota?.totalTokens ?? 0;
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
      tokenSubtitle = '$remainingTokens remaining';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(theme, isDark, 'Account', [
            Consumer<FirebaseAuthProvider>(
              builder: (context, authProvider, _) {
                final isAnonymous = authProvider.isAnonymous;
                final displayName = user?.email ?? user?.displayName;
                final sessionType = isAnonymous ? 'Anonymous session' : 'Apple account';
                final displayValue = isAnonymous ? sessionType : (displayName ?? sessionType);
                
                return _buildInfoCard(
                  theme,
                  isDark,
                  icon: Icons.person_outline,
                  title: 'Signed in as',
                  value: displayValue,
                  subtitle: user?.uid != null
                      ? 'UID: ${user!.uid.substring(0, 8)}…'
                      : null,
                );
              },
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

          // Support & Feedback section
          _buildSection(theme, isDark, 'Support & Feedback', [
            _buildActionCard(
              theme,
              isDark,
              icon: Icons.feedback_outlined,
              title: 'Send Feedback',
              subtitle: 'Share your thoughts and report issues',
              onTap: () => context.push('/feedback'),
            ),
          ]),

          const SizedBox(height: 24),
          // Account Actions - only show for non-anonymous users
          if (!authProvider.isAnonymous)
            _buildSection(theme, isDark, 'Account Actions', [
              // Sign Out button for authenticated users
              _buildActionCard(
                theme,
                isDark,
                icon: Icons.logout,
                title: 'Sign Out',
                subtitle: 'Sign out of your account',
                onTap: _signingOut ? null : _logout,
                isLoading: _signingOut,
                isDestructive: false,
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                theme,
                isDark,
                icon: Icons.delete_forever,
                title: 'Delete All My Data',
                subtitle: 'Permanently delete all your data',
                onTap: _deleteAllData,
                isDestructive: true,
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

  Widget _buildActionCard(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool isDestructive = false,
  }) {
    final iconColor = isDestructive 
        ? Colors.red 
        : (isDark ? AppColors.darkAccent : AppColors.lightAccent);
    final textColor = isDestructive 
        ? Colors.red 
        : (isDark ? AppColors.darkText : AppColors.lightText);
    final subtitleColor = isDestructive 
        ? Colors.red.withValues(alpha: 0.7)
        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      )
                    : Icon(
                        icon,
                        size: 20,
                        color: iconColor,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null && !isLoading)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
