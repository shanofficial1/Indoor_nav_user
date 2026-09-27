class NavigationEdge {
  final String from;
  final String to;

  NavigationEdge({
    required this.from,
    required this.to,
  });

  factory NavigationEdge.fromJson(Map<String, dynamic> json) {
    return NavigationEdge(
      from: json['from'] as String,
      to: json['to'] as String,
    );
  }
}