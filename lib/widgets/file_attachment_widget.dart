import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/file_attachment.dart';
import '../services/file_attachment_service.dart';

/// Compact file attachment button for inline use
class CompactFileAttachmentButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final ModelCapabilities? modelCapabilities;
  final bool enabled;
  final int attachmentCount;

  const CompactFileAttachmentButton({
    super.key,
    this.onPressed,
    this.modelCapabilities,
    this.enabled = true,
    this.attachmentCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final supportsAttachments = _checkAttachmentSupport();
    
    return IconButton(
      onPressed: enabled && supportsAttachments ? onPressed : null,
      icon: Badge(
        isLabelVisible: attachmentCount > 0,
        label: Text(attachmentCount.toString()),
        child: Icon(
          Icons.attach_file,
          color: enabled && supportsAttachments
              ? Theme.of(context).primaryColor
              : Colors.grey,
        ),
      ),
      tooltip: supportsAttachments
          ? 'Attach files'
          : 'File attachments not supported by current model',
    );
  }

  bool _checkAttachmentSupport() {
    if (modelCapabilities == null) return true;
    return modelCapabilities!.isMultimodal ||
           modelCapabilities!.supportsImages ||
           modelCapabilities!.supportsFiles;
  }
}

class FileAttachmentWidget extends StatefulWidget {
  final List<FileAttachment> attachments;
  final Function(List<FileAttachment>) onAttachmentsChanged;
  final ModelCapabilities? modelCapabilities;
  final int maxFiles;
  final bool enabled;

  const FileAttachmentWidget({
    super.key,
    required this.attachments,
    required this.onAttachmentsChanged,
    this.modelCapabilities,
    this.maxFiles = 5,
    this.enabled = true,
  });

  @override
  State<FileAttachmentWidget> createState() => _FileAttachmentWidgetState();
}

class _FileAttachmentWidgetState extends State<FileAttachmentWidget> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Attachment button row
        Row(
          children: [
            _buildAttachmentButton(),
            if (widget.attachments.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '${widget.attachments.length}/${widget.maxFiles}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        
        // Attachments preview
        if (widget.attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildAttachmentsPreview(),
        ],
        
        // Loading indicator
        if (_isLoading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Widget _buildAttachmentButton() {
    return PopupMenuButton<String>(
      enabled: widget.enabled && !_isLoading && widget.attachments.length < widget.maxFiles,
      icon: Icon(
        Icons.attach_file,
        color: widget.enabled && widget.attachments.length < widget.maxFiles
            ? Theme.of(context).primaryColor
            : Colors.grey,
      ),
      tooltip: 'Attach files',
      onSelected: _handleAttachmentSelection,
      itemBuilder: (context) => _buildAttachmentMenuItems(),
    );
  }

  Widget _buildAttachmentItem(FileAttachment attachment, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // File icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getFileTypeColor(attachment.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                FileAttachmentService.getFileIcon(attachment),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      FileAttachmentService.getFileTypeDescription(attachment),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${attachment.formattedSize}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Image preview (for images)
          if (attachment.isImage) ...[
            const SizedBox(width: 8),
            _buildImagePreview(attachment),
          ],
          
          // Remove button
          if (widget.enabled) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: Colors.grey[600]),
              onPressed: () => _removeAttachment(index),
              tooltip: 'Remove',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildAttachmentMenuItems() {
    final capabilities = widget.modelCapabilities;
    List<PopupMenuEntry<String>> items = [];

    // Camera option (if images supported)
    if (capabilities?.supportsImages ?? true) {
      items.add(
        const PopupMenuItem(
          value: 'camera',
          child: ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text('Take Photo'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }

    // Gallery option (if images supported)
    if (capabilities?.supportsImages ?? true) {
      items.add(
        const PopupMenuItem(
          value: 'gallery',
          child: ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Choose Images'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }

    // Documents option (if files supported)
    if (capabilities?.supportsFiles ?? true) {
      items.add(
        const PopupMenuItem(
          value: 'documents',
          child: ListTile(
            leading: Icon(Icons.insert_drive_file),
            title: Text('Choose Documents'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }

    // Text files option (always available)
    items.add(
      const PopupMenuItem(
        value: 'text',
        child: ListTile(
          leading: Icon(Icons.description),
          title: Text('Text Files'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );

    // Add separator if we have items
    if (items.isNotEmpty && capabilities != null) {
      items.add(const PopupMenuDivider());
      items.add(
        PopupMenuItem(
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              _getCapabilityHint(capabilities),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ),
        ),
      );
    }

    return items;
  }

  Widget _buildAttachmentsPreview() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.attachment, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Attached Files (${widget.attachments.length})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (widget.enabled)
                  IconButton(
                    icon: const Icon(Icons.clear_all, size: 16),
                    onPressed: () => widget.onAttachmentsChanged([]),
                    tooltip: 'Remove all',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          
          // Files list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.attachments.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              final attachment = widget.attachments[index];
              return _buildAttachmentItem(attachment, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImageErrorWidget() {
    return Container(
      color: Colors.grey.shade100,
      child: Icon(
        Icons.broken_image,
        size: 16,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildImageFromBase64(String base64Data) {
    try {
      if (base64Data.isEmpty) {
        return _buildImageErrorWidget();
      }

      // Decode base64 to bytes
      final bytes = base64Decode(base64Data);
      
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageErrorWidget();
        },
      );
    } catch (e) {
      return _buildImageErrorWidget();
    }
  }

  Widget _buildImagePreview(FileAttachment attachment) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _buildImageFromBase64(attachment.base64Data),
      ),
    );
  }

  String _getCapabilityHint(ModelCapabilities? capabilities) {
    if (capabilities == null) return 'All file types supported';
    
    List<String> supported = [];
    if (capabilities.supportsImages) supported.add('images');
    if (capabilities.supportsFiles) supported.add('documents');
    supported.add('text');
    
    return 'Supports: ${supported.join(', ')}';
  }

  Color _getFileTypeColor(String type) {
    switch (type) {
      case 'image':
        return Colors.blue;
      case 'pdf':
        return Colors.red;
      case 'text':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleAttachmentSelection(String option) async {
    if (!widget.enabled || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      List<FileAttachment> newAttachments = [];

      switch (option) {
        case 'camera':
          final attachment = await FileAttachmentService.pickImage(
            source: ImageSource.camera,
          );
          if (attachment != null) {
            newAttachments = [attachment];
          }
          break;

        case 'gallery':
          newAttachments = await FileAttachmentService.pickMultipleImages(
            maxImages: widget.maxFiles - widget.attachments.length,
          );
          break;

        case 'documents':
          newAttachments = await FileAttachmentService.pickFiles(
            maxFiles: widget.maxFiles - widget.attachments.length,
          );
          break;

        case 'text':
          newAttachments = await FileAttachmentService.pickTextDocuments(
            maxFiles: widget.maxFiles - widget.attachments.length,
          );
          break;
      }

      if (newAttachments.isNotEmpty) {
        // Validate attachments against model capabilities
        if (widget.modelCapabilities != null) {
          final validation = FileAttachmentService.validateAttachmentsForModel(
            newAttachments,
            widget.modelCapabilities!,
          );

          if (!validation.isValid) {
            _showError(validation.errorMessage!);
            return;
          }

          if (validation.warnings.isNotEmpty) {
            _showWarnings(validation.warnings);
          }
        }

        // Add to existing attachments
        final updatedAttachments = [...widget.attachments, ...newAttachments];
        widget.onAttachmentsChanged(updatedAttachments);

        _showSuccess('${newAttachments.length} file(s) attached');
      }
    } catch (e) {
      _showError('Failed to attach files: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeAttachment(int index) {
    final updatedAttachments = [...widget.attachments];
    updatedAttachments.removeAt(index);
    widget.onAttachmentsChanged(updatedAttachments);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showWarnings(List<String> warnings) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Warnings: ${warnings.join(', ')}'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
