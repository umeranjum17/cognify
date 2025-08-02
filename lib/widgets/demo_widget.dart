import 'package:flutter/material.dart';
import '../screens/sources_screen.dart';
import '../screens/editor_screen.dart';
import '../theme/app_theme.dart';

/// Demo widget to showcase the new Sources and Editor screens
class DemoWidget extends StatelessWidget {
  const DemoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cognify Flutter Demo'),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppColors.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'React Native Port Demo',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppColors.spacingLg),
            
            Text(
              'This demo showcases the Flutter port of the React Native sources.tsx and editor.tsx screens with modern UI design.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppColors.spacingXl),
            
            // Sources Screen Demo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppColors.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppColors.spacingSm),
                        Text(
                          'Sources Screen',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppColors.spacingSm),
                    Text(
                      '• Upload PDF and text files\n'
                      '• Add URLs (YouTube, Medium, Blinkist, websites)\n'
                      '• Real-time processing progress\n'
                      '• Source selection for chat\n'
                      '• Modern card-based UI',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppColors.spacingMd),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SourcesScreen(),
                          ),
                        );
                      },
                      child: const Text('Open Sources Screen'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppColors.spacingMd),
            
            // Editor Screen Demo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppColors.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.chat,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: AppColors.spacingSm),
                        Text(
                          'Editor Screen',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppColors.spacingSm),
                    Text(
                      '• AI chat with multiple models\n'
                      '• File and image attachments\n'
                      '• Markdown rendering\n'
                      '• Source-grounded conversations\n'
                      '• Cost tracking and conversation saving',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppColors.spacingMd),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const EditorScreen(),
                          ),
                        );
                      },
                      child: const Text('Open Editor Screen'),
                    ),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            Container(
              padding: const EdgeInsets.all(AppColors.spacingMd),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(height: AppColors.spacingSm),
                  Text(
                    'Implementation Complete',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Both screens have been successfully ported from React Native to Flutter with modern UI design.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
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
