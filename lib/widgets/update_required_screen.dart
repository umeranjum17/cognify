import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final String updateUrl;

  const UpdateRequiredScreen({super.key, required this.updateUrl});

  Future<void> _openStore() async {
    final uri = Uri.tryParse(updateUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.system_update, color: Colors.white, size: 56),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Update Required',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A newer version of Cognify is required to continue. Please update to the latest version to proceed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openStore,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Update Now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


