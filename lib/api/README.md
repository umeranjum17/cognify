# Centralized API Documentation

## Overview

All backend API calls are centralized in [`api.dart`](./api.dart). The UI should call `API.instance` methods directly - no service layers needed.

## Quick Start

```dart
import 'package:cognify_flutter/api/api.dart';

// Use the singleton instance
final api = API.instance;
```

## Usage Examples

### 1. Chat (Non-Streaming)

```dart
// Simple chat request
Future<void> sendChatMessage() async {
  try {
    final result = await API.instance.chat(
      mode: 'chat',
      messages: [
        {'role': 'user', 'content': 'What is AI?'}
      ],
      model: 'google/gemini-2.5-flash-lite',
      temperature: 0.7,
      maxTokens: 1000,
    );

    print('Response: ${result['response']}');
  } catch (e) {
    print('Error: $e');
  }
}
```

### 2. Chat (Streaming)

```dart
// Streaming chat for real-time UI updates
Future<void> streamChatMessage() async {
  final stream = API.instance.chatStream(
    mode: 'chat',
    messages: [
      {'role': 'user', 'content': 'Tell me a story'}
    ],
    model: 'google/gemini-2.5-flash-lite',
  );

  await for (final chunk in stream) {
    // Update UI with each chunk
    setState(() {
      responseText += chunk['content'] ?? '';
    });
  }
}
```

### 3. Check Credits Balance

```dart
// Get user's current credit balance
Future<void> checkBalance() async {
  final balance = await API.instance.getCreditsBalance();
  print('You have $balance credits');
}
```

### 4. Consume Credits

```dart
// Consume credits for a request
Future<void> useCredits() async {
  try {
    final newBalance = await API.instance.consumeCredits(
      amount: 10,
      reason: 'chat_request',
      requestId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    print('Credits consumed. Remaining: $newBalance');
  } on Exception catch (e) {
    if (e.toString().contains('INSUFFICIENT_CREDITS')) {
      // Show paywall or credit purchase UI
      showPaywall();
    }
  }
}
```

### 5. Get Available Models

```dart
// Fetch list of available AI models
Future<void> loadModels() async {
  final models = await API.instance.getModels();
  setState(() {
    availableModels = models;
  });
}
```

### 6. Upload Files

```dart
// Upload a file (image, PDF, etc.)
Future<void> uploadDocument() async {
  final bytes = await file.readAsBytes();

  final result = await API.instance.uploadFile(
    fileName: 'document.pdf',
    fileBytes: bytes,
    mimeType: 'application/pdf',
  );

  print('Uploaded: ${result['fileId']}');
}
```

### 7. Get Chat Modes

```dart
// Fetch available chat modes (chat, deepsearch, etc.)
Future<void> loadChatModes() async {
  final modes = await API.instance.getModes();
  setState(() {
    chatModes = modes;
  });
}
```

## Complete Widget Example

```dart
import 'package:flutter/material.dart';
import 'package:cognify_flutter/api/api.dart';

class ChatScreen extends StatefulWidget {
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  String _response = '';
  bool _loading = false;

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _loading = true;
      _response = '';
    });

    try {
      // Stream the response for real-time updates
      final stream = API.instance.chatStream(
        mode: 'chat',
        messages: [
          {'role': 'user', 'content': _controller.text}
        ],
        model: 'google/gemini-2.5-flash-lite',
      );

      await for (final chunk in stream) {
        setState(() {
          _response += chunk['content'] ?? '';
        });
      }
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Text(_response),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(hintText: 'Type a message...'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _loading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## API Methods Reference

### Chat Methods
- `chat()` - Non-streaming chat
- `chatStream()` - Streaming chat
- `getModes()` - Get available chat modes

### Credits Methods
- `getCreditsBalance()` - Get current balance
- `consumeCredits()` - Consume credits

### Config Methods
- `getModels()` - Get available AI models

### File Methods
- `uploadFile()` - Upload file
- `getSources()` - Get uploaded files

## Error Handling

All methods include try-catch blocks and print errors to console. Handle errors in your UI:

```dart
try {
  final result = await API.instance.chat(...);
} catch (e) {
  // Show error dialog or snackbar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

## Authentication

Authentication is handled automatically using Firebase Auth tokens. Make sure the user is signed in before making API calls.

## Configuration

Update the backend URL in environment variables:
```dart
// In dart-define or .env
BACKEND_BASE_URL=https://your-backend.com
```

Or programmatically:
```dart
API.instance.updateBaseUrl('https://new-backend.com');
```
