import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../theme/app_theme.dart';

/// Custom markdown code builder that adds a copy button to code blocks
class CodeBlockWithCopy extends MarkdownElementBuilder {
  final ThemeData theme;

  CodeBlockWithCopy({required this.theme});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Only handle 'code' elements (pre > code)
    if (element.tag != 'code') return null;

    // Get the code content
    final String code = element.textContent;
    if (code.isEmpty) return null;

    // Get language from class attribute (e.g., "language-dart")
    final String? className = element.attributes['class'];
    String language = '';
    bool isCodeBlock = false;

    if (className != null && className.startsWith('language-')) {
      language = className.substring('language-'.length);
      isCodeBlock = true; // Language class indicates code block
    }

    // Also check if there's no class but element has 'highlight' in attributes
    // This handles the case where markdown uses different syntax
    if (!isCodeBlock && className != null) {
      isCodeBlock = true;
    }

    if (!isCodeBlock) {
      // Inline code - render without copy button
      return _buildInlineCode(code);
    }

    // Code block - render with copy button
    return _buildCodeBlock(code, language);
  }

  Widget _buildInlineCode(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        code,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildCodeBlock(String code, String language) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with language and copy button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppColors.borderRadiusSm),
                topRight: Radius.circular(AppColors.borderRadiusSm),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Language label
                if (language.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      language,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),

                // Copy button
                _CopyButton(
                  code: code,
                  theme: theme,
                ),
              ],
            ),
          ),

          // Code content
          Container(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Copy button widget for code blocks
class _CopyButton extends StatefulWidget {
  final String code;
  final ThemeData theme;

  const _CopyButton({
    required this.code,
    required this.theme,
  });

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() {
      _copied = true;
    });

    // Reset after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _copyCode,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Icons.check : Icons.copy,
                size: 14,
                color: _copied
                    ? Colors.green
                    : widget.theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 4),
              Text(
                _copied ? 'Copied!' : 'Copy',
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _copied
                      ? Colors.green
                      : widget.theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
