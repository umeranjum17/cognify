import 'dart:typed_data';
import '../models/source.dart';

class FileUploadService {
  Future<List<Source>> getAllSources() async {
    // Placeholder: backend integration to list sources
    return [];
  }

  Future<Map<String, dynamic>> uploadBytes({
    required String filename,
    required String mimeType,
    required Uint8List data,
  }) async {
    // Placeholder: backend upload
    return {
      'id': filename,
      'name': filename,
      'mimeType': mimeType,
      'size': data.length,
    };
  }
}


