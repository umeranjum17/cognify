

class Source {
  final String id;
  final String filename;
  final String status;
  final String stage;
  final int uploadedAt;
  final int? processedAt;
  final int fileSize;
  final String mimeType;
  final String errorMessage;
  final int retryCount;
  final int? processingDuration;
  final String? progressMessage;
  final double? progress;
  final int? lastUpdated;
  final String sourceType; // 'file' | 'url' | 'youtube' | 'medium' | 'blink' | 'website'
  final String? originalUrl;
  final String? title;
  final String? description;
  final String? thumbnail;
  final String? author;
  final String? publishedAt;
  final Map<String, dynamic>? metadata;

  Source({
    required this.id,
    required this.filename,
    required this.status,
    required this.stage,
    required this.uploadedAt,
    this.processedAt,
    required this.fileSize,
    required this.mimeType,
    required this.errorMessage,
    required this.retryCount,
    this.processingDuration,
    this.progressMessage,
    this.progress,
    this.lastUpdated,
    required this.sourceType,
    this.originalUrl,
    this.title,
    this.description,
    this.thumbnail,
    this.author,
    this.publishedAt,
    this.metadata,
  });

  factory Source.fromJson(Map<String, dynamic> json) => Source(
        id: json['id'] ?? '',
        filename: json['filename'] ?? '',
        status: json['status'] ?? '',
        stage: json['stage'] ?? '',
        uploadedAt: json['uploadedAt'] ?? 0,
        processedAt: json['processedAt'],
        fileSize: json['fileSize'] ?? 0,
        mimeType: json['mimeType'] ?? '',
        errorMessage: json['errorMessage'] ?? '',
        retryCount: json['retryCount'] ?? 0,
        processingDuration: json['processingDuration'],
        progressMessage: json['progressMessage'],
        progress: json['progress']?.toDouble(),
        lastUpdated: json['lastUpdated'],
        sourceType: json['sourceType'] ?? 'file',
        originalUrl: json['originalUrl'],
        title: json['title'],
        description: json['description'],
        thumbnail: json['thumbnail'],
        author: json['author'],
        publishedAt: json['publishedAt'],
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

  factory Source.fromMap(Map<String, dynamic> map) {
    return Source(
      id: map['id'] ?? '',
      filename: map['filename'] ?? '',
      status: map['status'] ?? '',
      stage: map['stage'] ?? '',
      uploadedAt: map['uploaded_at'] ?? 0,
      processedAt: map['processed_at'],
      fileSize: map['file_size'] ?? 0,
      mimeType: map['mime_type'] ?? '',
      errorMessage: map['error_message'] ?? '',
      retryCount: map['retry_count'] ?? 0,
      processingDuration: map['processing_duration'],
      progressMessage: map['progress_message'],
      progress: map['progress']?.toDouble(),
      lastUpdated: map['last_updated'],
      sourceType: map['source_type'] ?? '',
      originalUrl: map['original_url'],
      title: map['title'],
      description: map['description'],
      thumbnail: map['thumbnail'],
      author: map['author'],
      publishedAt: map['published_at'],
      metadata: map['metadata'],
    );
  }

  Source copyWith({
    String? id,
    String? filename,
    String? status,
    String? stage,
    int? uploadedAt,
    int? processedAt,
    int? fileSize,
    String? mimeType,
    String? errorMessage,
    int? retryCount,
    int? processingDuration,
    String? progressMessage,
    double? progress,
    int? lastUpdated,
    String? sourceType,
    String? originalUrl,
    String? title,
    String? description,
    String? thumbnail,
    String? author,
    String? publishedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Source(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      status: status ?? this.status,
      stage: stage ?? this.stage,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      processedAt: processedAt ?? this.processedAt,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
      processingDuration: processingDuration ?? this.processingDuration,
      progressMessage: progressMessage ?? this.progressMessage,
      progress: progress ?? this.progress,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      sourceType: sourceType ?? this.sourceType,
      originalUrl: originalUrl ?? this.originalUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnail: thumbnail ?? this.thumbnail,
      author: author ?? this.author,
      publishedAt: publishedAt ?? this.publishedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'status': status,
        'stage': stage,
        'uploadedAt': uploadedAt,
        'processedAt': processedAt,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'errorMessage': errorMessage,
        'retryCount': retryCount,
        'processingDuration': processingDuration,
        'progressMessage': progressMessage,
        'progress': progress,
        'lastUpdated': lastUpdated,
        'sourceType': sourceType,
        'originalUrl': originalUrl,
        'title': title,
        'description': description,
        'thumbnail': thumbnail,
        'author': author,
        'publishedAt': publishedAt,
        'metadata': metadata,
      };

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filename': filename,
      'status': status,
      'stage': stage,
      'uploaded_at': uploadedAt,
      'processed_at': processedAt,
      'file_size': fileSize,
      'mime_type': mimeType,
      'error_message': errorMessage,
      'retry_count': retryCount,
      'processing_duration': processingDuration,
      'progress_message': progressMessage,
      'progress': progress,
      'last_updated': lastUpdated,
      'source_type': sourceType,
      'original_url': originalUrl,
      'title': title,
      'description': description,
      'thumbnail': thumbnail,
      'author': author,
      'published_at': publishedAt,
      'metadata': metadata,
    };
  }
}
