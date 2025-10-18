import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../theme/app_theme.dart';
import '../utils/text_utils.dart';
import 'code_block_with_copy.dart';
import 'safe_mermaid_code_builder.dart';
import '../models/streaming_message.dart';

/// Full-screen bottom sheet to provide a best-in-class copy experience
/// - View entire message
/// - Easily select partial text
/// - Copy All in different formats (Clean, Markdown, Code-only)
class CopyMessageSheet extends StatefulWidget {
  final String content;
  final String? messageId; // enables live streaming fallback

  const CopyMessageSheet({super.key, required this.content, this.messageId});

  @override
  State<CopyMessageSheet> createState() => _CopyMessageSheetState();
}

enum _CopyViewMode { clean, markdown, code }

class _CopyMessageSheetState extends State<CopyMessageSheet> {
  _CopyViewMode _mode = _CopyViewMode.clean;
  bool _copied = false;
  String _rawContent = '';
  StreamSubscription<String>? _subscription;

  bool get _hasCode => TextUtils.hasCodeBlocks(_rawContent);

  @override
  void initState() {
    super.initState();
    _rawContent = widget.content;

    // If empty and a streaming controller exists, hydrate from it and listen
    if (_rawContent.trim().isEmpty && widget.messageId != null) {
      final controller = StreamingMessageRegistry().getController(widget.messageId!);
      if (controller != null) {
        _rawContent = controller.content;
        _subscription = controller.contentStream.listen((value) {
          if (!mounted) return;
          setState(() {
            _rawContent = value;
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setMode(_CopyViewMode mode) {
    setState(() {
      _mode = mode;
    });
  }

  Future<void> _copyAll() async {
    String text;
    switch (_mode) {
      case _CopyViewMode.clean:
        text = TextUtils.stripMarkdown(_rawContent);
        break;
      case _CopyViewMode.markdown:
        text = _rawContent;
        break;
      case _CopyViewMode.code:
        text = TextUtils.extractCodeOnly(_rawContent);
        break;
    }
    await Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  // Selection is handled natively in SelectableText for partial copy.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final height = MediaQuery.of(context).size.height * 0.9;

    return SafeArea(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Grab handle
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.content_copy, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Copy',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Mode selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Text'),
                    selected: _mode == _CopyViewMode.clean,
                    onSelected: (_) => _setMode(_CopyViewMode.clean),
                  ),
                  ChoiceChip(
                    label: const Text('Markdown'),
                    selected: _mode == _CopyViewMode.markdown,
                    onSelected: (_) => _setMode(_CopyViewMode.markdown),
                  ),
                  if (_hasCode)
                    ChoiceChip(
                      label: const Text('Code'),
                      selected: _mode == _CopyViewMode.code,
                      onSelected: (_) => _setMode(_CopyViewMode.code),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Tip row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Long‑press to select and copy part. Use the button to copy all.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Content area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildContent(theme),
                  ),
                ),
              ),
            ),

            // Bottom action
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _copyAll,
                    icon: Icon(_copied ? Icons.check : Icons.copy),
                    label: Text(
                      _copied
                          ? 'Copied'
                          : _mode == _CopyViewMode.clean
                              ? 'Copy Text'
                              : _mode == _CopyViewMode.code
                                  ? 'Copy Code'
                                  : 'Copy Markdown',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_rawContent.trim().isEmpty) {
      return Center(
        child: Text(
          'No content to copy',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    switch (_mode) {
      case _CopyViewMode.clean:
      case _CopyViewMode.code:
        final text = _mode == _CopyViewMode.code
            ? TextUtils.extractCodeOnly(_rawContent)
            : TextUtils.stripMarkdown(_rawContent);
        return Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              text.isEmpty ? 'No content to copy' : text,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                fontFamily: _mode == _CopyViewMode.code ? 'monospace' : null,
                fontSize: _mode == _CopyViewMode.code ? 13 : 14,
              ),
              // Use Flutter-rendered toolbar to avoid iOS system
              // context menu assertion when no active text input
              // connection is present.
              contextMenuBuilder: (context, selectableTextState) {
                return AdaptiveTextSelectionToolbar.selectable(
                  anchors: selectableTextState.contextMenuAnchors,
                  onCopy: () => selectableTextState.copySelection(SelectionChangedCause.toolbar),
                  onSelectAll: () => selectableTextState.selectAll(SelectionChangedCause.toolbar),
                  onShare: () => selectableTextState.shareSelection(SelectionChangedCause.toolbar),
                  selectionGeometry: SelectionGeometry(
                    status: SelectionStatus.uncollapsed,
                    hasContent: true,
                  ),
                );
              },
            ),
          ),
        );
      case _CopyViewMode.markdown:
        // Wrap Markdown with SelectionArea to ensure we always use
        // Flutter's adaptive toolbar for selection, preventing the
        // iOS system context menu assertion.
        return SelectionArea(
          contextMenuBuilder: (context, selectableRegionState) {
            return AdaptiveTextSelectionToolbar.selectableRegion(
              selectableRegionState: selectableRegionState,
            );
          },
          child: Markdown(
            data: _rawContent,
            selectable: true,
            padding: const EdgeInsets.all(12),
            builders: {
              'code': _CombinedCodeBuilder(theme: theme),
            },
            styleSheet: MarkdownStyleSheet(
              p: theme.textTheme.bodyMedium?.copyWith(height: 1.5, fontSize: 14),
              code: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: theme.colorScheme.surface,
                fontSize: 13,
              ),
              codeblockDecoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant
                      .withValues(alpha: theme.brightness == Brightness.dark ? 0.28 : 0.45),
                  width: 1,
                ),
              ),
            ),
          ),
        );
    }
  }
}

/// Local combined code builder for the sheet so markdown shows copy buttons
class _CombinedCodeBuilder extends MarkdownElementBuilder {
  final ThemeData theme;
  late final SafeMermaidCodeBuilder _mermaidBuilder;
  late final CodeBlockWithCopy _codeBlockBuilder;

  _CombinedCodeBuilder({required this.theme}) {
    _mermaidBuilder = SafeMermaidCodeBuilder();
    _codeBlockBuilder = CodeBlockWithCopy(theme: theme);
  }

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final className = element.attributes['class'];
    final isMermaidBlock = className != null &&
        (className.contains('language-mermaid') || className == 'mermaid');

    if (isMermaidBlock) {
      return _mermaidBuilder.visitElementAfter(element, preferredStyle);
    }
    return _codeBlockBuilder.visitElementAfter(element, preferredStyle);
  }
}
