import 'dart:async';

/// A helper class to manage streaming content for messages
class StreamingMessageController {
  final String messageId;
  final StreamController<String> _contentController = StreamController<String>.broadcast();
  String _accumulatedContent = '';
  
  StreamingMessageController(this.messageId);
  
  /// Current accumulated content
  String get content => _accumulatedContent;
  
  /// Stream of content updates
  Stream<String> get contentStream => _contentController.stream;
  
  /// Add new content chunk
  void addContent(String chunk) {
    _accumulatedContent += chunk;
    print('🤖 StreamingMessageController: Added ${chunk.length} chars, total: ${_accumulatedContent.length} chars');
    _contentController.add(_accumulatedContent);
    print('🤖 StreamingMessageController: Emitted content to stream');
  }
  
  /// Close the stream controller
  void dispose() {
    if (!_contentController.isClosed) {
      _contentController.close();
    }
  }
  
  /// Set the final content and close the stream
  void setFinalContent(String finalContent) {
    _accumulatedContent = finalContent;
    _contentController.add(_accumulatedContent);
    _contentController.close();
  }
}

/// Global registry to manage streaming message controllers
class StreamingMessageRegistry {
  static final StreamingMessageRegistry _instance = StreamingMessageRegistry._internal();
  final Map<String, StreamingMessageController> _controllers = {};
  factory StreamingMessageRegistry() => _instance;
  
  StreamingMessageRegistry._internal();
  
  /// Create a new streaming controller for a message
  StreamingMessageController createController(String messageId) {
    // Dispose existing controller if it exists
    _controllers[messageId]?.dispose();
    
    final controller = StreamingMessageController(messageId);
    _controllers[messageId] = controller;
    return controller;
  }
  
  /// Dispose all controllers
  void disposeAll() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }
  
  /// Get existing controller for a message
  StreamingMessageController? getController(String messageId) {
    return _controllers[messageId];
  }
  
  /// Remove and dispose controller for a message
  void removeController(String messageId) {
    _controllers[messageId]?.dispose();
    _controllers.remove(messageId);
  }
}
