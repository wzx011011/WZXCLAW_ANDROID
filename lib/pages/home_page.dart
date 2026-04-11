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
import '../widgets/animated_message_item.dart';
import '../widgets/ask_user_bar.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/mic_button.dart';
import '../widgets/permission_bar.dart';
import '../widgets/plan_mode_bar.dart';
import '../widgets/project_drawer.dart';
import '../widgets/streaming_shimmer.dart';
import '../widgets/thinking_indicator.dart';
import '../widgets/tool_call_list.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _displayMessages = [];
  bool _isStreaming = false;
  bool _isWaiting = false;
  bool _showScrollFab = false;
  int _previousGroupCount = 0;
  String? _desktopIdentity;
  PermissionRequest? _permissionRequest;
  StreamSubscription? _messagesSub;
  StreamSubscription? _streamingSub;
  StreamSubscription? _voiceErrorSub;
  StreamSubscription<bool>? _waitingSub;
  // _connectionStateSub removed — StreamBuilder handles state reactively
  StreamSubscription<String?>? _desktopIdentitySub;
  StreamSubscription<PermissionRequest?>? _permissionSub;

  // Slash command autocomplete
  List<_SlashCommand> _slashSuggestions = [];
  static const _allSlashCommands = [
    _SlashCommand('/init', 'Generate WZXCLAW.md'),
    _SlashCommand('/compact', 'Compress context'),
    _SlashCommand('/clear', 'New session'),
  ];

  @override
  void initState() {
    super.initState();
    _autoConnect();
    ChatStore.instance.loadHistory();

    _messagesSub = ChatStore.instance.messagesStream.listen((msgs) {
      if (mounted) {
        setState(() => _displayMessages = msgs);
        if (_isStreaming && !_showScrollFab) _scrollToBottom();
      }
    });

    _streamingSub = ChatStore.instance.streamingStream.listen((streaming) {
      if (mounted) setState(() => _isStreaming = streaming);
    });

    _waitingSub = ChatStore.instance.waitingStream.listen((waiting) {
      if (mounted) {
        setState(() => _isWaiting = waiting);
        if (waiting) _scrollToBottom();
      }
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

    _desktopIdentitySub =
        ConnectionManager.instance.desktopIdentityStream.listen((identity) {
      if (mounted) setState(() => _desktopIdentity = identity);
    });
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _streamingSub?.cancel();
    _waitingSub?.cancel();
    _voiceErrorSub?.cancel();
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
    // Show/hide scroll-to-bottom FAB
    final distanceFromBottom = _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    final shouldShow = distanceFromBottom > 100;
    if (shouldShow != _showScrollFab) {
      setState(() => _showScrollFab = shouldShow);
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

  void _showMessageActions(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: const Text('复制文本', style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已复制'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            if (msg.role == MessageRole.user)
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.white70),
                title: const Text('重新发送', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  ChatStore.instance.sendMessage(msg.content);
                },
              ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white70),
              title: const Text('分享', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: msg.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已复制到剪贴板'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
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
          Expanded(
            child: Stack(
              children: [
                _buildMessageList(),
                // Scroll-to-bottom FAB
                if (_showScrollFab)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: AnimatedOpacity(
                      opacity: _showScrollFab ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: FloatingActionButton.small(
                        onPressed: () {
                          _scrollToBottom();
                          setState(() => _showScrollFab = false);
                        },
                        backgroundColor: AppColors.bgElevated,
                        child: const Icon(Icons.keyboard_arrow_down,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_permissionRequest != null)
            PermissionBar(request: _permissionRequest!),
          StreamBuilder<Map<String, dynamic>?>(
            stream: ChatStore.instance.planModeStream,
            builder: (context, snapshot) {
              final planData = snapshot.data;
              if (planData == null) return const SizedBox.shrink();
              return PlanModeBar(planData: planData);
            },
          ),
          StreamBuilder<AskUserQuestion?>(
            stream: ChatStore.instance.askUserStream,
            builder: (context, snapshot) {
              if (snapshot.data == null) return const SizedBox.shrink();
              return AskUserBar(question: snapshot.data!);
            },
          ),
          _buildSlashSuggestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Message list ───────────────────────────────────────────────────

  Widget _buildMessageList() {
    if (_displayMessages.isEmpty && !_isWaiting) {
      return const Center(
        child: Text('暂无消息',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      );
    }

    final showThinking = _isWaiting && !_isStreaming;
    // Group consecutive tool messages together
    final grouped = _groupMessages(_displayMessages);
    final itemCount = grouped.length + (showThinking ? 1 : 0);
    final prevCount = _previousGroupCount;
    _previousGroupCount = grouped.length;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showThinking && index == grouped.length) {
          return const ThinkingIndicator();
        }
        final item = grouped[index];
        Widget child;
        if (item is _ToolGroup) {
          child = ToolCallGroup(tools: item.messages);
        } else {
          child = _buildMessageItem(item as ChatMessage);
        }
        // Animate only newly appended items
        if (index >= prevCount) {
          return AnimatedMessageItem(child: child);
        }
        return child;
      },
    );
  }

  /// Group consecutive tool messages into _ToolGroup objects.
  List<dynamic> _groupMessages(List<ChatMessage> messages) {
    final result = <dynamic>[];
    List<ChatMessage>? currentToolGroup;

    for (final msg in messages) {
      if (msg.role == MessageRole.tool) {
        currentToolGroup ??= [];
        currentToolGroup.add(msg);
      } else {
        if (currentToolGroup != null) {
          result.add(_ToolGroup(currentToolGroup));
          currentToolGroup = null;
        }
        result.add(msg);
      }
    }
    if (currentToolGroup != null) {
      result.add(_ToolGroup(currentToolGroup));
    }
    return result;
  }

  Widget _buildMessageItem(ChatMessage msg) {
    switch (msg.role) {
      case MessageRole.user:
        return _buildUserBubble(msg);
      case MessageRole.assistant:
        return _buildAssistantBlock(msg);
      case MessageRole.tool:
        // Should not reach here — tools are grouped by _groupMessages
        return ToolCallGroup(tools: [msg]);
    }
  }

  // ── User bubble ────────────────────────────────────────────────────

  Widget _buildUserBubble(ChatMessage msg) {
    final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onLongPress: () => _showMessageActions(msg),
      child: Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: screenWidth * 0.80),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                color: Colors.white, fontSize: 13, height: 1.5)),
      ),
      ),
    );
  }

  // ── Assistant block with Markdown ──────────────────────────────────

  Widget _buildAssistantBlock(ChatMessage msg) {
    return GestureDetector(
      onLongPress: () => _showMessageActions(msg),
      child: Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          _buildMarkdownBody(msg.content),
          if (msg.isStreaming) const StreamingShimmer(),
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
      ),
    );
  }

  Widget _buildMarkdownBody(String rawContent) {
    // Strip <details>...</details> blocks — tool outputs are shown via ToolCallGroup
    final content = rawContent.replaceAll(RegExp(r'<details[\s\S]*?</details>'), '').trim();
    if (content.isEmpty) return const SizedBox.shrink();
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        // Text
        p: const TextStyle(
            color: AppColors.textPrimary, fontSize: 13, height: 1.5),
        pPadding: const EdgeInsets.only(bottom: 6),
        h1: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold),
        h2: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold),
        h3: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold),
        listBullet: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        listBulletPadding: const EdgeInsets.only(right: 6),
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

  // ── Slash command autocomplete ────────────────────────────────────

  void _onInputChanged(String text) {
    if (text.startsWith('/')) {
      final query = text.toLowerCase();
      final matches = _allSlashCommands
          .where((cmd) => cmd.command.startsWith(query))
          .toList();
      if (matches.isNotEmpty && text.length < 20) {
        setState(() => _slashSuggestions = matches);
        return;
      }
    }
    if (_slashSuggestions.isNotEmpty) {
      setState(() => _slashSuggestions = []);
    }
  }

  void _selectSlashCommand(_SlashCommand cmd) {
    _inputController.text = cmd.command;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: cmd.command.length),
    );
    setState(() => _slashSuggestions = []);
  }

  Widget _buildSlashSuggestions() {
    if (_slashSuggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _slashSuggestions.map((cmd) {
          return InkWell(
            onTap: () => _selectSlashCommand(cmd),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(
                    cmd.command,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cmd.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
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
                      hintText: isConnected
                          ? (_desktopIdentity != null ? '$_desktopIdentity — 输入指令...' : '输入指令...')
                          : '未连接',
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
                    maxLines: 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: _onInputChanged,
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

class _CodeBlockWidget extends StatefulWidget {
  final String code;
  final String? language;

  const _CodeBlockWidget({required this.code, this.language});

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _collapsed = true;

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    final language = widget.language;
    final lineCount = '\n'.allMatches(code).length + 1;
    final isLong = lineCount > 15;

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
          // Code content with collapse support
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: isLong && _collapsed ? 200 : 600,
            ),
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
          // Show more / less toggle for long code
          if (isLong)
            GestureDetector(
              onTap: () => setState(() => _collapsed = !_collapsed),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.bgTertiary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Text(
                  _collapsed
                      ? 'Show more ($lineCount lines)'
                      : 'Show less',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
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

// ── Helper for grouping consecutive tool messages ─────────────────────

class _ToolGroup {
  final List<ChatMessage> messages;
  const _ToolGroup(this.messages);
}

// ── Slash command model ───────────────────────────────────────────────

class _SlashCommand {
  final String command;
  final String description;
  const _SlashCommand(this.command, this.description);
}
