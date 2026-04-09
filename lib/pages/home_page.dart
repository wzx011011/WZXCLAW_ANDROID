import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../models/connection_state.dart';
import '../services/chat_store.dart';
import '../services/connection_manager.dart';
import '../services/voice_input_service.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/mic_button.dart';
import '../widgets/project_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _revealedMessageIds = <int>{};

  List<ChatMessage> _displayMessages = [];
  bool _isStreaming = false;
  StreamSubscription? _messagesSub;
  StreamSubscription? _streamingSub;
  StreamSubscription? _voiceErrorSub;

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
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _streamingSub?.cancel();
    _voiceErrorSub?.cancel();
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
        backgroundColor: const Color(0xFF16213E),
        title: const Text('清空会话', style: TextStyle(color: Colors.white)),
        content: const Text('确定要清空所有消息吗？',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ChatStore.instance.clearSession();
              setState(() => _revealedMessageIds.clear());
            },
            child:
                const Text('清空', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _toggleTimestamp(int msgId) {
    setState(() {
      if (_revealedMessageIds.contains(msgId)) {
        _revealedMessageIds.remove(msgId);
      } else {
        _revealedMessageIds.add(msgId);
      }
    });
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
      appBar: AppBar(
        title: const Text('wzxClaw'),
        actions: [
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
                  state: snapshot.data ?? WsConnectionState.disconnected);
            },
          ),
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_displayMessages.isEmpty) {
      return const Center(
        child:
            Text('暂无消息', style: TextStyle(color: Colors.white38, fontSize: 14)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _displayMessages.length,
      itemBuilder: (context, index) {
        return _buildMessageItem(_displayMessages[index], index);
      },
    );
  }

  Widget _buildMessageItem(ChatMessage msg, int index) {
    switch (msg.role) {
      case MessageRole.user:
        return _buildUserBubble(msg, index);
      case MessageRole.assistant:
        return _buildAssistantBlock(msg, index);
      case MessageRole.tool:
        return _buildToolBadge(msg);
    }
  }

  Widget _buildUserBubble(ChatMessage msg, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final msgId = msg.id;
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: msgId != null ? () => _toggleTimestamp(msgId) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(msg.content,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
            if (msgId != null && _revealedMessageIds.contains(msgId))
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Text(_formatTime(msg.createdAt),
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantBlock(ChatMessage msg, int index) {
    final msgId = msg.id;
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: msgId != null ? () => _toggleTimestamp(msgId) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: msg.isStreaming
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(msg.content,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 15)),
                        ),
                        const _StreamingCursor(),
                      ],
                    )
                  : Text(msg.content,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 15)),
            ),
            if (msgId != null && _revealedMessageIds.contains(msgId))
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(_formatTime(msg.createdAt),
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolBadge(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔧 ', style: TextStyle(fontSize: 13)),
          Text(msg.toolName ?? 'Tool',
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: msg.toolStatus == ToolCallStatus.running
                  ? Colors.yellow
                  : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

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
            color: Color(0xFF16213E),
            border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  enabled: isConnected,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: isConnected ? '输入指令...' : '未连接',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: isConnected
                        ? const Color(0xFF1A1A2E)
                        : const Color(0xFF0F0F1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: isConnected ? (_) => _sendMessage() : null,
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
              const SizedBox(width: 8),
              if (_isStreaming)
                IconButton(
                  onPressed: () => ChatStore.instance.stopGeneration(),
                  icon: const Icon(Icons.stop_circle,
                      color: Colors.redAccent, size: 28),
                  tooltip: '停止生成',
                )
              else
                IconButton(
                  onPressed: isConnected ? _sendMessage : null,
                  icon: Icon(
                    Icons.send,
                    color: isConnected
                        ? const Color(0xFF6366F1)
                        : Colors.white24,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

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
          style: TextStyle(color: Color(0xFF6366F1), fontSize: 15)),
    );
  }
}
