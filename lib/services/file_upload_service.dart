import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../database/database_service.dart';
import '../models/source.dart';
import '../utils/helpers.dart';
import 'content_extractor.dart';
import 'document_processor.dart';

/// File upload and processing service
class FileUploadService {
  static final FileUploadService _instance = FileUploadService._internal();
  final DatabaseService _db = DatabaseService();
  final DocumentProcessor _documentProcessor = DocumentProcessor();
  final ContentExtractor _contentExtractor = ContentExtractor();

  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();
  bool _initialized = false;
  factory FileUploadService() => _instance;

  FileUploadService._internal();

  /// Delete source
  Future<bool> deleteSource(String sourceId) async {
    await _ensureInitialized();
    
    try {
      await _db.deleteSource(sourceId);
      print('📁 Deleted source: $sourceId');
      return true;
    } catch (e) {
      print('📁 Failed to delete source: $sourceId - $e');
      return false;
    }
  }

  /// Get all uploaded sources
  Future<List<Source>> getAllSources() async {
    await _ensureInitialized();
    return await _db.getAllSources();
  }

  /// Get source by ID
  Future<Source?> getSource(String sourceId) async {
    await _ensureInitialized();
    return await _db.getSource(sourceId);
  }

  /// Get source content
  Future<Map<String, dynamic>?> getSourceContent(String sourceId) async {
    await _ensureInitialized();
    return await _db.getSourceContent(sourceId);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    
    await _db.initialize();
    await _documentProcessor.initialize();
    _initialized = true;
    
    print('📁 FileUploadService initialized');
  }

  /// Pick and upload files from device storage
  Future<List<Source>> pickAndUploadFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
    int? maxSizeInBytes,
  }) async {
    await _ensureInitialized();
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: true, // Load file data into memory
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      final sources = <Source>[];
      
      for (final file in result.files) {
        if (file.bytes == null) {
          print('📁 File ${file.name} has no data, skipping');
          continue;
        }

        // Check file size if limit is specified
        if (maxSizeInBytes != null && file.size > maxSizeInBytes) {
          print('📁 File ${file.name} exceeds size limit (${Helpers.formatFileSize(file.size)}), skipping');
          continue;
        }
        
        final source = await _processUploadedFile(
          fileName: file.name,
          fileData: file.bytes!,
          // Use bytes instead of path for web compatibility
          originalPath: null, // Don't use path on web
        );
        
        if (source != null) {
          sources.add(source);
        }
      }
      
      print('📁 Successfully uploaded ${sources.length} files');
      return sources;

    } catch (e) {
      print('📁 Failed to pick and upload files: $e');
      return [];
    }
  }

  /// Pick and upload images from camera or gallery
  Future<Source?> pickAndUploadImage({
    ImageSource source = ImageSource.gallery,
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    await _ensureInitialized();
    
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );

      if (image == null) return null;

      final imageData = await image.readAsBytes();
      final fileName = path.basename(image.path);
      
      final uploadedSource = await _processUploadedFile(
        fileName: fileName,
        fileData: imageData,
        originalPath: image.path,
      );
      
      if (uploadedSource != null) {
        print('📁 Successfully uploaded image: $fileName');
      }

      return uploadedSource;

    } catch (e) {
      print('📁 Failed to pick and upload image: $e');
      return null;
    }
  }

  /// Upload file from URL
  Future<Source?> uploadFromUrl(String url) async {
    await _ensureInitialized();
    
    try {
      print('📁 Downloading file from URL: $url');
      
      // Create a source for URL processing
      final sourceId = _uuid.v4();
      final now = DateTime.now();
      
      final source = Source(
        id: sourceId,
        filename: Helpers.extractDomain(url) ?? 'web-content',
        status: 'processing',
        stage: 'downloading',
        uploadedAt: now.millisecondsSinceEpoch,
        fileSize: 0,
        mimeType: 'text/html',
        errorMessage: '',
        retryCount: 0,
        sourceType: 'url',
        originalUrl: url,
        title: url,
      );
      
      // Save initial source
      await _db.saveSource(source);
      
      // Actually fetch content using ContentExtractor
      print('📁 Fetching content from URL: $url');
      final contentResult = await _contentExtractor.extractFromUrl(url);
      
      if (contentResult.containsKey('error')) {
        // Handle extraction error
        final errorSource = source.copyWith(
          status: 'failed',
          stage: 'failed',
          errorMessage: contentResult['error'].toString(),
        );
        await _db.saveSource(errorSource);
        return errorSource;
      }
      
      // Extract content and metadata
      final content = contentResult['content'] ?? '';
      final title = contentResult['title'] ?? url;
      final description = contentResult['description'] ?? '';
      final author = contentResult['author'] ?? '';
      final publishedDate = contentResult['publishedDate'] ?? '';
      final wordCount = contentResult['wordCount'] ?? 0;
      
      // Save extracted content to database
      await _db.saveSourceContent(sourceId, {
        'content': content,
        'extractedText': content,
        'title': title,
        'description': description,
        'author': author,
        'publishedDate': publishedDate,
        'wordCount': wordCount,
        'url': url,
        'extractedAt': DateTime.now().toIso8601String(),
        'metadata': contentResult['metadata'] ?? {},
      });
      
      // Update source with successful processing
      final updatedSource = source.copyWith(
        status: 'completed',
        stage: 'completed',
        processedAt: DateTime.now().millisecondsSinceEpoch,
        title: title,
        metadata: {
          'description': description,
          'author': author,
          'publishedDate': publishedDate,
          'wordCount': wordCount,
          'url': url,
        },
      );
      
      await _db.saveSource(updatedSource);
      
      print('📁 URL content fetched and stored successfully: $url');
      return updatedSource;

    } catch (e) {
      print('📁 Failed to upload from URL: $url - $e');
      return null;
    }
  }

  /// Determine MIME type from file name
  String _determineMimeType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    
    switch (extension) {
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.md':
      case '.markdown':
        return 'text/markdown';
      case '.html':
      case '.htm':
        return 'text/html';
      case '.json':
        return 'application/json';
      case '.xml':
        return 'application/xml';
      case '.zip':
        return 'application/zip';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.webp':
        return 'image/webp';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
        return 'audio/ogg';
      case '.m4a':
        return 'audio/mp4';
      case '.mp4':
        return 'video/mp4';
      case '.avi':
        return 'video/x-msvideo';
      case '.mov':
        return 'video/quicktime';
      case '.wmv':
        return 'video/x-ms-wmv';
      default:
        return 'application/octet-stream';
    }
  }

  /// Determine source type from file name and data
  String _determineSourceType(String fileName, Uint8List fileData) {
    final extension = path.extension(fileName).toLowerCase();
    
    switch (extension) {
      case '.pdf':
        return 'pdf';
      case '.txt':
      case '.md':
      case '.markdown':
        return 'text';
      case '.html':
      case '.htm':
        return 'html';
      case '.json':
        return 'json';
      case '.xml':
        return 'xml';
      case '.zip':
      case '.rar':
      case '.7z':
        return 'archive';
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
      case '.webp':
        return 'image';
      case '.mp3':
      case '.wav':
      case '.ogg':
      case '.m4a':
        return 'audio';
      case '.mp4':
      case '.avi':
      case '.mov':
      case '.wmv':
        return 'video';
      case '.doc':
      case '.docx':
      case '.rtf':
      case '.odt':
        return 'document';
      case '.xls':
      case '.xlsx':
      case '.ods':
        return 'spreadsheet';
      case '.ppt':
      case '.pptx':
      case '.odp':
        return 'presentation';
      default:
        return 'file';
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Process uploaded file data
  Future<Source?> _processUploadedFile({
    required String fileName,
    required Uint8List fileData,
    String? originalPath,
  }) async {
    try {
      final sourceId = _uuid.v4();
      final now = DateTime.now();
      final sourceType = _determineSourceType(fileName, fileData);
      
      // Create initial source record
      final source = Source(
        id: sourceId,
        filename: fileName,
        status: 'processing',
        stage: 'uploading',
        uploadedAt: now.millisecondsSinceEpoch,
        fileSize: fileData.length,
        mimeType: _determineMimeType(fileName),
        errorMessage: '',
        retryCount: 0,
        sourceType: sourceType,
        title: path.basenameWithoutExtension(fileName),
      );
      
      // Save initial source
      await _db.saveSource(source);
      
      print('📁 Processing file: $fileName (${Helpers.formatFileSize(fileData.length)})');
      
      // Process the document
      final processingResult = await _documentProcessor.processDocument(source, fileData);
      
      // Update source with processing results
      final updatedSource = source.copyWith(
        status: processingResult.containsKey('error') ? 'failed' : 'completed',
        stage: processingResult.containsKey('error') ? 'failed' : 'completed',
        processedAt: now.millisecondsSinceEpoch,
        errorMessage: processingResult['error']?.toString() ?? '',
        title: processingResult['title']?.toString() ?? source.title,
        metadata: processingResult['metadata'] as Map<String, dynamic>?,
      );
      
      await _db.saveSource(updatedSource);
      
      // Save extracted content
      if (processingResult['extractedText'] != null) {
        await _db.saveSourceContent(sourceId, {
          'content': processingResult['content'],
          'extractedText': processingResult['extractedText'],
          'summary': processingResult['summary'],
          'keywords': processingResult['keywords'],
        });
      }
      
      print('📁 File processing completed: $fileName');
      return updatedSource;

    } catch (e) {
      print('📁 Failed to process uploaded file: $fileName - $e');
      
      // Update source with error
      try {
        final errorSource = Source(
          id: _uuid.v4(),
          filename: fileName,
          status: 'failed',
          stage: 'failed',
          uploadedAt: DateTime.now().millisecondsSinceEpoch,
          fileSize: fileData.length,
          mimeType: _determineMimeType(fileName),
          errorMessage: e.toString(),
          retryCount: 0,
          sourceType: _determineSourceType(fileName, fileData),
          title: path.basenameWithoutExtension(fileName),
        );
        
        await _db.saveSource(errorSource);
        return errorSource;
      } catch (saveError) {
        print('📁 Failed to save error source: $saveError');
        return null;
      }
    }
  }
}
