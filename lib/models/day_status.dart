/// Day completion status enum
enum DayStatus {
  win, // All tasks completed
  loss, // Not all tasks completed or no tasks
  pending, // Today (in progress)
  scheduled, // Future day (planned)
}

extension DayStatusExtension on DayStatus {
  String get displayName {
    switch (this) {
      case DayStatus.win:
        return 'WIN';
      case DayStatus.loss:
        return 'LOSS';
      case DayStatus.pending:
        return 'PENDING';
      case DayStatus.scheduled:
        return 'SCHEDULED';
    }
  }

  String get emoji {
    switch (this) {
      case DayStatus.win:
        return '✅';
      case DayStatus.loss:
        return '❌';
      case DayStatus.pending:
        return '⏳';
      case DayStatus.scheduled:
        return '📅';
    }
  }

  String get badge {
    switch (this) {
      case DayStatus.win:
        return 'W';
      case DayStatus.loss:
        return 'L';
      case DayStatus.pending:
        return 'P';
      case DayStatus.scheduled:
        return 'S';
    }
  }
}
