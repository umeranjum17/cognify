import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/source.dart';
import '../models/source_type.dart';
import '../services/services_manager.dart';
import '../services/sharing_service.dart';
import '../services/unified_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_app_header.dart';
import 'editor_screen.dart';

class SourcesScreen extends StatefulWidget {
  final String? initialUrl;
  
  const SourcesScreen({super.key, this.initialUrl});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  late final UnifiedApiService _apiService;
  bool _handledInitialUrl = false;

  final TextEditingController _urlController = TextEditingController();
  List<Source> _sources = [];
  Set<String> _selectedSourceIds = {};

  bool _isLoading = false;
  bool _isUploading = false;
  bool _isRefreshing = false;
  String? _error;
  String _selectedSourceType = 'website';
  Timer? _refreshTimer;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: ModernAppHeader(
        title: _selectedSourceIds.isEmpty
            ? 'Sources'
            : '${_selectedSourceIds.length} selected',
        showBackButton: true,
        showLogo: true,
        centerTitle: false,
        showNewChatButton: true,
      ),
      body: Column(
        children: [
          // Minimalist Input Section
          Container(
            padding: const EdgeInsets.all(AppColors.spacingLg),
            child: Column(
              children: [
                // URL Input
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
                    border: Border.all(
                      color: _urlController.text.trim().isNotEmpty
                          ? _getSourceColor(_selectedSourceType).withValues(alpha: 0.3)
                          : theme.dividerColor,
                    ),
                  ),
                  child: TextField(
                    controller: _urlController,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addUrl(),
                    decoration: InputDecoration(
                      hintText: _getSmartPlaceholder(),
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      prefixIcon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _urlController.text.trim().isEmpty
                              ? Icons.link
                              : _getSourceIcon(_selectedSourceType),
                          key: ValueKey(_selectedSourceType),
                          color: _urlController.text.trim().isEmpty
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                              : _getSourceColor(_selectedSourceType),
                        ),
                      ),
                      suffixIcon: _urlController.text.trim().isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.content_paste, size: 20),
                                  onPressed: _pasteFromClipboard,
                                  tooltip: 'Paste',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _urlController.clear();
                                    setState(() {
                                      _selectedSourceType = 'website';
                                    });
                                  },
                                  tooltip: 'Clear',
                                ),
                              ],
                            )
                          : IconButton(
                              icon: const Icon(Icons.content_paste, size: 20),
                              onPressed: _pasteFromClipboard,
                              tooltip: 'Paste',
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppColors.spacingMd,
                        vertical: AppColors.spacingMd,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppColors.spacingMd),

                // Primary Action: Add URL (full width when URL is entered)
                if (_urlController.text.trim().isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _addUrl,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.add_link),
                      label: Text(
                        _isUploading ? 'Adding URL...' : 'Add URL',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lightAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppColors.spacingMd),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
                        ),
                      ),
                    ),
                  ),

                // Upload File Option (always visible)
                if (_urlController.text.trim().isEmpty) ...[
                  // When no URL, show upload as primary action
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadFile,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(
                        _isUploading ? 'Uploading...' : 'Upload File',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppColors.spacingMd),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // When URL is entered, show upload as secondary option
                  const SizedBox(height: AppColors.spacingSm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _uploadFile,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text(
                        'Or upload a file instead',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppColors.spacingSm),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Error Banner
          if (_error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppColors.spacingMd),
              padding: const EdgeInsets.all(AppColors.spacingSm),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error, size: 16),
                  const SizedBox(width: AppColors.spacingSm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _error = null),
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
            ),

          // Sources List
          Expanded(
            child: _isLoading && _sources.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _sources.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_off,
                              size: 48,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: AppColors.spacingMd),
                            Text(
                              'No sources found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppColors.spacingSm),
                            Text(
                              'Upload a file or add a URL to get started.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppColors.spacingMd),
                          itemCount: _sources.length,
                          itemBuilder: (context, index) {
                            final source = _sources[index];
                            return _buildSourceCard(source, theme);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _selectedSourceIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showChatBottomSheet,
              backgroundColor: AppColors.lightAccent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(
                '${_selectedSourceIds.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }
  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }
  @override
  void didUpdateWidget(covariant SourcesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_handledInitialUrl &&
        widget.initialUrl != null &&
        widget.initialUrl!.isNotEmpty &&
        widget.initialUrl != oldWidget.initialUrl) {
      debugPrint('🟢 didUpdateWidget: new initialUrl: ${widget.initialUrl}');
      _handleInitialUrl(autoAdd: false);
    }
  }

  void handleNavigateToEntities() {
    Navigator.of(context).pushNamed('/entities');
  }

  void handleNavigateToSources() {
    Navigator.of(context).pushNamed('/sources');
  }

  @override
  void initState() {
    super.initState();

    // Get the globally initialized API service
    _apiService = ServicesManager().unifiedApiService;

    _fetchSources();
    _startPeriodicRefresh();
    _urlController.addListener(_onUrlChanged);
    
    // Handle initial URL once (populate only)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialUrl(autoAdd: false);
    });
  }

  Future<void> _addUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final detectedType = SourceType.detectSourceType(url);

      await _apiService.addUrl(
        url: url,
        sourceType: detectedType,
        userSelectedType: detectedType,
      );

      _urlController.clear();
      setState(() {
        _selectedSourceType = 'website';
      });

      await _fetchSources();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL added successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to add URL: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Widget _buildMetadataChip(String text, IconData icon, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppColors.spacingXs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(Source source, ThemeData theme) {
    final isSelected = _selectedSourceIds.contains(source.id);
    final progress = _getProgress(source.stage, source.progress);
    final progressColor = _getProgressColor(source.status, context);
    final isProcessing = ['uploading', 'processing', 'queued'].contains(source.status);

    return Container(
      margin: const EdgeInsets.only(bottom: AppColors.spacingMd),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppColors.borderRadiusLg),
        border: Border.all(
          color: isSelected
              ? AppColors.lightAccent
              : theme.dividerColor.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.lightAccent.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleSourceSelection(source.id),
          borderRadius: BorderRadius.circular(AppColors.borderRadiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppColors.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced Checkbox
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: AppColors.spacingMd),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.lightAccent
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.lightAccent
                              : theme.dividerColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: AppColors.lightAccent.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),

                    // Source Icon and Type
                    _isImageFile(source.filename)
                        ? Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Image.network(
                              _getSourceImageUrl(source.id),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.broken_image,
                                color: Colors.grey[400],
                                size: 24,
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(AppColors.spacingSm),
                            decoration: BoxDecoration(
                              color: _getSourceColor(source.sourceType).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                            ),
                            child: Icon(
                              _getSourceIcon(source.sourceType),
                              size: 24,
                              color: _getSourceColor(source.sourceType),
                            ),
                          ),

                    const SizedBox(width: AppColors.spacingMd),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            source.title ?? source.filename,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          if (source.author != null) ...[
                            const SizedBox(height: AppColors.spacingXs),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 14,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: AppColors.spacingXs),
                                Expanded(
                                  child: Text(
                                    source.author!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppColors.spacingSm,
                        vertical: AppColors.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: progressColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: progressColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        source.status.toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: progressColor,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                // Description and Metadata
                if (source.description != null || source.originalUrl != null) ...[
                  const SizedBox(height: AppColors.spacingMd),
                  if (source.description != null) ...[
                    Text(
                      source.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppColors.spacingSm),
                  ],
                  if (source.originalUrl != null) ...[
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(source.originalUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppColors.spacingSm,
                          vertical: AppColors.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightAccentSecondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.lightAccentSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.link,
                              size: 14,
                              color: AppColors.lightAccentSecondary,
                            ),
                            const SizedBox(width: AppColors.spacingXs),
                            Flexible(
                              child: Text(
                                source.originalUrl!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.lightAccentSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],

                // Progress Section
                if (isProcessing) ...[
                  const SizedBox(height: AppColors.spacingMd),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                            ),
                          ),
                          const SizedBox(width: AppColors.spacingSm),
                          Text(
                            source.progressMessage ?? 'Processing...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: progressColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppColors.spacingSm),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: progress.clamp(0.05, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: progressColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Metadata Section
                const SizedBox(height: AppColors.spacingMd),
                Container(
                  padding: const EdgeInsets.all(AppColors.spacingSm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: AppColors.spacingXs),
                          Text(
                            'Details',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppColors.spacingXs),
                      Wrap(
                        spacing: AppColors.spacingSm,
                        runSpacing: AppColors.spacingXs,
                        children: [
                          if (source.fileSize > 0)
                            _buildMetadataChip(
                              '${(source.fileSize / 1024).toStringAsFixed(1)} KB',
                              Icons.storage,
                              theme,
                            ),
                          _buildMetadataChip(
                            _formatTimestamp(source.uploadedAt),
                            Icons.upload,
                            theme,
                          ),
                          if (source.processedAt != null)
                            _buildMetadataChip(
                              _formatTimestamp(source.processedAt),
                              Icons.check_circle,
                              theme,
                            ),
                          // Show extraction cost for completed sources
                          if (source.status == 'ready' && source.metadata?['generationId'] != null)
                            FutureBuilder<Map<String, dynamic>?>(
                              future: _getExtractionCost(source.metadata!['generationId']),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  final cost = snapshot.data!['total_cost'] as double? ?? 0.0;
                                  final model = source.metadata?['model'] as String? ?? 'gemini-2.0-flash-001';

                                  if (cost > 0) {
                                    return _buildMetadataChip(
                                      '\$${cost.toStringAsFixed(4)}',
                                      Icons.attach_money,
                                      theme,
                                    );
                                  } else {
                                    return _buildMetadataChip(
                                      '0',
                                      Icons.attach_money,
                                      theme,
                                    );
                                  }
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Error Section
                if (source.status == 'failed') ...[
                  const SizedBox(height: AppColors.spacingSm),
                  Container(
                    padding: const EdgeInsets.all(AppColors.spacingSm),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: AppColors.spacingSm),
                        Expanded(
                          child: Text(
                            source.errorMessage.isNotEmpty
                                ? source.errorMessage
                                : 'Processing failed',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () => _retrySource(source.id),
                          tooltip: 'Retry processing',
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons
                if (!isProcessing) ...[
                  const SizedBox(height: AppColors.spacingMd),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteSource(source.id),
                          icon: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: theme.colorScheme.error,
                          ),
                          label: Text(
                            'Delete',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: theme.colorScheme.error.withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                            ),
                          ),
                        ),
                      ),
                      if (source.originalUrl != null) ...[
                        const SizedBox(width: AppColors.spacingSm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(source.originalUrl!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                            icon: const Icon(
                              Icons.open_in_new,
                              size: 16,
                            ),
                            label: const Text(
                              'Open',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppColors.borderRadiusSm),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chatWithSelected() async {
    if (_selectedSourceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one source to chat with')),
      );
      return;
    }

    // Save selected source IDs to SharedPreferences for editor screen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'editorInitialData',
      jsonEncode({
        'content': '',
        'title': 'Chat with selected sources',
        'isNewConversation': true,
        'selectedSourceIds': _selectedSourceIds.toList(),
      }),
    );

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const EditorScreen(),
        ),
      );
    }
  }

  Future<void> _deleteSource(String id) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _apiService.deleteSource(id);
      _selectedSourceIds.remove(id);
      await _fetchSources();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source deleted successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Delete failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSources({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final sources = await _apiService.getSources();
      // Sort by uploadedAt descending (latest first)
      sources.sort((a, b) => (b.uploadedAt ?? 0).compareTo(a.uploadedAt ?? 0));
      if (mounted) {
        setState(() {
          _sources = sources;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return "-";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  // Get extraction cost using generation ID
  Future<Map<String, dynamic>?> _getExtractionCost(String generationId) async {
    try {
      final apiService = UnifiedApiService();
      final response = await apiService.getGenerationCosts([
        {'id': generationId, 'stage': 'extraction', 'model': 'gemini-2.0-flash-001'}
      ]);

      if (response['success'] == true &&
          response['generations'] != null &&
          response['generations'].isNotEmpty) {
        return response['generations'][0]['costData'];
      }
      return null;
    } catch (e) {
      print('Error fetching extraction cost: $e');
      return null;
    }
  }

  double _getProgress(String stage, double? progressValue) {
    if (progressValue != null && progressValue >= 0) {
      return progressValue / 100;
    }

    switch (stage) {
      case "saving": return 0.05;
      case "uploaded": return 0.10;
      case "queued": return 0.15;
      case "extracting": return 0.30;
      case "chunking": return 0.60;
      case "analyzing": return 0.80;
      case "indexing": return 0.90;
      case "complete": return 1.0;
      default: return 0;
    }
  }

  Color _getProgressColor(String status, BuildContext context) {
    final theme = Theme.of(context);
    switch (status) {
      case "ready": return AppColors.lightSuccess;
      case "failed": return theme.colorScheme.error;
      case "processing": return theme.colorScheme.primary;
      case "uploading": return AppColors.lightAccentSecondary;
      default: return theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }

  String _getSmartPlaceholder() {
    final sourceType = SourceType.findById(_selectedSourceType);
    if (sourceType != null) {
      return sourceType.placeholder;
    }

    // Dynamic placeholder based on detected type
    switch (_selectedSourceType) {
      case 'youtube':
        return 'https://youtube.com/watch?v=...';
      case 'medium':
        return 'https://medium.com/@author/article';
      case 'github':
        return 'https://github.com/user/repository';
      case 'reddit':
        return 'https://reddit.com/r/subreddit/comments/...';
      case 'substack':
        return 'https://newsletter.substack.com/p/...';
      case 'blink':
        return 'https://blinkist.com/books/...';
      default:
        return 'https://example.com/article';
    }
  }

  Color _getSourceColor(String sourceType) {
    final colorString = SourceType.getSourceColor(sourceType);
    // Convert hex string to Color
    return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
  }

  IconData _getSourceIcon(String sourceType) {
    switch (sourceType) {
      case 'file': return Icons.insert_drive_file;
      case 'url': return Icons.link;
      case 'youtube': return Icons.play_circle_filled;
      case 'medium': return Icons.article;
      case 'blink': return Icons.menu_book;
      case 'website': return Icons.language;
      default: return Icons.insert_drive_file;
    }
  }

  // Helper to get the image URL for a source
  String _getSourceImageUrl(String sourceId) {
    // Assumes backend serves image at this endpoint
    return '${_apiService.baseUrl}/api/sources/$sourceId/file';
  }

  void _handleInitialUrl({bool autoAdd = false}) {
    if (_handledInitialUrl) return;
    debugPrint('🟢 _handleInitialUrl called with sharedUrl: ${widget.initialUrl}, autoAdd: $autoAdd');
    String? sharedUrl = widget.initialUrl;
    if (sharedUrl == null || sharedUrl.isEmpty) {
      sharedUrl = SharingService().getPendingSharedUrl();
    }
    if (sharedUrl != null && sharedUrl.isNotEmpty) {
      try {
        sharedUrl = Uri.decodeFull(sharedUrl!);
      } catch (e) {
        try { sharedUrl = Uri.decodeQueryComponent(sharedUrl!); } catch (_) {}
        debugPrint('Error decoding URL: $e');
      }
    }
    if (sharedUrl != null && sharedUrl.isNotEmpty && mounted) {
      final decodedUrl = sharedUrl;
      final trimmedUrl = decodedUrl.trim();
      if (!_isValidUrl(trimmedUrl)) return;
      setState(() {
        _urlController.text = trimmedUrl;
        _selectedSourceType = SourceType.detectSourceType(trimmedUrl);
        _handledInitialUrl = true;
      });
      if (!autoAdd) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.share, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Shared URL added: ${trimmedUrl.length > 40 ? '${trimmedUrl.substring(0, 40)}...' : trimmedUrl}',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.lightAccent,
            action: SnackBarAction(
              label: 'Add Now',
              textColor: Colors.white,
              onPressed: _addUrl,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }



  // Helper to check if a file is an image
  bool _isImageFile(String? filename) {
    if (filename == null) return false;
    final ext = filename.toLowerCase();
    return ext.endsWith('.png') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.gif');
  }

  bool _isValidUrl(String text) {
    try {
      final uri = Uri.parse(text);
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      // Try to detect URL patterns even without proper scheme
      return RegExp(r'(?:www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}', caseSensitive: false)
          .hasMatch(text);
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    await _fetchSources();
    setState(() {
      _isRefreshing = false;
    });
  }

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      final detectedType = SourceType.detectSourceType(url);
      if (detectedType != _selectedSourceType) {
        setState(() {
          _selectedSourceType = detectedType;
        });
      }
    } else {
      // Reset to website when URL is empty
      if (_selectedSourceType != 'website') {
        setState(() {
          _selectedSourceType = 'website';
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        final text = clipboardData!.text!.trim();

        // Check if clipboard contains a URL
        if (_isValidUrl(text)) {
          setState(() {
            _urlController.text = text;
            _selectedSourceType = SourceType.detectSourceType(text);
          });

          // Show feedback
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.content_paste, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('URL pasted from clipboard'),
                ],
              ),
              backgroundColor: AppColors.lightAccentSecondary,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Show error if clipboard doesn't contain a valid URL
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Clipboard doesn\'t contain a valid URL'),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error pasting from clipboard: $e');
    }
  }

  Future<void> _retrySource(String id) async {
    setState(() {
      _error = null;
    });

    try {
      await _apiService.retrySource(id);
      await _fetchSources();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source retry initiated')),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Retry failed: ${e.toString()}';
      });
    }
  }

  void _selectAll() {
    setState(() {
      if (_selectedSourceIds.length == _sources.length) {
        _selectedSourceIds.clear();
      } else {
        _selectedSourceIds = _sources.map((s) => s.id).toSet();
      }
    });
  }

  void _showChatBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppColors.borderRadiusLg),
          ),
        ),
        padding: const EdgeInsets.all(AppColors.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppColors.spacingLg),

            // Title
            Text(
              'Chat with Sources',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppColors.spacingSm),

            // Info Text
            Text(
              'Start a grounded conversation using ${_selectedSourceIds.length} selected source${_selectedSourceIds.length == 1 ? '' : 's'}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppColors.spacingXs),

            Text(
              'Your responses will be backed by the content from these sources.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppColors.spacingLg),

            // Primary Action - Start Chat
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _chatWithSelected();
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text(
                  'Start Grounded Chat',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppColors.spacingMd),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.borderRadiusMd),
                  ),
                ),
              ),
            ),

            // Safe area padding
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _fetchSources(silent: true);
      }
    });
  }
  void _toggleSourceSelection(String id) {
    setState(() {
      if (_selectedSourceIds.contains(id)) {
        _selectedSourceIds.remove(id);
      } else {
        _selectedSourceIds.add(id);
      }
    });
  }

  Future<void> _uploadFile() async {
    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'png', 'jpg', 'jpeg', 'gif'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        await _apiService.uploadFile(file);
        await _fetchSources();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File uploaded successfully')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Upload failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
}
