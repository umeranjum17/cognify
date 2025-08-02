// ToolsConfig model for AI tools configuration

import 'dart:convert';

class ToolsConfig {
  final bool? braveSearch;
  final bool? sequentialThinking;
  final bool? webFetch;
  final bool? youtubeProcessor;
  final bool? browserRoadmap;
  final bool? imageSearch;
  final bool? keywordExtraction;
  final bool? memoryManager;
  final bool? sourceQuery;
  final bool? sourceContent;
  final bool? timeTool;

  const ToolsConfig({
    this.braveSearch,
    this.sequentialThinking,
    this.webFetch,
    this.youtubeProcessor,
    this.browserRoadmap,
    this.imageSearch,
    this.keywordExtraction,
    this.memoryManager,
    this.sourceQuery,
    this.sourceContent,
    this.timeTool,
  });

  factory ToolsConfig.fromJson(Map<String, dynamic> json) {
    return ToolsConfig(
      braveSearch: json['braveSearch'],
      sequentialThinking: json['sequentialThinking'],
      webFetch: json['webFetch'],
      youtubeProcessor: json['youtubeProcessor'],
      browserRoadmap: json['browserRoadmap'],
      imageSearch: json['imageSearch'],
      keywordExtraction: json['keywordExtraction'],
      memoryManager: json['memoryManager'],
      sourceQuery: json['sourceQuery'],
      sourceContent: json['sourceContent'],
      timeTool: json['timeTool'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (braveSearch != null) 'braveSearch': braveSearch,
      if (sequentialThinking != null) 'sequentialThinking': sequentialThinking,
      if (webFetch != null) 'webFetch': webFetch,
      if (youtubeProcessor != null) 'youtubeProcessor': youtubeProcessor,
      if (browserRoadmap != null) 'browserRoadmap': browserRoadmap,
      if (imageSearch != null) 'imageSearch': imageSearch,
      if (keywordExtraction != null) 'keywordExtraction': keywordExtraction,
      if (memoryManager != null) 'memoryManager': memoryManager,
      if (sourceQuery != null) 'sourceQuery': sourceQuery,
      if (sourceContent != null) 'sourceContent': sourceContent,
      if (timeTool != null) 'timeTool': timeTool,
    };
  }
}
