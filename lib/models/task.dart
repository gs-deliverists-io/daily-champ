import 'package:uuid/uuid.dart';

/// Individual task within a day
class Task {
  final String id;
  String title;
  double estimatedHours;
  bool isCompleted;
  DateTime? completedAt;
  final DateTime createdAt;

  Task({
    String? id,
    required this.title,
    this.estimatedHours = 0.0,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Toggle task completion status
  void toggle() {
    isCompleted = !isCompleted;
    completedAt = isCompleted ? DateTime.now() : null;
  }

  /// Create a copy of this task
  Task copyWith({
    String? id,
    String? title,
    double? estimatedHours,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'estimatedHours': estimatedHours,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from Map
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      estimatedHours: (json['estimatedHours'] as num).toDouble(),
      isCompleted: json['isCompleted'] as bool,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  String toString() {
    return 'Task(title: $title, hours: $estimatedHours, completed: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
