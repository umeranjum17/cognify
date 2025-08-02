import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/file_attachment.dart';

class FileAttachmentService {
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> supportedImageTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp'
  ];
  static const List<String> supportedTextTypes = [
    'text/plain',
    'text/markdown',
    'text/csv',
    'application/json',
    'text/html',
    'text/xml'
  ];
  static const List<String> supportedDocumentTypes = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ];

  /// Create file attachment from base64 string
  static FileAttachment fileAttachmentFromBase64({
    required String name,
    required String base64Data,
    required String mimeType,
  }) {
    final bytes = base64Decode(base64Data);
    return FileAttachment.fromBytes(
      name: name,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  /// Convert file attachment to base64 string for API
  static String fileAttachmentToBase64(FileAttachment attachment) {
    return attachment.base64Data;
  }

  /// Get file icon based on file type
  static String getFileIcon(FileAttachment attachment) {
    switch (attachment.type) {
      case 'image':
        return '🖼️';
      case 'pdf':
        return '📄';
      case 'text':
        return '📝';
      default:
        return '📎';
    }
  }

  /// Get file type description
  static String getFileTypeDescription(FileAttachment attachment) {
    switch (attachment.type) {
      case 'image':
        return 'Image';
      case 'pdf':
        return 'PDF Document';
      case 'text':
        return 'Text File';
      default:
        return 'Document';
    }
  }

  /// Get supported file types for a given model capability
  static List<String> getSupportedFileTypesForModel(ModelCapabilities capabilities) {
    List<String> supportedTypes = [];

    // Always support text content
    supportedTypes.addAll(['txt', 'md', 'json', 'csv']);

    // Add image support if model supports images
    if (capabilities.supportsImages) {
      supportedTypes.addAll(['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']);
    }

    // Add document support if model supports files
    if (capabilities.supportsFiles) {
      supportedTypes.addAll(['pdf', 'doc', 'docx', 'html', 'xml']);
    }

    return supportedTypes;
  }

  /// Check if file type is supported by model
  static bool isFileTypeSupportedByModel(
    String fileExtension,
    ModelCapabilities capabilities,
  ) {
    final supportedTypes = getSupportedFileTypesForModel(capabilities);
    return supportedTypes.contains(fileExtension.toLowerCase());
  }

  /// Pick files using file picker
  static Future<List<FileAttachment>> pickFiles({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
    bool allowMultiple = true,
    int maxFiles = 5,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return [];

      // Limit number of files
      final limitedFiles = result.files.take(maxFiles).toList();
      final List<FileAttachment> attachments = [];

      for (final file in limitedFiles) {
        try {
          if (file.bytes == null) {
            debugPrint('File ${file.name} has no data');
            continue;
          }

          final mimeType = _detectMimeType(file.name, file.extension);
          final validation = _validateFile(
            bytes: file.bytes!,
            fileName: file.name,
            mimeType: mimeType,
          );

          if (validation.isValid) {
            attachments.add(FileAttachment.fromBytes(
              name: file.name,
              bytes: file.bytes!,
              mimeType: mimeType,
            ));
          } else {
            debugPrint('File validation failed for ${file.name}: ${validation.errorMessage}');
          }
        } catch (e) {
          debugPrint('Error processing file ${file.name}: $e');
          // Continue with other files
        }
      }

      return attachments;
    } catch (e) {
      debugPrint('Error picking files: $e');
      return [];
    }
  }

  /// Pick image from camera or gallery
  static Future<FileAttachment?> pickImage({
    required ImageSource source,
    int imageQuality = 85,
  }) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (image == null) return null;

      final bytes = await image.readAsBytes();
      final validation = _validateFile(
        bytes: bytes,
        fileName: image.name,
        mimeType: image.mimeType ?? 'image/jpeg',
      );

      if (!validation.isValid) {
        throw Exception(validation.errorMessage);
      }

      return FileAttachment.fromBytes(
        name: image.name,
        bytes: bytes,
        mimeType: image.mimeType ?? 'image/jpeg',
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
      rethrow;
    }
  }

  /// Pick multiple images from gallery
  static Future<List<FileAttachment>> pickMultipleImages({
    int imageQuality = 85,
    int maxImages = 5,
  }) async {
    try {
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: imageQuality,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (images.isEmpty) return [];

      // Limit number of images
      final limitedImages = images.take(maxImages).toList();
      final List<FileAttachment> attachments = [];

      for (final image in limitedImages) {
        try {
          final bytes = await image.readAsBytes();
          final validation = _validateFile(
            bytes: bytes,
            fileName: image.name,
            mimeType: image.mimeType ?? 'image/jpeg',
          );

          if (validation.isValid) {
            attachments.add(FileAttachment.fromBytes(
              name: image.name,
              bytes: bytes,
              mimeType: image.mimeType ?? 'image/jpeg',
            ));
          }
        } catch (e) {
          debugPrint('Error processing image ${image.name}: $e');
          // Continue with other images
        }
      }

      return attachments;
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return [];
    }
  }

  /// Pick PDF documents specifically
  static Future<List<FileAttachment>> pickPdfDocuments({
    bool allowMultiple = true,
    int maxFiles = 3,
  }) async {
    return pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: allowMultiple,
      maxFiles: maxFiles,
    );
  }

  /// Pick text documents specifically
  static Future<List<FileAttachment>> pickTextDocuments({
    bool allowMultiple = true,
    int maxFiles = 3,
  }) async {
    return pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'json', 'csv', 'html', 'xml'],
      allowMultiple: allowMultiple,
      maxFiles: maxFiles,
    );
  }

  /// Validate multiple attachments for model compatibility
  static FileValidationResult validateAttachmentsForModel(
    List<FileAttachment> attachments,
    ModelCapabilities capabilities,
  ) {
    if (attachments.isEmpty) {
      return FileValidationResult.valid();
    }

    List<String> warnings = [];
    List<String> errors = [];

    for (final attachment in attachments) {
      if (!capabilities.supportsFileType(attachment.type)) {
        if (attachment.type == 'text') {
          // Text files can always be included as text content
          warnings.add('${attachment.name} will be included as text content');
        } else {
          errors.add('${attachment.name} (${attachment.type}) is not supported by this model');
        }
      }
    }

    if (errors.isNotEmpty) {
      return FileValidationResult.invalid(errors.join(', '));
    }

    return FileValidationResult.valid(warnings: warnings);
  }

  /// Detect MIME type from file name and extension
  static String _detectMimeType(String fileName, String? extension) {
    final ext = (extension ?? fileName.split('.').last).toLowerCase();
    
    switch (ext) {
      // Images
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      
      // Text files
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'html':
        return 'text/html';
      case 'xml':
        return 'text/xml';
      
      // Documents
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      
      default:
        return 'application/octet-stream';
    }
  }

  /// Validate file before processing
  static FileValidationResult _validateFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    // Check file size
    if (bytes.length > maxFileSize) {
      return FileValidationResult.invalid(
        'File size (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB) '
        'exceeds maximum limit of ${maxFileSize ~/ (1024 * 1024)} MB'
      );
    }

    // Check if file is empty
    if (bytes.isEmpty) {
      return FileValidationResult.invalid('File is empty');
    }

    // Check file type support
    final allSupportedTypes = [
      ...supportedImageTypes,
      ...supportedTextTypes,
      ...supportedDocumentTypes,
    ];

    if (!allSupportedTypes.contains(mimeType)) {
      return FileValidationResult.invalid(
        'File type $mimeType is not supported'
      );
    }

    List<String> warnings = [];

    // Add warnings for large files
    if (bytes.length > 5 * 1024 * 1024) {
      warnings.add('Large file detected - may take longer to process');
    }

    // Add warning for certain file types
    if (mimeType == 'application/pdf') {
      warnings.add('PDF content extraction may be limited');
    }

    return FileValidationResult.valid(warnings: warnings);
  }
}