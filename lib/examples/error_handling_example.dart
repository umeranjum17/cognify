import 'package:flutter/material.dart';
import '../services/openrouter_client.dart';

/// Example demonstrating error handling for OpenRouter API
class ErrorHandlingExample extends StatefulWidget {
  const ErrorHandlingExample({super.key});

  @override
  State<ErrorHandlingExample> createState() => _ErrorHandlingExampleState();
}

class _ErrorHandlingExampleState extends State<ErrorHandlingExample> {
  final OpenRouterClient _client = OpenRouterClient();
  bool _isLoading = false;
  String _result = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenRouter Error Handling'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'OpenRouter Error Handling Demo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This example demonstrates automatic error handling for:\n'
              '• 401 Unauthorized: Redirects to onboarding with toast\n'
              '• 429 Rate Limited: Shows rate limit warning toast',
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
              onPressed: _isLoading ? null : () => _testStreamingChat(),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test Streaming Chat'),
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
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testStreamingChat() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing streaming chat...\n';
    });

    try {
      await for (final chunk in _client.chatCompletionStream(
        model: 'deepseek/deepseek-chat:free',
        messages: [
          {'role': 'user', 'content': 'Tell me a short story'}
        ],
        context: context, // Pass context for error handling
      )) {
        setState(() {
          _result += 'Chunk: ${chunk.toString()}\n';
        });
      }
    } catch (e) {
      setState(() {
        _result += 'Streaming Error: $e\n';
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
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
