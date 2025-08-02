import 'dart:convert';

/// User data model
class UserData {
  final String id;
  final String? name;
  final String? email;
  final Map<String, dynamic> preferences;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserData({
    required this.id,
    this.name,
    this.email,
    required this.preferences,
    required this.createdAt,
    required this.updatedAt,
  });

  UserData copyWith({
    String? id,
    String? name,
    String? email,
    Map<String, dynamic>? preferences,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserData(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'preferences': jsonEncode(preferences),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory UserData.fromMap(Map<String, dynamic> map) {
    return UserData(
      id: map['id'] as String,
      name: map['name'] as String?,
      email: map['email'] as String?,
      preferences: jsonDecode(map['preferences'] as String) as Map<String, dynamic>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserData.fromJson(String source) => UserData.fromMap(jsonDecode(source));

  @override
  String toString() {
    return 'UserData(id: $id, name: $name, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserData && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
