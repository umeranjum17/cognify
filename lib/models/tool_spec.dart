/// Tool specification model for agent system
class ToolSpec {
  final String name;
  final Map<String, dynamic> input;
  final int order;
  final String reasoning;

  ToolSpec({
    required this.name,
    required this.input,
    required this.order,
    required this.reasoning,
  });

  factory ToolSpec.fromJson(Map<String, dynamic> json) {
    return ToolSpec(
      name: json['name'] ?? '',
      input: json['input'] ?? {},
      order: json['order'] ?? 0,
      reasoning: json['reasoning'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'input': input,
      'order': order,
      'reasoning': reasoning,
    };
  }

  @override
  String toString() {
    return 'ToolSpec(name: $name, order: $order, reasoning: $reasoning)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolSpec &&
        other.name == name &&
        other.order == order;
  }

  @override
  int get hashCode {
    return name.hashCode ^ order.hashCode;
  }
}
