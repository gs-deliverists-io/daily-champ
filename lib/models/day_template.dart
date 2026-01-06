import 'section.dart';

/// Represents a day template for creating new daily entries
///
/// Templates contain section structures without date-specific content.
/// They define the skeleton of a day that users can fill in.
///
/// Example template file (weekday.md):
/// ```markdown
/// ## Goals
/// -
///
/// ## Work Tasks
/// - [ ] | 2.0h
///
/// ## Personal
/// - [ ] | 1.0h
///
/// ## Notes
/// -
///
/// ## Reflections
///
/// ```
class DayTemplate {
  /// Unique identifier (usually the filename without extension)
  final String id;

  /// Display name for the template
  final String name;

  /// Optional description of what this template is for
  final String? description;

  /// Sections that make up the template structure
  final List<TemplateSection> sections;

  /// Path to the template file (relative to templates directory)
  final String? filePath;

  const DayTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.sections,
    this.filePath,
  });

  /// Create an empty template with no sections
  factory DayTemplate.empty({String? id, String? name}) {
    return DayTemplate(
      id: id ?? 'blank',
      name: name ?? 'Blank',
      description: 'Start with an empty day',
      sections: [],
    );
  }

  /// Create a default weekday template
  factory DayTemplate.weekday() {
    return DayTemplate(
      id: 'weekday',
      name: 'Weekday',
      description: 'Standard work day template',
      sections: [
        const TemplateSection(
          name: 'Goals',
          type: SectionType.list,
          placeholderItems: [''],
        ),
        const TemplateSection(
          name: 'Work Tasks',
          type: SectionType.tasks,
          placeholderItems: ['- [ ] | 2.0h'],
        ),
        const TemplateSection(
          name: 'Personal',
          type: SectionType.tasks,
          placeholderItems: ['- [ ] | 1.0h'],
        ),
        const TemplateSection(
          name: 'Notes',
          type: SectionType.list,
          placeholderItems: [''],
        ),
        const TemplateSection(
          name: 'Reflections',
          type: SectionType.text,
          placeholderItems: [],
        ),
      ],
    );
  }

  /// Create a default weekend template
  factory DayTemplate.weekend() {
    return DayTemplate(
      id: 'weekend',
      name: 'Weekend',
      description: 'Relaxed weekend template',
      sections: [
        const TemplateSection(
          name: 'Goals',
          type: SectionType.list,
          placeholderItems: [''],
        ),
        const TemplateSection(
          name: 'Personal',
          type: SectionType.tasks,
          placeholderItems: ['- [ ] | 1.0h'],
        ),
        const TemplateSection(
          name: 'Notes',
          type: SectionType.list,
          placeholderItems: [''],
        ),
        const TemplateSection(
          name: 'Reflections',
          type: SectionType.text,
          placeholderItems: [],
        ),
      ],
    );
  }

  /// Convert template sections to regular sections for a DailyEntry
  List<Section> toSections() {
    return sections.map((ts) => ts.toSection()).toList();
  }

  /// Create a copy with updated fields
  DayTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<TemplateSection>? sections,
    String? filePath,
  }) {
    return DayTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sections: sections ?? List.from(this.sections),
      filePath: filePath ?? this.filePath,
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sections': sections.map((s) => s.toJson()).toList(),
      'filePath': filePath,
    };
  }

  /// Create from JSON
  factory DayTemplate.fromJson(Map<String, dynamic> json) {
    return DayTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      sections: (json['sections'] as List?)
              ?.map((s) => TemplateSection.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      filePath: json['filePath'] as String?,
    );
  }

  @override
  String toString() {
    return 'DayTemplate(id: $id, name: $name, sections: ${sections.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DayTemplate && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// A section within a template
///
/// Unlike regular Section, this can contain placeholder items
/// that guide the user on what to add.
class TemplateSection {
  final String name;
  final SectionType type;

  /// Placeholder items to include in the section
  /// For tasks: "- [ ] | 2.0h" (empty task with time)
  /// For lists: "" (empty item placeholder)
  /// For text: [] (no placeholders)
  final List<String> placeholderItems;

  const TemplateSection({
    required this.name,
    required this.type,
    this.placeholderItems = const [],
  });

  /// Convert to a regular Section (for use in DailyEntry)
  Section toSection() {
    // Filter out empty placeholders - they're just for the template file
    final items =
        placeholderItems.where((item) => item.trim().isNotEmpty).toList();

    return Section(
      name: name,
      items: items,
      type: type,
    );
  }

  /// Create a copy with updated fields
  TemplateSection copyWith({
    String? name,
    SectionType? type,
    List<String>? placeholderItems,
  }) {
    return TemplateSection(
      name: name ?? this.name,
      type: type ?? this.type,
      placeholderItems: placeholderItems ?? List.from(this.placeholderItems),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.toString(),
      'placeholderItems': placeholderItems,
    };
  }

  /// Create from JSON
  factory TemplateSection.fromJson(Map<String, dynamic> json) {
    return TemplateSection(
      name: json['name'] as String,
      type: SectionType.values.firstWhere(
        (e) => e.toString() == (json['type'] as String),
        orElse: () => SectionType.list,
      ),
      placeholderItems:
          List<String>.from(json['placeholderItems'] as List? ?? []),
    );
  }

  @override
  String toString() {
    return 'TemplateSection(name: $name, type: $type)';
  }
}
