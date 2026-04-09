enum MessageRole { user, assistant, tool }

enum ToolCallStatus { running, done }

class ChatMessage {
  final int? id;
  final MessageRole role;
  final String content;
  final String? toolName;
  final ToolCallStatus? toolStatus;
  final DateTime createdAt;
  final bool isStreaming;

  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.toolName,
    this.toolStatus,
    required this.createdAt,
    this.isStreaming = false,
  });

  ChatMessage copyWith({
    int? id,
    String? content,
    ToolCallStatus? toolStatus,
    bool? isStreaming,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        role: role,
        content: content ?? this.content,
        toolName: toolName,
        toolStatus: toolStatus ?? this.toolStatus,
        createdAt: createdAt,
        isStreaming: isStreaming ?? this.isStreaming,
      );

  Map<String, dynamic> toDbMap() => {
        'role': role.index,
        'content': content,
        'tool_name': toolName,
        'tool_status': toolStatus?.index,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ChatMessage.fromDbMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as int?,
        role: MessageRole.values[map['role'] as int],
        content: map['content'] as String,
        toolName: map['tool_name'] as String?,
        toolStatus: map['tool_status'] != null
            ? ToolCallStatus.values[map['tool_status'] as int]
            : null,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}
