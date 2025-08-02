import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/message.dart';

class SaveConversationModal extends StatefulWidget {
  final bool isVisible;
  final String initialTitle;
  final double sessionCost;
  final String conversationContent;
  final String aiReplyContent;
  final Function(String title, List<String> tags, String saveType, Message? messageToSave) onSave;
  final VoidCallback onCancel;
  final Message? messageToSave;

  const SaveConversationModal({
    super.key,
    required this.isVisible,
    required this.initialTitle,
    required this.sessionCost,
    required this.conversationContent,
    required this.aiReplyContent,
    required this.onSave,
    required this.onCancel,
    this.messageToSave,
  });

  @override
  State<SaveConversationModal> createState() => _SaveConversationModalState();
}

class _SaveConversationModalState extends State<SaveConversationModal> {
  late TextEditingController _titleController;
  late TextEditingController _tagController;
  String _step = 'type'; // 'type' or 'details'
  String _saveType = 'conversation';
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _tagController = TextEditingController();
    _saveType = widget.messageToSave != null ? 'reply' : 'conversation';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _handleSave() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    widget.onSave(_titleController.text.trim(), _tags, _saveType, widget.messageToSave);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: Colors.black54,
        child: SafeArea(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              margin: const EdgeInsets.only(top: 50),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(AppColors.spacingMd),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: widget.onCancel,
                        ),
                        Icon(
                          Icons.bookmark_add,
                          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                        ),
                        const SizedBox(width: AppColors.spacingSm),
                        Text(
                          'Save Content',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: _step == 'type' ? _buildTypeSelection(theme, isDark) : _buildDetailsForm(theme, isDark),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelection(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppColors.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What would you like to save?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppColors.spacingLg),

          // Full Conversation Option
          _buildTypeOption(
            theme,
            isDark,
            'conversation',
            Icons.chat,
            'Full Conversation',
            'Save the entire conversation including your messages and AI responses',
            isDark ? AppColors.darkAccentSecondary : AppColors.lightAccentSecondary,
          ),

          const SizedBox(height: AppColors.spacingMd),

          // AI Response Option (only if there's a specific message)
          if (widget.messageToSave != null)
            _buildTypeOption(
              theme,
              isDark,
              'reply',
              Icons.psychology,
              'AI Response',
              'Save only the AI response from this conversation',
              isDark ? AppColors.darkAccent : AppColors.lightAccent,
            ),

          const Spacer(),

          // Continue Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _step = 'details';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppColors.spacingMd),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(ThemeData theme, bool isDark, String type, IconData icon, String title, String description, Color color) {
    final isSelected = _saveType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _saveType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(AppColors.spacingMd),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withValues(alpha: 0.1)
              : theme.cardColor,
          border: Border.all(
            color: isSelected ? color : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppColors.spacingSm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: AppColors.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsForm(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppColors.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button
          GestureDetector(
            onTap: () {
              setState(() {
                _step = 'type';
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  'Change Type',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppColors.spacingMd),

          // Selected Type Indicator
          Container(
            padding: const EdgeInsets.all(AppColors.spacingMd),
            decoration: BoxDecoration(
              color: (_saveType == 'conversation' 
                  ? (isDark ? AppColors.darkAccentSecondary : AppColors.lightAccentSecondary)
                  : (isDark ? AppColors.darkAccent : AppColors.lightAccent)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  _saveType == 'conversation' ? Icons.chat : Icons.psychology,
                  color: _saveType == 'conversation' 
                      ? (isDark ? AppColors.darkAccentSecondary : AppColors.lightAccentSecondary)
                      : (isDark ? AppColors.darkAccent : AppColors.lightAccent),
                ),
                const SizedBox(width: AppColors.spacingSm),
                Text(
                  'Saving ${_saveType == 'conversation' ? 'Full Conversation' : 'AI Response'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppColors.spacingLg),

          // Title Input
          Text(
            'Title',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppColors.spacingSm),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Enter a title for your saved content',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
              ),
            ),
          ),

          const SizedBox(height: AppColors.spacingLg),

          // Tags Input
          Text(
            'Tags (Optional)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppColors.spacingSm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: InputDecoration(
                    hintText: 'Add a tag',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
                    ),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: AppColors.spacingSm),
              IconButton(
                onPressed: _addTag,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),

          // Tags Display
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: AppColors.spacingSm),
            Wrap(
              spacing: AppColors.spacingSm,
              runSpacing: AppColors.spacingSm,
              children: _tags.map((tag) => Chip(
                label: Text(tag),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _removeTag(tag),
                backgroundColor: theme.colorScheme.primaryContainer,
              )).toList(),
            ),
          ],

          const SizedBox(height: AppColors.spacingMd),

          // Cost Display
          Text(
            'Session Cost: \$${widget.sessionCost.toStringAsFixed(4)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppColors.spacingMd),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppColors.spacingMd),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppColors.spacingMd),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
