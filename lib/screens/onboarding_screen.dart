import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/cognify_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final Map<String, TextEditingController> _controllers = {
    'openai': TextEditingController(),
    'anthropic': TextEditingController(),
    'google': TextEditingController(),
    'groq': TextEditingController(),
  };

  final Map<String, bool> _isLoading = {
    'openai': false,
    'anthropic': false,
    'google': false,
    'groq': false,
  };

  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              // Modern welcome header
              Center(
                child: Column(
                  children: [
                    // App logo
                    const CognifyLogo(size: 80, variant: 'robot'),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome to Cognify',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        'Connect your AI providers to get started with intelligent content analysis and conversation.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          height: 1.5,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              Text(
                'Connect AI Providers',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add at least one API key to continue. You can add more providers later.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),

              const SizedBox(height: 24),

              // Primary providers (OpenAI)
              _buildProviderCard(
                context,
                'openai',
                'OpenAI',
                'GPT-4, GPT-3.5, and other OpenAI models',
                Icons.psychology,
                authProvider,
                isPrimary: true,
              ),

              const SizedBox(height: 16),

              // Show/Hide advanced options
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAdvanced = !_showAdvanced;
                  });
                },
                icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
                label: Text(_showAdvanced ? 'Hide Advanced Options' : 'Show More Providers'),
              ),

              if (_showAdvanced) ...[
                const SizedBox(height: 16),

                _buildProviderCard(
                  context,
                  'anthropic',
                  'Anthropic',
                  'Claude 3 and other Anthropic models',
                  Icons.smart_toy,
                  authProvider,
                ),

                const SizedBox(height: 16),

                _buildProviderCard(
                  context,
                  'google',
                  'Google AI',
                  'Gemini and other Google AI models',
                  Icons.auto_awesome,
                  authProvider,
                ),

                const SizedBox(height: 16),

                _buildProviderCard(
                  context,
                  'groq',
                  'Groq',
                  'Fast inference for open-source models',
                  Icons.speed,
                  authProvider,
                ),
              ],

              const SizedBox(height: 32),

              // Continue button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: authProvider.hasApiKey
                      ? LinearGradient(
                          colors: [
                            theme.primaryColor,
                            theme.primaryColor.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: authProvider.hasApiKey ? null : theme.dividerColor.withValues(alpha: 0.3),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: authProvider.hasApiKey ? () => context.push('/home') : null,
                    child: Center(
                      child: Text(
                        authProvider.hasApiKey
                            ? 'Continue to App'
                            : 'Add at least one API key to continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: authProvider.hasApiKey
                              ? Colors.white
                              : theme.textTheme.bodySmall?.color,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Help text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Getting API Keys',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• OpenAI: Visit platform.openai.com/api-keys\n'
                      '• Anthropic: Visit console.anthropic.com\n'
                      '• Google AI: Visit makersuite.google.com\n'
                      '• Groq: Visit console.groq.com',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildProviderCard(
    BuildContext context,
    String provider,
    String name,
    String description,
    IconData icon,
    AuthProvider authProvider, {
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    final controller = _controllers[provider]!;
    final isLoading = _isLoading[provider]!;
    final hasKey = authProvider.hasApiKeyForProvider(provider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasKey ? theme.primaryColor : theme.dividerColor.withValues(alpha: 0.3),
          width: hasKey ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: theme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        if (isPrimary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Recommended',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasKey) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              hintText: authProvider.getApiKeyPlaceholder(provider),
              suffixIcon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : hasKey
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              // Auto-save when user stops typing
              if (value.isNotEmpty) {
                _saveApiKey(provider, value, authProvider);
              }
            },
          ),
          if (hasKey) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'API key configured',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _removeApiKey(provider, authProvider),
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _removeApiKey(String provider, AuthProvider authProvider) async {
    try {
      await authProvider.removeApiKey(provider);
      _controllers[provider]?.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${authProvider.getProviderDisplayName(provider)} API key removed'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing API key: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveApiKey(String provider, String apiKey, AuthProvider authProvider) async {
    if (apiKey.isEmpty) return;

    setState(() {
      _isLoading[provider] = true;
    });

    try {
      await authProvider.storeApiKey(provider, apiKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${authProvider.getProviderDisplayName(provider)} API key saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading[provider] = false;
        });
      }
    }
  }
}
