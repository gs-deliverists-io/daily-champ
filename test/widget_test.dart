// Basic widget test for Execute app
//
// Note: This app requires file system access and Provider setup,
// so widget tests focus on simpler components. Full app testing
// is done via markdown_parser_test.dart and markdown_writer_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailychamp_app/models/models.dart';
import 'package:dailychamp_app/widgets/task_tile.dart';

void main() {
  group('TaskTile Widget', () {
    testWidgets('displays task title correctly', (WidgetTester tester) async {
      final task = Task(
        title: 'Test Task',
        estimatedHours: 2.0,
        isCompleted: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskTile(
              task: task,
              onToggle: () {},
              onTap: () {},
              onDelete: () {},
              onCopyToTomorrow: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Task'), findsOneWidget);
      expect(find.text('2h'),
          findsOneWidget); // Updated: whole numbers show without decimal
    });

    testWidgets('shows completed state correctly', (WidgetTester tester) async {
      final task = Task(
        title: 'Completed Task',
        estimatedHours: 1.0,
        isCompleted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskTile(
              task: task,
              onToggle: () {},
              onTap: () {},
              onDelete: () {},
              onCopyToTomorrow: () {},
            ),
          ),
        ),
      );

      expect(find.text('Completed Task'), findsOneWidget);
      // Completed tasks show check icon inside the checkbox container
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}
