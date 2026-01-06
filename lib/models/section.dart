/// Represents a section in the daily entry (Goals, Tasks, Notes, or custom sections)
class Section {
  final String name;
  final List<String> items;
  final SectionType type;

  Section({
    required this.name,
    required this.items,
    this.type = SectionType.list,
  });

  Section copyWith({
    String? name,
    List<String>? items,
    SectionType? type,
  }) {
    return Section(
      name: name ?? this.name,
      items: items ?? List.from(this.items),
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'items': items,
      'type': type.toString(),
    };
  }

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      name: json['name'] as String,
      items: List<String>.from(json['items'] as List? ?? []),
      type: SectionType.values.firstWhere(
        (e) => e.toString() == (json['type'] as String),
        orElse: () => SectionType.list,
      ),
    );
  }
}

/// Type of section content
enum SectionType {
  list, // List items (Goals, Notes, custom list sections)
  text, // Free-form text (Reflections)
  tasks, // Task items with checkboxes (parsed separately)
}
