import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../providers/firebase_auth_provider.dart';
import '../services/llm_service.dart';
import '../models/message.dart';
import '../widgets/session_info_widget.dart';
import '../widgets/model_quick_switcher_modal.dart';
import '../models/mode_config.dart';
import '../services/request_usage_estimator.dart';
import '../services/session_cost_service.dart';

/// DemoModeScreen - Shows sample conversations for unauthenticated users
/// Implements Apple Guideline 5.1.1 (Login requirement)
class DemoModeScreen extends StatefulWidget {
  const DemoModeScreen({super.key});

  @override
  State<DemoModeScreen> createState() => _DemoModeScreenState();
}

class _DemoModeScreenState extends State<DemoModeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _showScrollToBottom = false;
  bool _hasUsedFreeMessage = false;
  bool _isProcessing = false;
  List<Message> _messages = [];
  late LLMService _llmService;
  String _selectedModel = 'mistralai/mistral-small-3.2-24b-instruct:free';
  double _sessionCost = 0.0;
  double _lastOperationCost = 0.0;
  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);
    _llmService = LLMService();
    _initializeDemoMessages();
  }

  void _onTextChanged() {
    setState(() {}); // Rebuild to update send button state
  }

  void _showModelQuickSwitcher() {
    showModelQuickSwitcher(
      context: context,
      mode: ChatMode.chat,
      selectedModel: _selectedModel,
      onModelSelected: (modelId) {
        setState(() {
          _selectedModel = modelId;
        });
      },
    );
  }

  String _formatModelName(String modelId) {
    // Extract the model name from the ID
    final parts = modelId.split('/');
    if (parts.length > 1) {
      final modelName = parts.last;
      // Remove :free suffix if present
      return modelName.replaceAll(':free', '');
    }
    return modelId;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _initializeDemoMessages() {
    // Add sample conversations as initial messages
    for (int i = 0; i < DemoModeConfig.sampleConversations.length; i += 2) {
      if (i + 1 < DemoModeConfig.sampleConversations.length) {
        _messages.add(Message(
          id: 'demo_${i ~/ 2}',
          type: 'user',
          content: DemoModeConfig.sampleConversations[i]['content']!,
          timestamp: DateTime.now().subtract(Duration(minutes: 10 - (i ~/ 2))).toIso8601String(),
        ));
        _messages.add(Message(
          id: 'demo_${i ~/ 2}_response',
          type: 'assistant',
          content: DemoModeConfig.sampleConversations[i + 1]['content']!,
          timestamp: DateTime.now().subtract(Duration(minutes: 9 - (i ~/ 2))).toIso8601String(),
        ));
      }
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isAtBottom = _scrollController.offset >= 
          _scrollController.position.maxScrollExtent - 100;
      if (isAtBottom != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = isAtBottom;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isProcessing) return;
    
    final messageText = _messageController.text.trim();
    _messageController.clear();
    
    setState(() {
      _isProcessing = true;
      _hasUsedFreeMessage = true;
    });

    // Add user message
    final userMessage = Message(
      id: 'demo_user_${DateTime.now().millisecondsSinceEpoch}',
      type: 'user',
      content: messageText,
      timestamp: DateTime.now().toIso8601String(),
    );
    
    setState(() {
      _messages.add(userMessage);
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    try {
      // Send to AI (using selected model)
      final response = await _llmService.chatCompletion(
        messages: [
          {
            'role': 'user',
            'content': messageText,
          }
        ],
        model: _selectedModel,
      );

      // Add AI response
      final responseText = response['choices']?[0]?['message']?['content'] ?? 'Sorry, I could not generate a response.';
      final aiMessage = Message(
        id: 'demo_ai_${DateTime.now().millisecondsSinceEpoch}',
        type: 'assistant',
        content: responseText,
        timestamp: DateTime.now().toIso8601String(),
      );

      // Update costs and message count
      final usage = response['usage'];
      if (usage != null) {
        final promptTokens = usage['prompt_tokens'] ?? 0;
        final completionTokens = usage['completion_tokens'] ?? 0;
        // Estimate cost (simplified for demo)
        final estimatedCost = (promptTokens + completionTokens) * 0.0001;
        setState(() {
          _lastOperationCost = estimatedCost;
          _sessionCost += estimatedCost;
          _messageCount += 2; // User + AI message
        });
      }

      setState(() {
        _messages.add(aiMessage);
      });

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });

    } catch (e) {
      // Add error message
      final errorMessage = Message(
        id: 'demo_error_${DateTime.now().millisecondsSinceEpoch}',
        type: 'assistant',
        content: 'Sorry, there was an error processing your message. Please sign in to continue chatting.',
        timestamp: DateTime.now().toIso8601String(),
      );

      setState(() {
        _messages.add(errorMessage);
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Image.asset(
              'assets/images/cognify_robot_512x512.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 12),
            Text(
              'Cognify',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'DEMO MODE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Demo banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.visibility,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _hasUsedFreeMessage 
                        ? 'You\'ve used your free message! Sign in to continue chatting and get free credits.'
                        : 'This is a preview of Cognify. Try one free message, then sign in for more!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Session Info Widget (matching editor screen)
          SessionInfoWidget(
            llmUsed: _selectedModel,
            modelName: _selectedModel,
            cost: _lastOperationCost,
            sessionCost: _sessionCost,
            messageCount: _messageCount,
            mode: ChatMode.chat,
            onModelSwitched: (modelId) {
              setState(() {
                _selectedModel = modelId;
              });
            },
            remainingRequests: _hasUsedFreeMessage ? 0 : 1,
            isQuotaLoading: false,
          ),
          
          // Chat messages
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageBubble(message, theme);
                  },
                ),
                
                // Scroll to bottom button
                if (!_showScrollToBottom)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      onPressed: () {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ),
              ],
            ),
          ),

          // Model selector layer (matching editor screen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFFF5F5F5),
              border: Border(
                bottom: BorderSide(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF333333)
                      : const Color(0xFFE0E0E0),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.memory,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: _showModelQuickSwitcher,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: _ModelRateDisplay(
                        modelId: _selectedModel,
                        baseText: _formatModelName(_selectedModel),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showModelQuickSwitcher,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Switch',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                // Input field - interactive if not used free message
                if (!_hasUsedFreeMessage) ...[
                  // Interactive input for free message (matching editor screen style)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF404040)
                            : const Color(0xFFE0E0E0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 36,
                              maxHeight: 100,
                            ),
                            child: TextField(
                              controller: _messageController,
                              focusNode: _messageFocusNode,
                              enabled: !_isProcessing,
                              maxLines: null,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFFE0E0E0)
                                    : const Color(0xFF1A1A1A),
                                fontSize: 16,
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                hintText: 'What do you want to know? (1 free message)',
                                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.brightness == Brightness.dark
                                      ? const Color(0xFF888888)
                                      : const Color(0xFF666666),
                                  fontSize: 16,
                                ),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.all(0),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isProcessing)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            onPressed: _messageController.text.trim().isNotEmpty ? _sendMessage : null,
                            icon: Icon(
                              Icons.send,
                              color: _messageController.text.trim().isNotEmpty
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Disabled input after using free message (matching editor screen style)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF333333)
                            : const Color(0xFFD0D0D0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sign in to continue chatting...',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.send,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Sign in button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/sign-in'),
                    icon: const Icon(Icons.login),
                    label: Text(
                      _hasUsedFreeMessage 
                          ? 'Sign In to Continue Chatting'
                          : 'Sign In to Get Free Credits',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, ThemeData theme) {
    final isUser = message.role == 'user';
    final content = message.content;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(
                Icons.smart_toy,
                color: theme.colorScheme.onPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          Expanded(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser 
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(18).copyWith(
                      bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isUser 
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  isUser ? 'You' : 'Cognify AI',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondary,
              child: Icon(
                Icons.person,
                color: theme.colorScheme.onSecondary,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModelRateDisplay extends StatelessWidget {
  final String? modelId;
  final String baseText;
  final TextStyle? style;

  const _ModelRateDisplay({
    required this.modelId,
    required this.baseText,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (modelId == null) {
      return Text(
        '$baseText (Loading...)',
        style: style,
        overflow: TextOverflow.ellipsis,
      );
    }

    return FutureBuilder<RequestUsageEstimate>(
      future: RequestUsageEstimator.estimate(
        modelId: modelId!,
        mode: ChatMode.chat,
      ),
      builder: (context, snapshot) {
        String suffix = ' (Loading...)';
        
        if (snapshot.hasData) {
          final units = snapshot.data!.requestUnits;
          suffix = units > 0 ? ' (x${units.toStringAsFixed(1)})' : ' (x0.3)';
        } else if (snapshot.hasError) {
          // Fallback for errors - could be improved to get from config
          suffix = ' (x0.3)';
        }
        
        return Text(
          '$baseText$suffix',
          style: style,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
