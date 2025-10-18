import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/github.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final headerColor = isDark
        ? AppColors.darkBackgroundLight.withValues(alpha: 0.3)
        : AppColors.lightBackgroundLight.withValues(alpha: 0.5);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with language and copy button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: headerColor,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (language.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      language,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),

                _CopyButton(
                  code: code,
                  theme: theme,
                ),
              ],
            ),
          ),

          // Code content using flutter_highlight
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                code,
                language: language.isEmpty ? 'plaintext' : language,
                theme: isDark ? monokaiSublimeTheme : githubTheme,
                textStyle: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.5,
                ),
                padding: EdgeInsets.zero,
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
    final isDark = widget.theme.brightness == Brightness.dark;
    final buttonColor = isDark 
        ? AppColors.darkBackgroundLight.withValues(alpha: 0.4)
        : AppColors.lightBackgroundLight.withValues(alpha: 0.6);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _copyCode,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Icons.check : Icons.copy,
                size: 16,
                color: _copied
                    ? Colors.green
                    : widget.theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 6),
              Text(
                _copied ? 'Copied!' : 'Copy',
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
