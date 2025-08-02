class RoadmapRole {
  final String id;
  final String name;
  final String path;
  final String url;

  const RoadmapRole({
    required this.id,
    required this.name,
    required this.path,
    required this.url,
  });

  factory RoadmapRole.fromJson(Map<String, dynamic> json) {
    return RoadmapRole(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'url': url,
    };
  }

  @override
  String toString() {
    return 'RoadmapRole(id: $id, name: $name, path: $path, url: $url)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoadmapRole && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class RoadmapRolesResponse {
  final bool success;
  final String? error;
  final RoadmapRolesData? data;

  const RoadmapRolesResponse({
    required this.success,
    this.error,
    this.data,
  });

  factory RoadmapRolesResponse.fromJson(Map<String, dynamic> json) {
    return RoadmapRolesResponse(
      success: json['success'] ?? false,
      error: json['error'],
      data: json['data'] != null ? RoadmapRolesData.fromJson(json['data']) : null,
    );
  }
}

class RoadmapRolesData {
  final String extractedAt;
  final int totalRoles;
  final List<RoadmapRole> roles;

  const RoadmapRolesData({
    required this.extractedAt,
    required this.totalRoles,
    required this.roles,
  });

  factory RoadmapRolesData.fromJson(Map<String, dynamic> json) {
    return RoadmapRolesData(
      extractedAt: json['extractedAt'] ?? '',
      totalRoles: json['totalRoles'] ?? 0,
      roles: (json['roles'] as List<dynamic>?)
          ?.map((role) => RoadmapRole.fromJson(role))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'extractedAt': extractedAt,
      'totalRoles': totalRoles,
      'roles': roles.map((role) => role.toJson()).toList(),
    };
  }
}

class RoadmapRoleSearchResponse {
  final bool success;
  final String? error;
  final RoadmapRoleSearchData? data;

  const RoadmapRoleSearchResponse({
    required this.success,
    this.error,
    this.data,
  });

  factory RoadmapRoleSearchResponse.fromJson(Map<String, dynamic> json) {
    return RoadmapRoleSearchResponse(
      success: json['success'] ?? false,
      error: json['error'],
      data: json['data'] != null ? RoadmapRoleSearchData.fromJson(json['data']) : null,
    );
  }
}

class RoadmapRoleSearchData {
  final String query;
  final int totalMatches;
  final List<RoadmapRole> roles;

  const RoadmapRoleSearchData({
    required this.query,
    required this.totalMatches,
    required this.roles,
  });

  factory RoadmapRoleSearchData.fromJson(Map<String, dynamic> json) {
    return RoadmapRoleSearchData(
      query: json['query'] ?? '',
      totalMatches: json['totalMatches'] ?? 0,
      roles: (json['roles'] as List<dynamic>?)
          ?.map((role) => RoadmapRole.fromJson(role))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'totalMatches': totalMatches,
      'roles': roles.map((role) => role.toJson()).toList(),
    };
  }
}
