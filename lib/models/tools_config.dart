// ToolsConfig model for AI tools configuration

import 'dart:convert';

class ToolsConfig {
  final bool? braveSearch;
  final bool? webFetch;
  final bool? imageSearch;
  final bool? timeTool;

  const ToolsConfig({
    this.braveSearch,
    this.webFetch,
    this.imageSearch,
    this.timeTool,
  });

  factory ToolsConfig.fromJson(Map<String, dynamic> json) {
    return ToolsConfig(
      braveSearch: json['braveSearch'],
      webFetch: json['webFetch'],
      imageSearch: json['imageSearch'],
      timeTool: json['timeTool'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (braveSearch != null) 'braveSearch': braveSearch,
      if (webFetch != null) 'webFetch': webFetch,
      if (imageSearch != null) 'imageSearch': imageSearch,
      if (timeTool != null) 'timeTool': timeTool,
    };
  }
}
