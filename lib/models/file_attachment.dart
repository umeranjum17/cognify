import 'dart:convert';
import 'dart:typed_data';

/// Represents a file attachment for multimodal AI interactions
class FileAttachment {
  final String id;
  final String name;
  final String type; // 'image', 'file', 'pdf', 'text'
  final String base64Data;
  final int size;
  final String mimeType;
  final DateTime createdAt;

  const FileAttachment({
    required this.id,
    required this.name,
    required this.type,
    required this.base64Data,
    required this.size,
    required this.mimeType,
    required this.createdAt,
  });

  /// Get file bytes from base64 data
  Uint8List get bytes => base64Decode(base64Data);

  /// Get file extension from name
  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// Get human-readable file size
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  @override
  int get hashCode => id.hashCode;

  /// Check if file is an image
  bool get isImage => type == 'image';

  /// Check if file is a PDF
  bool get isPdf => type == 'pdf';

  /// Check if file is text-based
  bool get isTextBased => type == 'text';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileAttachment && other.id == id;
  }

  /// Create a copy with modified properties
  FileAttachment copyWith({
    String? id,
    String? name,
    String? type,
    String? base64Data,
    int? size,
    String? mimeType,
    DateTime? createdAt,
  }) {
    return FileAttachment(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      base64Data: base64Data ?? this.base64Data,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'base64Data': base64Data,
      'size': size,
      'mimeType': mimeType,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'FileAttachment(id: $id, name: $name, type: $type, size: $formattedSize)';
  }

  /// Create FileAttachment from file bytes
  static FileAttachment fromBytes({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) {
    final base64Data = base64Encode(bytes);
    final type = _determineFileType(mimeType, name);
    
    return FileAttachment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      type: type,
      base64Data: base64Data,
      size: bytes.length,
      mimeType: mimeType,
      createdAt: DateTime.now(),
    );
  }

  /// Create from JSON
  static FileAttachment fromJson(Map<String, dynamic> json) {
    return FileAttachment(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      base64Data: json['base64Data'],
      size: json['size'],
      mimeType: json['mimeType'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  /// Determine file type from MIME type and filename
  static String _determineFileType(String mimeType, String fileName) {
    if (mimeType.startsWith('image/')) {
      return 'image';
    } else if (mimeType == 'application/pdf') {
      return 'pdf';
    } else if (mimeType.startsWith('text/') || 
               fileName.toLowerCase().endsWith('.txt') ||
               fileName.toLowerCase().endsWith('.md') ||
               fileName.toLowerCase().endsWith('.json') ||
               fileName.toLowerCase().endsWith('.csv')) {
      return 'text';
    } else {
      return 'file';
    }
  }
}

/// File attachment validation result
class FileValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<String> warnings;

  const FileValidationResult({
    required this.isValid,
    this.errorMessage,
    this.warnings = const [],
  });

  factory FileValidationResult.invalid(String errorMessage) {
    return FileValidationResult(
      isValid: false,
      errorMessage: errorMessage,
    );
  }

  factory FileValidationResult.valid({List<String> warnings = const []}) {
    return FileValidationResult(
      isValid: true,
      warnings: warnings,
    );
  }
}

/// Model capabilities for input modalities
class ModelCapabilities {
  final List<String> inputModalities;
  final List<String> outputModalities;
  final bool supportsImages;
  final bool supportsFiles;
  final bool isMultimodal;
  final int? contextLength;
  final int? maxCompletionTokens;

  const ModelCapabilities({
    required this.inputModalities,
    required this.outputModalities,
    required this.supportsImages,
    required this.supportsFiles,
    required this.isMultimodal,
    this.contextLength,
    this.maxCompletionTokens,
  });

  factory ModelCapabilities.fromJson(Map<String, dynamic> json) {
    final inputModalities = List<String>.from(json['inputModalities'] ?? ['text']);
    return ModelCapabilities(
      inputModalities: inputModalities,
      outputModalities: List<String>.from(json['outputModalities'] ?? ['text']),
      supportsImages: json['supportsImages'] ?? inputModalities.contains('image'),
      supportsFiles: json['supportsFiles'] ?? inputModalities.contains('file'),
      isMultimodal: json['isMultimodal'] ?? inputModalities.length > 1,
      contextLength: json['contextLength'],
      maxCompletionTokens: json['maxCompletionTokens'],
    );
  }

  /// Check if model supports specific file type
  bool supportsFileType(String fileType) {
    switch (fileType) {
      case 'image':
        return supportsImages;
      case 'file':
      case 'pdf':
      case 'text':
        return supportsFiles || inputModalities.contains('text');
      default:
        return false;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'inputModalities': inputModalities,
      'outputModalities': outputModalities,
      'supportsImages': supportsImages,
      'supportsFiles': supportsFiles,
      'isMultimodal': isMultimodal,
      'contextLength': contextLength,
      'maxCompletionTokens': maxCompletionTokens,
    };
  }
}