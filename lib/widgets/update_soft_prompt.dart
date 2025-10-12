import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateSoftPrompt extends StatelessWidget {
  final String updateUrl;
  final String currentVersion;
  final String requiredVersion;

  const UpdateSoftPrompt({
    super.key,
    required this.updateUrl,
    required this.currentVersion,
    required this.requiredVersion,
  });

  Future<void> _openStore() async {
    final uri = Uri.tryParse(updateUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Available'),
      content: Text(
        'Your version ($currentVersion) is older than the recommended version ($requiredVersion). Please update for the best experience.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: _openStore,
          child: const Text('Update'),
        ),
      ],
    );
  }
}


