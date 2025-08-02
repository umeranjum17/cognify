import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/config_service.dart';

/// Image-based Mermaid widget that uses server-side generation
/// Replaces WebView-based implementation for consistent rendering
class MermaidImageWidget extends StatefulWidget {
  final String mermaidCode;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final String? baseUrl;
  final bool enableFullscreen;
  final String format; // 'png' or 'svg'

  const MermaidImageWidget({
    super.key,
    required this.mermaidCode,
    this.width,
    this.height,
    this.backgroundColor,
    this.baseUrl,
    this.enableFullscreen = true,
    this.format = 'png', // Default to PNG for backward compatibility
  });

  @override
  State<MermaidImageWidget> createState() => _MermaidImageWidgetState();
}

/// Popup dialog for displaying Mermaid images with rotation functionality
class _MermaidImagePopupDialog extends StatefulWidget {
  final Uint8List imageData;

  const _MermaidImagePopupDialog({
    required this.imageData,
  });

  @override
  State<_MermaidImagePopupDialog> createState() => _MermaidImagePopupDialogState();
}

class _MermaidImagePopupDialogState extends State<_MermaidImagePopupDialog> {
  bool _isRotated = false; // false = 0°, true = 90°

  String get _rotationLabel => _isRotated ? '90°' : '0°';

  int get _rotationQuarters => _isRotated ? 1 : 0;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenSize.width * 0.95,
          maxHeight: screenSize.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with rotation and close buttons
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mermaid Diagram',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Rotation button with current angle indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rotate_90_degrees_ccw,
                          size: 16,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _rotationLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  IconButton(
                    onPressed: _toggleRotation,
                    icon: const Icon(Icons.rotate_90_degrees_ccw),
                    tooltip: 'Toggle rotation',
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(width: 8),

                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // Image content with zoom/pan and rotation
            Flexible(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    boundaryMargin: const EdgeInsets.all(20),
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: _rotationQuarters,
                        child: Image.memory(
                          widget.imageData,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 300,
                            height: 300,
                            color: theme.colorScheme.surface,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load diagram',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleRotation() {
    setState(() {
      _isRotated = !_isRotated;
    });
  }
}

class _MermaidImageWidgetState extends State<MermaidImageWidget> {
  bool _isLoading = true;
  String? _error;
  Uint8List? _imageData;
  Timer? _debounceTimer;
  String? _lastRenderedCode;

  // Get server URL from config service or use override
  String get _serverUrl => widget.baseUrl ?? ConfigService.serverUrl;

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }

  @override
  void didUpdateWidget(MermaidImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mermaidCode != widget.mermaidCode) {
      _debouncedGenerateImage();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _debouncedGenerateImage();
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Container(
        width: widget.width ?? 300,
        height: widget.height ?? 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Generating diagram...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        width: widget.width ?? 300,
        height: widget.height ?? 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                size: 32,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to generate diagram',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _retryGeneration,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_imageData != null) {
      return GestureDetector(
        onTap: widget.enableFullscreen ? () => _showMermaidImagePopup(context) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _imageData!,
              width: widget.width,
              height: widget.height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: widget.width ?? 300,
                  height: widget.height ?? 200,
                  color: theme.colorScheme.errorContainer,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 32,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to display image',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return Container(
      width: widget.width ?? 300,
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text('No diagram to display'),
      ),
    );
  }

  void _debouncedGenerateImage() {
    _debounceTimer?.cancel();

    // Only generate if the code has actually changed
    if (_lastRenderedCode == widget.mermaidCode) {
      return;
    }

    _lastRenderedCode = widget.mermaidCode;

    // Check if the code looks complete/valid
    if (!_isValidMermaidCode(widget.mermaidCode)) {
      // For incomplete code, wait longer before generating
      _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
        _generateImage();
      });
    } else {
      // For complete code, generate quickly
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _generateImage();
      });
    }
  }

  Future<void> _generateImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Detect current theme
      final theme = Theme.of(context);
      final isDarkMode = theme.brightness == Brightness.dark;
      final mermaidTheme = isDarkMode ? 'dark' : 'default';

      // Debug logging for theme detection
      print('🎨 Flutter theme detection:');
      print('  - Theme brightness: ${theme.brightness}');
      print('  - isDarkMode: $isDarkMode');
      print('  - mermaidTheme: $mermaidTheme');

      final response = await http.post(
        Uri.parse('$_serverUrl/api/mermaid/generate'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'code': widget.mermaidCode,
          'format': widget.format,
          'width': 1200,
          'height': 800,
          'theme': mermaidTheme,
          'cacheBuster': DateTime.now().millisecondsSinceEpoch.toString(), // Force fresh generation
        }),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _imageData = response.bodyBytes;
          _isLoading = false;
          _error = null;
        });
      } else {
        // Try to parse error response
        String errorMessage = 'Failed to generate diagram';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['details'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          // Use default error message if parsing fails
        }

        setState(() {
          _isLoading = false;
          _error = errorMessage;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _error = 'Network error: ${e.toString()}';
      });
    }
  }

  bool _isValidMermaidCode(String code) {
    if (code.trim().isEmpty) return false;

    final trimmedCode = code.trim().toLowerCase();
    
    // Check for valid diagram type starters
    final validStarters = [
      'graph', 'flowchart', 'sequencediagram', 'classdiagram',
      'statediagram', 'erdiagram', 'journey', 'gantt', 'pie',
      'gitgraph', 'mindmap', 'timeline', 'sankey'
    ];

    final hasValidStarter = validStarters.any((starter) =>
      trimmedCode.startsWith(starter)
    );

    if (!hasValidStarter) return false;

    // Check for basic structure (has some arrows or connections)
    final hasConnections = trimmedCode.contains('-->') ||
                          trimmedCode.contains('->') ||
                          trimmedCode.contains('---') ||
                          trimmedCode.contains(':') ||
                          trimmedCode.contains('|') ||
                          trimmedCode.contains('[') ||
                          trimmedCode.contains('(');

    return hasConnections;
  }

  void _retryGeneration() {
    _generateImage();
  }

  void _showMermaidImagePopup(BuildContext context) {
    if (_imageData == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _MermaidImagePopupDialog(imageData: _imageData!);
      },
    );
  }
}
