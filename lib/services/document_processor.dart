import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;

import '../database/database_service.dart';
import '../models/source.dart';
import '../utils/helpers.dart';
import 'openrouter_client.dart';

/// Document processor for handling various file types and content extraction
class DocumentProcessor {
  static final DocumentProcessor _instance = DocumentProcessor._internal();
  // Text processing configuration
  static const int defaultChunkSize = 500;
  static const int defaultChunkOverlap = 50;

  static const List<String> defaultSeparators = ['\n\n', '\n', ' ', ''];
  final DatabaseService _db = DatabaseService();
  final OpenRouterClient _openRouterClient = OpenRouterClient();

  bool _initialized = false;
  factory DocumentProcessor() => _instance;
  DocumentProcessor._internal();

  Future<void> initialize() async {
    if (_initialized) return;
    
    await _db.initialize();
    await _openRouterClient.initialize();
    _initialized = true;
    print('📚 DocumentProcessor initialized');
  }

  /// Process a document and extract content
  Future<Map<String, dynamic>> processDocument(Source source, Uint8List fileData) async {
    await _ensureInitialized();
    
    try {
      print('📚 Processing document: ${source.title} (${source.sourceType})');
      
      Map<String, dynamic> result;
      
      // Use OpenRouter for all file types that can contain text
      if (_isTextExtractable(source.sourceType)) {
        print('📚 Using OpenRouter for text extraction from: ${source.sourceType}');
        result = await _processWithOpenRouter(fileData, source.filename, source.sourceType);
      } else {
        // Fallback to specific processors for non-text files
        switch (source.sourceType.toLowerCase()) {
          case 'zip':
          case 'archive':
            result = await _processArchive(fileData);
            break;
          case 'json':
            result = await _processJson(fileData);
            break;
          case 'xml':
            result = await _processXml(fileData);
            break;
          default:
            // Try OpenRouter for any other file type
            result = await _processWithOpenRouter(fileData, source.filename, source.sourceType);
        }
      }
      
      // Add metadata
      result['sourceId'] = source.id;
      result['sourceType'] = source.sourceType;
      result['processedAt'] = DateTime.now().toIso8601String();
      result['fileSize'] = fileData.length;
      
      // Generate chunks for vector storage
      if (result['extractedText'] != null) {
        result['chunks'] = await _generateChunks(result['extractedText'] as String);
      }
      
      // Extract keywords
      if (result['extractedText'] != null) {
        result['keywords'] = _extractKeywords(result['extractedText'] as String);
      }
      
      print('📚 Document processing completed for: ${source.title}');
      return result;
      
    } catch (e) {
      print('📚 Document processing failed for: ${source.title} - $e');
      return {
        'error': e.toString(),
        'sourceId': source.id,
        'processedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Extract keywords from text
  List<String> _extractKeywords(String text) {
    return Helpers.extractKeywords(text, maxKeywords: 10);
  }

  /// Extract text from file using OpenRouter with Gemini Flash 2.0
  Future<String> _extractTextWithOpenRouter(Uint8List fileData, String fileName) async {
    try {
      print('🤖 Using OpenRouter to extract text from: $fileName');
      print('🤖 File size: ${fileData.length} bytes');
      
      // Convert file data to base64 for API request
      final base64Data = base64Encode(fileData);
      print('🤖 Base64 data length: ${base64Data.length}');
      
      // Determine file type and create appropriate prompt
      final fileExtension = fileName.split('.').last.toLowerCase();
      String prompt;
      
      switch (fileExtension) {
        case 'pdf':
          prompt = '''Please extract and return all the text content from this PDF document. 
          
File name: $fileName
File size: ${fileData.length} bytes

Instructions:
1. Extract all readable text content from the PDF
2. Preserve the structure and formatting as much as possible
3. Include headers, titles, and body text
4. Return only the extracted text, no explanations

Extracted text:''';
          break;
          
        case 'jpg':
        case 'jpeg':
        case 'png':
        case 'gif':
        case 'bmp':
        case 'webp':
          prompt = '''Please extract and describe all the text content visible in this image. 
          
File name: $fileName
File size: ${fileData.length} bytes

Instructions:
1. Extract all text visible in the image (OCR)
2. Describe any diagrams, charts, or visual content
3. Include any labels, captions, or annotations
4. Return only the extracted text and descriptions, no explanations

Extracted text:''';
          break;
          
        case 'doc':
        case 'docx':
          prompt = '''Please extract and return all the text content from this Word document. 
          
File name: $fileName
File size: ${fileData.length} bytes

Instructions:
1. Extract all readable text content from the document
2. Preserve the structure and formatting as much as possible
3. Include headers, titles, and body text
4. Return only the extracted text, no explanations

Extracted text:''';
          break;
          
        case 'xls':
        case 'xlsx':
          prompt = '''Please extract and return all the text content from this Excel spreadsheet. 
          
File name: $fileName
File size: ${fileData.length} bytes

Instructions:
1. Extract all text content from the spreadsheet
2. Include cell values, headers, and any text
3. Preserve the table structure if possible
4. Return only the extracted text, no explanations

Extracted text:''';
          break;
          
        case 'ppt':
        case 'pptx':
          prompt = '''Please extract and return all the text content from this PowerPoint presentation. 
          
File name: $fileName
File size: ${fileData.length} bytes

Instructions:
1. Extract all text content from the presentation
2. Include slide titles, bullet points, and body text
3. Preserve the structure and hierarchy
4. Return only the extracted text, no explanations

Extracted text:''';
          break;
          
        default:
          prompt = '''Please extract and return all the text content from this file. 
          
File name: $fileName
File size: ${fileData.length} bytes

Instructions:
1. Extract all readable text content from the file
2. Preserve the structure and formatting as much as possible
3. Remove any binary data or non-text content
4. Return only the extracted text, no explanations

Extracted text:''';
      }

      final messages = [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': prompt,
            },
            {
              'type': 'image',
              'image_url': {
                'url': 'data:application/octet-stream;base64,$base64Data',
              },
            },
          ],
        },
      ];

      print('🤖 Sending request to OpenRouter with Gemini Flash 2.0');
      print('🤖 File type: $fileExtension');
      print('🤖 Messages structure: ${messages.length} messages');

      final response = await _openRouterClient.chatCompletion(
        model: 'google/gemini-2.0-flash-exp:free',
        messages: messages,
        temperature: 0.1, // Low temperature for consistent extraction
        maxTokens: 4000, // Allow for large text extraction
      );

      print('🤖 OpenRouter response received: ${response.keys}');

      if (response.containsKey('error')) {
        print('❌ OpenRouter text extraction failed: ${response['error']}');
        return '';
      }

      final content = response['choices']?[0]?['message']?['content'] as String?;
      if (content != null && content.isNotEmpty) {
        print('✅ OpenRouter text extraction successful: ${content.length} characters');
        print('✅ First 100 chars: ${content.substring(0, content.length > 100 ? 100 : content.length)}');
        return content;
      } else {
        print('⚠️ OpenRouter returned empty content');
        print('⚠️ Response structure: ${response.toString()}');
        return '';
      }

    } catch (e) {
      print('❌ OpenRouter text extraction error: $e');
      print('❌ Error stack trace: ${StackTrace.current}');
      return '';
    }
  }

  /// Extract title from text content
  String _extractTitleFromText(String text) {
    if (text.isEmpty) return 'Untitled Document';
    
    // Try to find a title in the first few lines
    final lines = text.split('\n').take(5).toList();
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && trimmed.length < 100) {
        return trimmed;
      }
    }
    
    // Fallback: use first 50 characters
    return Helpers.truncateText(text.trim(), 50);
  }

  /// Generate text chunks for vector storage
  Future<List<Map<String, dynamic>>> _generateChunks(String text) async {
    final chunks = <Map<String, dynamic>>[];
    
    if (text.isEmpty) return chunks;
    
    // Split text into chunks
    final textChunks = _splitText(text, defaultChunkSize, defaultChunkOverlap);
    
    for (int i = 0; i < textChunks.length; i++) {
      final chunk = textChunks[i];
      
      chunks.add({
        'index': i,
        'content': chunk,
        'length': chunk.length,
        'wordCount': chunk.split(RegExp(r'\s+')).length,
        'embedding': null, // Will be generated later if needed
      });
    }
    
    return chunks;
  }

  /// Check if file type can contain extractable text
  bool _isTextExtractable(String sourceType) {
    final textTypes = [
      'pdf', 'text', 'txt', 'md', 'markdown', 'html', 'htm',
      'image', 'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
      'document', 'doc', 'docx', 'rtf', 'odt',
      'spreadsheet', 'xls', 'xlsx', 'ods',
      'presentation', 'ppt', 'pptx', 'odp',
    ];
    
    return textTypes.contains(sourceType.toLowerCase());
  }

  /// Convert JSON data to readable text
  String _jsonToText(dynamic data, {int depth = 0}) {
    final buffer = StringBuffer();
    final indent = '  ' * depth;
    
    if (data is Map) {
      for (final entry in data.entries) {
        buffer.writeln('$indent${entry.key}: ${_jsonToText(entry.value, depth: depth + 1)}');
      }
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        buffer.writeln('$indent[$i]: ${_jsonToText(data[i], depth: depth + 1)}');
      }
    } else {
      buffer.write(data.toString());
    }
    
    return buffer.toString();
  }

  /// Process archive files (ZIP, etc.)
  Future<Map<String, dynamic>> _processArchive(Uint8List fileData) async {
    try {
      final archive = ZipDecoder().decodeBytes(fileData);
      final extractedFiles = <Map<String, dynamic>>[];
      final allText = StringBuffer();
      
      for (final file in archive) {
        if (file.isFile) {
          final fileName = file.name;
          final fileContent = file.content as List<int>;
          
          // Try to extract text from supported file types
          String? text;
          if (fileName.endsWith('.txt') || fileName.endsWith('.md')) {
            text = utf8.decode(fileContent);
          } else if (fileName.endsWith('.html') || fileName.endsWith('.htm')) {
            final htmlDoc = html_parser.parse(utf8.decode(fileContent));
            text = htmlDoc.body?.text ?? htmlDoc.text;
          }
          
          extractedFiles.add({
            'name': fileName,
            'size': fileContent.length,
            'text': text,
          });
          
          if (text != null) {
            allText.writeln(text);
          }
        }
      }
      
      return {
        'content': 'Archive with ${archive.length} files',
        'extractedText': allText.toString(),
        'title': 'Archive Document',
        'files': extractedFiles,
        'metadata': {
          'type': 'archive',
          'size': fileData.length,
          'fileCount': archive.length,
        }
      };
    } catch (e) {
      throw Exception('Failed to process archive file: $e');
    }
  }

  /// Process generic files by attempting to decode as text
  Future<Map<String, dynamic>> _processGenericFile(Uint8List fileData) async {
    try {
      // Try OpenRouter extraction first for better text processing
      String extractedText = await _extractTextWithOpenRouter(fileData, 'generic_file');
      
      if (extractedText.isNotEmpty) {
        return {
          'content': extractedText,
          'extractedText': extractedText,
          'title': _extractTitleFromText(extractedText),
          'metadata': {
            'type': 'generic',
            'size': fileData.length,
            'extractionMethod': 'openrouter',
          }
        };
      }
      
      // Fallback to basic UTF-8 decoding
      try {
        final text = utf8.decode(fileData);
        return {
          'content': text,
          'extractedText': text,
          'title': 'Generic Document',
          'metadata': {
            'type': 'generic',
            'size': fileData.length,
            'extractionMethod': 'utf8',
          }
        };
      } catch (e) {
        // If UTF-8 decoding fails, treat as binary
        return {
          'content': 'Binary file - content not extractable',
          'extractedText': '',
          'title': 'Binary Document',
          'metadata': {
            'type': 'binary',
            'size': fileData.length,
            'extractionMethod': 'none',
          }
        };
      }
    } catch (e) {
      throw Exception('Failed to process generic file: $e');
    }
  }

  /// Process HTML files
  Future<Map<String, dynamic>> _processHtml(Uint8List fileData) async {
    try {
      final htmlContent = utf8.decode(fileData);
      final document = html_parser.parse(htmlContent);
      
      // Extract text content
      final extractedText = document.body?.text ?? document.text ?? '';
      
      // Extract title
      final titleElement = document.querySelector('title');
      final title = titleElement?.text ?? _extractTitleFromText(extractedText);
      
      // Extract metadata
      final metaTags = document.querySelectorAll('meta');
      final metadata = <String, dynamic>{
        'type': 'html',
        'size': fileData.length,
      };
      
      for (final meta in metaTags) {
        final name = meta.attributes['name'] ?? meta.attributes['property'];
        final content = meta.attributes['content'];
        if (name != null && content != null) {
          metadata[name] = content;
        }
      }
      
      return {
        'content': htmlContent,
        'extractedText': extractedText,
        'title': title,
        'metadata': metadata,
      };
    } catch (e) {
      throw Exception('Failed to process HTML file: $e');
    }
  }

  /// Process JSON files
  Future<Map<String, dynamic>> _processJson(Uint8List fileData) async {
    try {
      final jsonContent = utf8.decode(fileData);
      final jsonData = jsonDecode(jsonContent);
      
      // Convert JSON to readable text
      final extractedText = _jsonToText(jsonData);
      
      return {
        'content': jsonContent,
        'extractedText': extractedText,
        'title': 'JSON Document',
        'data': jsonData,
        'metadata': {
          'type': 'json',
          'size': fileData.length,
        }
      };
    } catch (e) {
      throw Exception('Failed to process JSON file: $e');
    }
  }

  /// Process PDF files
  Future<Map<String, dynamic>> _processPdf(Uint8List fileData) async {
    try {
      print('📚 Processing PDF with OpenRouter extraction');
      
      // Use OpenRouter for PDF text extraction
      final extractedText = await _extractTextWithOpenRouter(fileData, 'document.pdf');
      
      if (extractedText.isNotEmpty) {
        return {
          'content': extractedText,
          'extractedText': extractedText,
          'title': _extractTitleFromText(extractedText),
          'pages': 1, // We don't know the actual page count
          'metadata': {
            'type': 'pdf',
            'size': fileData.length,
            'extractionMethod': 'openrouter',
          }
        };
      } else {
        // Fallback to placeholder if OpenRouter fails
        return {
          'content': 'PDF content extraction not yet implemented',
          'extractedText': 'PDF text extraction requires additional implementation',
          'title': 'PDF Document',
          'pages': 1,
          'metadata': {
            'type': 'pdf',
            'size': fileData.length,
            'extractionMethod': 'placeholder',
          }
        };
      }
    } catch (e) {
      throw Exception('Failed to process PDF: $e');
    }
  }

  /// Process text files
  Future<Map<String, dynamic>> _processText(Uint8List fileData) async {
    try {
      // Try OpenRouter extraction first for better text processing
      String extractedText = await _extractTextWithOpenRouter(fileData, 'text_file.txt');
      
      // Fallback to basic UTF-8 decoding if OpenRouter fails
      if (extractedText.isEmpty) {
        print('📚 Falling back to basic text processing');
        extractedText = utf8.decode(fileData);
      }
      
      return {
        'content': extractedText,
        'extractedText': extractedText,
        'title': _extractTitleFromText(extractedText),
        'metadata': {
          'type': 'text',
          'size': fileData.length,
          'lineCount': extractedText.split('\n').length,
          'wordCount': extractedText.split(RegExp(r'\s+')).length,
          'extractionMethod': extractedText.isNotEmpty ? 'openrouter' : 'basic',
        }
      };
    } catch (e) {
      throw Exception('Failed to process text file: $e');
    }
  }

  /// Process file with OpenRouter for text extraction
  Future<Map<String, dynamic>> _processWithOpenRouter(Uint8List fileData, String fileName, String sourceType) async {
    try {
      print('🤖 Processing $sourceType file with OpenRouter: $fileName');
      
      final extractedText = await _extractTextWithOpenRouter(fileData, fileName);
      
      if (extractedText.isNotEmpty) {
        return {
          'content': extractedText,
          'extractedText': extractedText,
          'title': _extractTitleFromText(extractedText),
          'metadata': {
            'type': sourceType,
            'size': fileData.length,
            'extractionMethod': 'openrouter',
            'model': 'google/gemini-2.0-flash-exp:free',
          }
        };
      } else {
        // Fallback for when OpenRouter extraction fails
        return {
          'content': 'Content extraction failed',
          'extractedText': '',
          'title': fileName,
          'metadata': {
            'type': sourceType,
            'size': fileData.length,
            'extractionMethod': 'failed',
          }
        };
      }
    } catch (e) {
      print('❌ OpenRouter processing failed: $e');
      return {
        'content': 'Processing failed: $e',
        'extractedText': '',
        'title': fileName,
        'metadata': {
          'type': sourceType,
          'size': fileData.length,
          'extractionMethod': 'error',
          'error': e.toString(),
        }
      };
    }
  }

  /// Process XML files
  Future<Map<String, dynamic>> _processXml(Uint8List fileData) async {
    try {
      final xmlContent = utf8.decode(fileData);
      
      // Basic XML text extraction (remove tags)
      final extractedText = xmlContent
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      return {
        'content': xmlContent,
        'extractedText': extractedText,
        'title': 'XML Document',
        'metadata': {
          'type': 'xml',
          'size': fileData.length,
        }
      };
    } catch (e) {
      throw Exception('Failed to process XML file: $e');
    }
  }

  /// Split text into chunks with overlap
  List<String> _splitText(String text, int chunkSize, int overlap) {
    final chunks = <String>[];
    
    if (text.length <= chunkSize) {
      chunks.add(text);
      return chunks;
    }
    
    int start = 0;
    while (start < text.length) {
      int end = start + chunkSize;
      if (end > text.length) end = text.length;
      
      // Try to break at word boundaries
      if (end < text.length) {
        final lastSpace = text.lastIndexOf(' ', end);
        if (lastSpace > start) {
          end = lastSpace;
        }
      }
      
      chunks.add(text.substring(start, end).trim());
      start = end - overlap;
      
      if (start >= text.length) break;
    }
    
    return chunks;
  }
}
