import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/firebase_auth_provider.dart';
import '../config/app_config.dart';
import '../services/feedback_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _contactEmailController = TextEditingController();
  bool _submittingFeedback = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final message = _feedbackController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write some feedback before submitting.')),
      );
      return;
    }

    setState(() => _submittingFeedback = true);
    try {
      final authProvider = Provider.of<FirebaseAuthProvider>(context, listen: false);
      final user = authProvider.user;
      // Build rich context to help backend triage
      final locale = Localizations.localeOf(context).toString();
      final mq = MediaQuery.of(context);
      final isDarkNow = Theme.of(context).brightness == Brightness.dark;
      final themeMode = isDarkNow ? 'dark' : 'light';

      await FeedbackService.instance.submit(
        message: message,
        userId: user?.uid,
        userEmail: _contactEmailController.text.trim().isNotEmpty
            ? _contactEmailController.text.trim()
            : user?.email,
        extra: {
          'route': 'feedback',
          'platform': Theme.of(context).platform.toString(),
          'theme': themeMode,
          'locale': locale,
          'screen': {
            'width': mq.size.width,
            'height': mq.size.height,
            'devicePixelRatio': mq.devicePixelRatio,
          },
          'app': {
            'name': AppConfig.appName,
            'version': AppConfig.appVersion,
          },
        },
      );
      AnalyticsService.instance.logEvent('feedback_submitted');
      _feedbackController.clear();
      _contactEmailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! Your feedback was sent.')),
      );
    } catch (e) {
      // Show detailed error with fallback option
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.orange),
                SizedBox(width: 8),
                Text('Unable to Send Feedback'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('There was an issue sending your feedback through the app.'),
                const SizedBox(height: 8),
                Text(
                  'Error: ${e.toString()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Text('Would you like to try sending via email instead?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _fallbackEmail();
                },
                child: const Text('Send via Email'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingFeedback = false);
    }
  }

  Future<void> _fallbackEmail() async {
    final subject = Uri.encodeComponent('Cognify Feedback');
    final body = Uri.encodeComponent(_feedbackController.text.trim());
    final uri = Uri.parse('mailto:umerfarooq1995@gmail.com?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      AnalyticsService.instance.logEvent('feedback_mailto_opened');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email client available on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Feedback'),
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        foregroundColor: isDark ? AppColors.darkText : AppColors.lightText,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkDivider.withValues(alpha: 0.2)
                      : AppColors.lightDivider.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.feedback_outlined,
                          size: 24,
                          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'We value your feedback',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Help us improve Cognify by sharing your thoughts, reporting bugs, or suggesting new features.',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Feedback Form
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkDivider.withValues(alpha: 0.2)
                      : AppColors.lightDivider.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Feedback',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Describe your idea, bug report, or feature request...',
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: isDark 
                          ? AppColors.darkBackground.withValues(alpha: 0.5)
                          : AppColors.lightBackground.withValues(alpha: 0.5),
                    ),
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contactEmailController,
                    decoration: InputDecoration(
                      hintText: 'Optional: Your email for follow-up',
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: isDark 
                          ? AppColors.darkBackground.withValues(alpha: 0.5)
                          : AppColors.lightBackground.withValues(alpha: 0.5),
                    ),
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _submittingFeedback ? null : _submitFeedback,
                          icon: _submittingFeedback
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          label: Text(_submittingFeedback ? 'Sending...' : 'Send Feedback'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                            foregroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _fallbackEmail,
                        icon: const Icon(Icons.email_outlined),
                        label: const Text('Email'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                          side: BorderSide(
                            color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Additional Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your feedback is anonymous unless you provide an email. We read every message and use it to improve Cognify.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
