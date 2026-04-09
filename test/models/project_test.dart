import 'package:flutter_test/flutter_test.dart';
import 'package:wzx_claw/models/project.dart';

void main() {
  group('Project', () {
    group('fromJson', () {
      test('parses name and status=running correctly', () {
        final project = Project.fromJson({
          'name': 'my-project',
          'status': 'running',
        });
        expect(project.name, equals('my-project'));
        expect(project.isRunning, isTrue);
      });

      test('parses name and status=idle correctly', () {
        final project = Project.fromJson({
          'name': 'other-project',
          'status': 'idle',
        });
        expect(project.name, equals('other-project'));
        expect(project.isRunning, isFalse);
      });

      test('defaults name to empty string when missing', () {
        final project = Project.fromJson({'status': 'running'});
        expect(project.name, equals(''));
        expect(project.isRunning, isTrue);
      });

      test('defaults isRunning to false when status is missing', () {
        final project = Project.fromJson({'name': 'test'});
        expect(project.name, equals('test'));
        expect(project.isRunning, isFalse);
      });

      test('handles empty map', () {
        final project = Project.fromJson({});
        expect(project.name, equals(''));
        expect(project.isRunning, isFalse);
      });

      test('isRunning is false for arbitrary status string', () {
        final project = Project.fromJson({
          'name': 'test',
          'status': 'unknown_value',
        });
        expect(project.isRunning, isFalse);
      });
    });

    group('constructor defaults', () {
      test('isRunning defaults to false', () {
        final project = Project(name: 'test');
        expect(project.isRunning, isFalse);
      });
    });

    group('copyWith', () {
      test('overrides name', () {
        const original = Project(name: 'old', isRunning: false);
        final copied = original.copyWith(name: 'new');
        expect(copied.name, equals('new'));
        expect(copied.isRunning, isFalse);
      });

      test('overrides isRunning', () {
        const original = Project(name: 'test', isRunning: false);
        final copied = original.copyWith(isRunning: true);
        expect(copied.name, equals('test'));
        expect(copied.isRunning, isTrue);
      });

      test('returns new instance with no changes when called without args', () {
        const original = Project(name: 'test', isRunning: true);
        final copied = original.copyWith();
        expect(copied.name, equals('test'));
        expect(copied.isRunning, isTrue);
        // Verify it is a different instance
        expect(identical(original, copied), isFalse);
      });
    });

    group('equality', () {
      test('equal when name and isRunning match', () {
        const a = Project(name: 'test', isRunning: true);
        const b = Project(name: 'test', isRunning: true);
        expect(a == b, isTrue);
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal when name differs', () {
        const a = Project(name: 'alpha', isRunning: true);
        const b = Project(name: 'beta', isRunning: true);
        expect(a == b, isFalse);
      });

      test('not equal when isRunning differs', () {
        const a = Project(name: 'test', isRunning: true);
        const b = Project(name: 'test', isRunning: false);
        expect(a == b, isFalse);
      });

      test('identical objects are equal', () {
        const project = Project(name: 'test', isRunning: true);
        expect(project == project, isTrue);
      });

      test('not equal to non-Project object', () {
        const project = Project(name: 'test', isRunning: true);
        expect(project == 'test', isFalse);
        expect(project == 42, isFalse);
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        const project = Project(name: 'my-proj', isRunning: true);
        expect(
          project.toString(),
          equals('Project(name: my-proj, isRunning: true)'),
        );
      });
    });
  });
}
