import 'package:cognify_flutter/services/sharing_service.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const SharingTestApp());
}

class SharingTestApp extends StatelessWidget {
  const SharingTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Sharing Test',
      home: SharingTestScreen(),
    );
  }
}

class SharingTestScreen extends StatefulWidget {
  const SharingTestScreen({super.key});

  @override
  State<SharingTestScreen> createState() => _SharingTestScreenState();
}

class _SharingTestScreenState extends State<SharingTestScreen> {
  String? _sharedUrl;
  final TextEditingController _testController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sharing Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Shared URL Test',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _testController,
              decoration: const InputDecoration(
                labelText: 'Test URL',
                hintText: 'Enter a URL to test sharing',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final url = _testController.text;
                if (url.isNotEmpty) {
                  SharingService().setPendingSharedUrl(url);
                  setState(() {
                    _sharedUrl = SharingService().getPendingSharedUrl();
                  });
                }
              },
              child: const Text('Set Test URL'),
            ),
            const SizedBox(height: 20),
            Text(
              'Detected URL: ${_sharedUrl ?? "None"}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _testController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _testSharing();
  }

  Future<void> _testSharing() async {
    // Simulate sharing a URL
    const testUrl = 'https://example.com/test-article';
    SharingService().setPendingSharedUrl(testUrl);
    
    setState(() {
      _sharedUrl = SharingService().getPendingSharedUrl();
    });
  }
}