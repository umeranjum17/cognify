import 'package:flutter/material.dart';
import '../services/openrouter_client.dart';

/// Updated example demonstrating improved error handling for OpenRouter API
class UpdatedErrorHandlingExample extends StatefulWidget {
  const UpdatedErrorHandlingExample({super.key});

  @override
  State<UpdatedErrorHandlingExample> createState() => _UpdatedErrorHandlingExampleState();
}

class _UpdatedErrorHandlingExampleState extends State<UpdatedErrorHandlingExample> {
  final OpenRouterClient _client = OpenRouterClient();
  bool _isLoading = false;
  String _result = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Updated OpenRouter Error Handling'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Updated OpenRouter Error Handling Demo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This example demonstrates improved error handling:\n'
              '• 401 Unauthorized: Automatically clears invalid API key\n'
              '• 429 Rate Limited: Shows rate limit warning toast\n'
              '• App handles authentication flow naturally',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _testChatCompletion(),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test Chat Completion'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _testGetModels(),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test Get Models'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _result.isEmpty ? 'Results will appear here...' : _result,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testChatCompletion() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing chat completion...\n';
    });

    try {
      final response = await _client.chatCompletion(
        model: 'deepseek/deepseek-chat:free',
        messages: [
          {'role': 'user', 'content': 'Hello, how are you?'}
        ],
        context: context, // Pass context for error handling
      );

      setState(() {
        _result += 'Success: ${response.toString()}\n';
      });
    } catch (e) {
      setState(() {
        _result += 'Error: $e\n';
        _result += 'Note: If this was a 401 error, the API key has been automatically cleared.\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testGetModels() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing get models...\n';
    });

    try {
      final models = await _client.getModels(
        context: context, // Pass context for error handling
      );

      setState(() {
        _result += 'Models: ${models.toString()}\n';
      });
    } catch (e) {
      setState(() {
        _result += 'Models Error: $e\n';
        _result += 'Note: If this was a 401 error, the API key has been automatically cleared.\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
