/// Project data model representing a desktop wzxClaw project.
///
/// Parsed from WebSocket responses received after sending `/projects`
/// commands to the desktop IDE.
class Project {
  /// Project name (unique identifier).
  final String name;

  /// Whether the project is currently active/running on the desktop.
  final bool isRunning;

  const Project({required this.name, this.isRunning = false});

  /// Parse from a JSON map received from the desktop.
  ///
  /// Expected fields:
  /// - `name` (String): project name, defaults to empty string
  /// - `status` (String): `'running'` maps to `isRunning = true`, anything else is false
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      name: json['name'] as String? ?? '',
      isRunning: json['status'] == 'running',
    );
  }

  /// Create a copy with optional field overrides.
  Project copyWith({String? name, bool? isRunning}) {
    return Project(
      name: name ?? this.name,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project && name == other.name && isRunning == other.isRunning;

  @override
  int get hashCode => Object.hash(name, isRunning);

  @override
  String toString() => 'Project(name: $name, isRunning: $isRunning)';
}
