import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/anonymous_access_provider.dart';
import '../providers/firebase_auth_provider.dart';
import '../theme/app_theme.dart';

/// Banner that shows anonymous user limits and encourages sign-in
class AnonymousLimitBanner extends StatelessWidget {
  const AnonymousLimitBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AnonymousAccessProvider, FirebaseAuthProvider>(
      builder: (context, anonymousAccess, authProvider, _) {
        // Only show for anonymous users
        if (!authProvider.isAnonymous) {
          debugPrint('🚫 [AnonymousBanner] Not showing - user not anonymous');
          return const SizedBox.shrink();
        }
        
        debugPrint('✅ [AnonymousBanner] Showing banner for anonymous user');
        debugPrint('  - Messages remaining: ${anonymousAccess.messagesRemaining}');
        debugPrint('  - Has reached limit: ${anonymousAccess.hasReachedLimit}');
        
        final theme = Theme.of(context);
        final messagesRemaining = anonymousAccess.messagesRemaining;
        final hasReachedLimit = anonymousAccess.hasReachedLimit;
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppColors.spacingMd,
            vertical: AppColors.spacingSm,
          ),
          decoration: BoxDecoration(
            color: hasReachedLimit 
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.primaryContainer,
            border: Border(
              bottom: BorderSide(
                color: hasReachedLimit 
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasReachedLimit ? Icons.block : Icons.info_outline,
                size: 16,
                color: hasReachedLimit 
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasReachedLimit 
                      ? anonymousAccess.getLimitMessage()
                      : 'You have ${messagesRemaining} free message${messagesRemaining == 1 ? '' : 's'} remaining. Sign in for unlimited access.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: hasReachedLimit 
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.go('/sign-in'),
                style: TextButton.styleFrom(
                  foregroundColor: hasReachedLimit 
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Sign In',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: hasReachedLimit 
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
