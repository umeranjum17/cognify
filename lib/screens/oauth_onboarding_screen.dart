import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/feature_flags.dart';
import '../providers/oauth_auth_provider.dart';
import '../widgets/cognify_logo.dart';

/// Streamlined OAuth onboarding screen for OpenRouter authentication
class OAuthOnboardingScreen extends StatefulWidget {
  const OAuthOnboardingScreen({super.key});

  @override
  State<OAuthOnboardingScreen> createState() => _OAuthOnboardingScreenState();
}

class _OAuthOnboardingScreenState extends State<OAuthOnboardingScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _showManualEntry = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // Keep content away from notches/system UI
        top: true,
        bottom: true,
        child: Consumer<OAuthAuthProvider>(
          builder: (context, authProvider, child) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              // Use CustomScrollView + SliverFillRemaining to:
              // - center content on tall screens
              // - allow scrolling on small screens
              // - avoid overlap with any top banners (ConnectionStatusBanner)
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 16), // avoids top overlay clipping on Android
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        children: [
                          // Main body centered
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // App logo and welcome
                                _buildWelcomeSection(context),

                                const SizedBox(height: 32),

                                // Value proposition
                                _buildValueProposition(context),

                                const SizedBox(height: 32),

                                // Authentication options - prioritize OAuth
                                if (!_showManualEntry) ...[
                                  _buildOAuthButton(context, authProvider),
                                  const SizedBox(height: 16),
                                  _buildManualEntryToggle(context),
                                ] else ...[
                                  _buildManualApiKeyEntry(context, authProvider),
                                  const SizedBox(height: 16),
                                  _buildBackToOAuthButton(context),
                                ],

                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  _buildErrorMessage(context),
                                ],
                              ],
                            ),
                          ),

                          // Footer (features list)
                          _buildFooter(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Defer authentication check until after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingAuthentication();
    });
  }

  Widget _buildBackToOAuthButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        setState(() {
          _showManualEntry = false;
          _errorMessage = null;
          _apiKeyController.clear();
        });
      },
      icon: const Icon(Icons.arrow_back),
      label: const Text('Back to one-click setup'),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          'Free Version Features:',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '• Unlimited chat\n• Multiple free models\n• Attach files & images\n• Save conversations\n• Learning roadmaps\n• No login required',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildManualApiKeyEntry(BuildContext context, OAuthAuthProvider authProvider) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OpenRouter API Key',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Get your API key from openrouter.ai/keys',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            hintText: 'sk-or-v1-...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.key),
            helperText: 'Your API key will be stored securely on this device',
          ),
          obscureText: true,
          enabled: !authProvider.isLoading,
          // Improve UX: enable button state updates as user types
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: authProvider.isLoading || _apiKeyController.text.isEmpty
                ? null
                : () => _handleManualLogin(authProvider),
            child: authProvider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildManualEntryToggle(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _showManualEntry = true;
            _errorMessage = null;
          });
        },
        icon: const Icon(Icons.key, color: Colors.black),
        label: const Text(
          'Enter OpenRouter API Key',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 2),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildOAuthButton(BuildContext context, OAuthAuthProvider authProvider) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: authProvider.isLoading ? null : () => _handleOAuthLogin(authProvider),
        icon: authProvider.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.open_in_new, color: Colors.white),
        label: Text(
          authProvider.isLoading
              ? 'Connecting with OpenRouter...'
              : 'Connect with OpenRouter OAuth',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildValueProposition(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.security,
            size: 32,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'You Control Your Costs',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your OpenRouter account to access powerful AI models. You pay OpenRouter directly for usage - no hidden fees or markups.',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const CognifyLogo(size: 80, variant: 'robot'),
        const SizedBox(height: 24),
        Text(
          'Welcome to Cognify',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Chat with AI using your own OpenRouter account',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.textTheme.bodyMedium?.color,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _checkExistingAuthentication() async {
    final authProvider = Provider.of<OAuthAuthProvider>(context, listen: false);
    
    // No need to initialize again since it's done at app startup
    // Just check the current authentication state
    if (authProvider.isAuthenticated && mounted) {
      // Check if we're currently processing an OAuth callback
      final currentLocation = GoRouterState.of(context).uri.toString();
      if (currentLocation.contains('/oauth/callback')) {
        // Don't redirect if we're in the middle of OAuth callback processing
        print('🔄 OAuth callback in progress, skipping authentication redirect');
        return;
      }

      // User is already authenticated, redirect to editor
      context.go('/editor');
    }
  }

  Future<void> _handleManualLogin(OAuthAuthProvider authProvider) async {
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }

    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Please enter your OpenRouter API key.';
        });
      }
      return;
    }

    final success = await authProvider.setApiKeyManually(apiKey);

    if (success) {
      if (mounted) {
        context.go('/editor');
      }
    } else {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Invalid API key. Please verify your key is correct and has proper permissions. Get your API key from https://openrouter.ai/keys';
        });
      }
    }
  }

  Future<void> _handleOAuthLogin(OAuthAuthProvider authProvider) async {
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }

    final success = await authProvider.authenticateWithOpenRouter();

    if (success) {
      if (mounted) {
        context.go('/editor');
      }
    } else {
      if (mounted) {
        setState(() {
          _errorMessage =
              'OAuth authentication failed. Please try again or enter your API key manually.';
          _showManualEntry = true; // Automatically show manual entry
        });
      }
    }
  }
}
