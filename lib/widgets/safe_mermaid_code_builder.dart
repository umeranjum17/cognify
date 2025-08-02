import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'mermaid_widget.dart';

/// Safe custom markdown builder that only handles Mermaid code blocks
/// All other code blocks are handled by the default flutter_markdown renderer
class SafeMermaidCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Only handle code elements (both inline and block)
    if (element.tag != 'code') {
      return null; // Let flutter_markdown handle non-code elements
    }

    // Check if this is a code block with mermaid language specification
    final className = element.attributes['class'];
    final isMermaidBlock = className != null && 
                          (className.contains('language-mermaid') || 
                           className == 'mermaid');

    if (!isMermaidBlock) {
      return null; // Let flutter_markdown handle normal code blocks
    }

    // Extract the mermaid code content
    final mermaidCode = element.textContent.trim();
    
    // Validate that it's not empty
    if (mermaidCode.isEmpty) {
      return _buildEmptyMermaidFallback();
    }

    // Basic validation for common Mermaid diagram types
    if (!_isValidMermaidCode(mermaidCode)) {
      return _buildInvalidMermaidFallback(mermaidCode);
    }

    // Render the Mermaid diagram
    return MermaidWidget(
      mermaidCode: mermaidCode,
      height: _calculateDiagramHeight(mermaidCode),
    );
  }

  /// Basic validation to check if the code looks like valid Mermaid
  bool _isValidMermaidCode(String code) {
    final trimmedCode = code.trim().toLowerCase();
    
    // Check for common Mermaid diagram types
    final mermaidKeywords = [
      'graph',
      'flowchart',
      'sequencediagram',
      'classDiagram',
      'stateDiagram',
      'erDiagram',
      'journey',
      'gantt',
      'pie',
      'gitgraph',
      'mindmap',
      'timeline',
      'quadrantChart',
      'requirement',
      'c4context',
    ];

    // Check if the code starts with any Mermaid keywords
    return mermaidKeywords.any((keyword) => 
      trimmedCode.startsWith(keyword.toLowerCase())
    );
  }

  /// Calculate appropriate height based on diagram content
  double _calculateDiagramHeight(String code) {
    final lines = code.split('\n').length;
    
    // Base height + additional height per line
    double baseHeight = 300;
    double additionalHeight = lines * 20;
    
    // Cap the maximum height to prevent excessive scrolling
    double maxHeight = 600;
    
    return (baseHeight + additionalHeight).clamp(250, maxHeight);
  }

  /// Fallback widget for empty Mermaid blocks
  Widget _buildEmptyMermaidFallback() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 16),
          SizedBox(width: 8),
          Text(
            'Empty Mermaid diagram block',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback widget for invalid Mermaid code
  Widget _buildInvalidMermaidFallback(String code) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Text(
                'Invalid Mermaid syntax',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This code block was marked as Mermaid but doesn\'t appear to contain valid Mermaid syntax.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
