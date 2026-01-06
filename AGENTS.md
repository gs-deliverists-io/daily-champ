# Agent Guidelines for DailyChamp App (Flutter/Dart)

## Agent Delegation
- For Flutter coding tasks, use the `flutter_dev` subagent via the Task tool
- The flutter_dev agent is an expert in Flutter/Dart best practices and architecture

## Build, Test, and Lint Commands
- Test all: `flutter test`
- Test single file: `flutter test test/services/markdown_parser_test.dart`
- Test with coverage: `flutter test --coverage`
- Run app (macOS): `flutter run -d macos`
- Run app (web): `flutter run -d chrome`
- Lint: `flutter analyze`
- Format: `flutter format lib/ test/`

## Code Style
- Use relative imports for internal files: `import '../models/models.dart';`
- Use absolute imports for packages: `import 'package:flutter/material.dart';`
- Order imports: dart core, flutter, packages, relative (separated by blank lines)
- Use trailing commas for multi-line function calls and widget trees
- Use `const` constructors whenever possible
- Prefer `final` over `var` for immutable variables

## Types and Naming
- Always specify return types for functions
- Use explicit types for class fields (avoid `var` in class scope)
- Classes/enums: PascalCase (e.g., `DailyEntry`, `DayStatus`)
- Functions/variables: camelCase (e.g., `parseTask`, `isCompleted`)
- Private members: prefix with underscore (e.g., `_parseDay`)
- Constants: lowerCamelCase (e.g., `_dateFormat`)

## Error Handling
- Use try-catch for I/O operations and parsing
- Return `null` or empty collections for parse failures (don't throw)
- Log errors with descriptive messages
- Use `orElse` parameter with collection methods for safe defaults
