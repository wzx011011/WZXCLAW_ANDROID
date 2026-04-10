import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:highlight/highlight.dart' show highlight;
import 'package:markdown/markdown.dart' as md;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_colors.dart';
import '../models/chat_message.dart';
import '../models/connection_state.dart';
import '../services/chat_store.dart';
import '../services/connection_manager.dart';
import '../services/session_sync_service.dart';
import '../services/voice_input_service.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/mic_button.dart';
import '../widgets/permission_bar.dart';
import '../widgets/project_drawer.dart';
import '../widgets/tool_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _displayMessages = [];
  bool _isStreaming = false;
  String? _desktopIdentity;
  PermissionRequest? _permissionRequest;
  StreamSubscription? _messagesSub;
  StreamSubscription? _streamingSub;
  StreamSubscription? _voiceErrorSub;
  StreamSubscription<WsConnectionState>? _connectionStateSub;
  StreamSubscription<String?>? _desktopIdentitySub;
  StreamSubscription<PermissionRequest?>? _permissionSub;

  @override
  void initState() {
    super.initState();
    _autoConnect();
    ChatStore.instance.loadHistory();

    _messagesSub = ChatStore.instance.messagesStream.listen((msgs) {
      if (mounted) {
        setState(() => _displayMessages = msgs);
        if (_isStreaming) _scrollToBottom();
      }
    });

    _streamingSub = ChatStore.instance.streamingStream.listen((streaming) {
      if (mounted) setState(() => _isStreaming = streaming);
    });

    _permissionSub = ChatStore.instance.permissionStream.listen((req) {
      if (mounted) setState(() => _permissionRequest = req);
    });

    _scrollController.addListener(_onScroll);

    _voiceErrorSub = VoiceInputService.instance.errorStream.listen((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(VoiceInputService.errorMessage(error)),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    _connectionStateSub =
        ConnectionManager.instance.stateStream.listen((_) {});

    _desktopIdentitySub =
        ConnectionManager.instance.desktopIdentityStream.listen((identity) {
      if (mounted) setState(() => _desktopIdentity = identity);
    });
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _streamingSub?.cancel();
    _voiceErrorSub?.cancel();
    _connectionStateSub?.cancel();
    _desktopIdentitySub?.cancel();
    _permissionSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _autoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('server_url');
    if (serverUrl != null && serverUrl.isNotEmpty) {
      final token = prefs.getString('auth_token') ?? '';
      try {
        final uri = Uri.parse(serverUrl);
        final params = Map<String, String>.from(uri.queryParameters);
        params['role'] = 'mobile';
        if (token.isNotEmpty) params['token'] = token;
        final fullUrl = uri.replace(queryParameters: params).toString();
        ConnectionManager.instance.connect(fullUrl);
      } catch (e) {
        debugPrint('Auto-connect failed: $e');
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 50) {
      ChatStore.instance.loadMoreMessages();
    }
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (ConnectionManager.instance.state != WsConnectionState.connected) return;
    ChatStore.instance.sendMessage(text);
    _inputController.clear();
    _scrollToBottom();
  }

  void _clearSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title:
            const Text('清空会话', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('确定要清空所有消息吗？',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ChatStore.instance.clearSession();
            },
            child:
                const Text('清空', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        title: StreamBuilder<String?>(
          stream: SessionSyncService.instance.activeSessionStream,
          initialData: SessionSyncService.instance.activeSessionId,
          builder: (context, snapshot) {
            final sessionId = snapshot.data;
            if (sessionId == null) {
              return const Text('wzxClaw',
                  style: TextStyle(color: AppColors.textPrimary));
            }
            // Find session title from cached sessions
            final sessions = SessionSyncService.instance.sessions;
            final match = sessions.where((s) => s.id == sessionId);
            final title = match.isNotEmpty ? match.first.title : 'Session';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('wzxClaw',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 16)),
                Text(
                  title,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          // Return to live chat (clear active session)
          StreamBuilder<String?>(
            stream: SessionSyncService.instance.activeSessionStream,
            initialData: SessionSyncService.instance.activeSessionId,
            builder: (context, snapshot) {
              if (snapshot.data == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: '新对话',
                onPressed: () {
                  SessionSyncService.instance.setActiveSession(null);
                  ChatStore.instance.switchToSession(null);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空会话',
            onPressed: _clearSession,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      drawer: const ProjectDrawer(),
      body: Column(
        children: [
          StreamBuilder<WsConnectionState>(
            stream: ConnectionManager.instance.stateStream,
            initialData: ConnectionManager.instance.state,
            builder: (context, snapshot) {
              return ConnectionStatusBar(
                  state: snapshot.data ?? WsConnectionState.disconnected,
                  desktopIdentity: _desktopIdentity);
            },
          ),
          Expanded(child: _buildMessageList()),
          if (_permissionRequest != null)
            PermissionBar(request: _permissionRequest!),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Message list ───────────────────────────────────────────────────

  Widget _buildMessageList() {
    if (_displayMessages.isEmpty) {
      return const Center(
        child: Text('暂无消息',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      itemCount: _displayMessages.length,
      itemBuilder: (context, index) {
        return _buildMessageItem(_displayMessages[index]);
      },
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    switch (msg.role) {
      case MessageRole.user:
        return _buildUserBubble(msg);
      case MessageRole.assistant:
        return _buildAssistantBlock(msg);
      case MessageRole.tool:
        return ToolCard(message: msg);
    }
  }

  // ── User bubble ────────────────────────────────────────────────────

  Widget _buildUserBubble(ChatMessage msg) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: screenWidth * 0.80),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.userBubble,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(msg.content,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, height: 1.5)),
      ),
    );
  }

  // ── Assistant block with Markdown ──────────────────────────────────

  Widget _buildAssistantBlock(ChatMessage msg) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.assistantBubble,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.isStreaming)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: _buildMarkdownBody(msg.content)),
                const _StreamingCursor(),
              ],
            )
          else
            _buildMarkdownBody(msg.content),
          // Token usage footer
          if (msg.usage != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'In: ${_formatTokens(msg.usage!.inputTokens)} · Out: ${_formatTokens(msg.usage!.outputTokens)}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarkdownBody(String content) {
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        // Text
        p: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14, height: 1.6),
        h1: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold),
        h2: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold),
        h3: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold),
        listBullet: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        // Inline code
        code: TextStyle(
          color: AppColors.textPrimary,
          backgroundColor: AppColors.bgPrimary,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
        // Block code
        codeblockDecoration: BoxDecoration(
          color: AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        // Links
        a: const TextStyle(color: AppColors.accent),
        // Blockquote
        blockquoteDecoration: BoxDecoration(
          border: Border(
              left: BorderSide(color: AppColors.accent, width: 3)),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        // Table
        tableHead: const TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        tableBody: const TextStyle(color: AppColors.textPrimary),
        tableBorder: TableBorder.all(color: AppColors.border),
        // Horizontal rule
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
      ),
      builders: {
        'code': _CodeBlockBuilder(),
      },
      onTapLink: (text, href, title) {
        if (href != null) {
          Clipboard.setData(ClipboardData(text: href));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Link copied: $href'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}k';
    }
    return tokens.toString();
  }

  // ── Input bar ──────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return StreamBuilder<WsConnectionState>(
      stream: ConnectionManager.instance.stateStream,
      initialData: ConnectionManager.instance.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? WsConnectionState.disconnected;
        final isConnected = state == WsConnectionState.connected;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            color: AppColors.bgSecondary,
            border:
                Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: isConnected,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: isConnected ? '输入指令...' : '未连接',
                      hintStyle:
                          const TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: isConnected
                          ? AppColors.bgInput
                          : AppColors.bgPrimary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: isConnected ? (_) => _sendMessage() : null,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                MicButton(
                  onResult: (text) {
                    _inputController.text = text;
                    _inputController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _inputController.text.length),
                    );
                  },
                  isConnected: isConnected,
                  isStreaming: _isStreaming,
                ),
                const SizedBox(width: 4),
                if (_isStreaming)
                  IconButton(
                    onPressed: () => ChatStore.instance.stopGeneration(),
                    icon: const Icon(Icons.stop_circle,
                        color: AppColors.error, size: 28),
                    tooltip: '停止生成',
                  )
                else
                  IconButton(
                    onPressed: isConnected ? _sendMessage : null,
                    icon: Icon(
                      Icons.send,
                      color:
                          isConnected ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Custom code block builder with syntax highlight + copy ────────────

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(
      md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    // Determine language from the element info
    String? language;
    if (element.attributes['class'] != null) {
      final cls = element.attributes['class']!;
      if (cls.startsWith('language-')) {
        language = cls.substring(9);
      }
    }

    return _CodeBlockWidget(code: code, language: language);
  }
}

class _CodeBlockWidget extends StatelessWidget {
  final String code;
  final String? language;

  const _CodeBlockWidget({required this.code, this.language});

  @override
  Widget build(BuildContext context) {
    // Try syntax highlighting
    List<TextSpan> spans;
    try {
      final result = language != null
          ? highlight.parse(code, language: language)
          : highlight.parse(code, autoDetection: true);
      spans = _convertNodes(result.nodes ?? []);
    } catch (_) {
      spans = [TextSpan(text: code)];
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: language + copy button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: const BoxDecoration(
              color: AppColors.bgTertiary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Row(
              children: [
                Text(
                  language?.toLowerCase() ?? 'code',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace'),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 12, color: AppColors.textSecondary),
                      SizedBox(width: 3),
                      Text('Copy',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 300),
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText.rich(
                  TextSpan(
                    children: spans,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Convert highlight.js nodes to Flutter TextSpans with vs2015 theme colors.
  List<TextSpan> _convertNodes(List<dynamic> nodes) {
    final spans = <TextSpan>[];
    for (final node in nodes) {
      if (node is String) {
        spans.add(TextSpan(text: node));
      } else if (node.className != null) {
        final style = vs2015Theme[node.className] ??
            vs2015Theme['${node.className}'] ??
            const TextStyle();
        final children = node.children != null
            ? _convertNodes(node.children!)
            : [TextSpan(text: node.value ?? '')];
        spans.add(TextSpan(style: style, children: children));
      } else {
        if (node.children != null) {
          spans.addAll(_convertNodes(node.children!));
        } else {
          spans.add(TextSpan(text: node.value ?? ''));
        }
      }
    }
    return spans;
  }
}

// ── Streaming cursor ─────────────────────────────────────────────────

class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Text('▌',
          style: TextStyle(color: AppColors.accent, fontSize: 15)),
    );
  }
}
