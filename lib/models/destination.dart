class Destination {
  final String id;
  final String name;

  const Destination({
    required this.id,
    required this.name,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}