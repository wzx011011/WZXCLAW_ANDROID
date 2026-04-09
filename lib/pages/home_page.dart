import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/connection_state.dart';
import '../models/ws_message.dart';
import '../services/connection_manager.dart';
import '../widgets/connection_status_bar.dart';

/// Main page for wzxClaw Android.
///
/// Displays real-time connection status, a scrollable message log of all
/// received WebSocket messages, and a text input for sending test commands
/// to the wzxClaw desktop IDE.
///
/// This is the Phase 1 "end-to-end verification" UI. Phase 3 will replace
/// the message list with a proper chat UI.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_MessageEntry> _messages = [];

  @override
  void initState() {
    super.initState();
    _autoConnect();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Attempt auto-connect if SharedPreferences has a saved server_url.
  Future<void> _autoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('server_url');
    if (serverUrl != null && serverUrl.isNotEmpty) {
      final token = prefs.getString('auth_token') ?? '';
      try {
        // Build URL with token and role parameters.
        // Supports both relay URL (wss://host/relay/) and direct URL (ws://host:port).
        final uri = Uri.parse(serverUrl);
        final params = Map<String, String>.from(uri.queryParameters);
        params['role'] = 'mobile';
        if (token.isNotEmpty) {
          params['token'] = token;
        }
        final fullUrl = uri.replace(queryParameters: params).toString();
        ConnectionManager.instance.connect(fullUrl);
      } catch (e) {
        // Malformed saved URL -- skip auto-connect, user can fix in settings.
      }
    }
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (ConnectionManager.instance.state != WsConnectionState.connected) return;

    final message = WsMessage(
      event: WsEvents.commandSend,
      data: {'content': text},
    );
    ConnectionManager.instance.send(message);

    // Show the sent message in the local log.
    setState(() {
      _messages.add(_MessageEntry(
        event: '(sent) ${WsEvents.commandSend}',
        content: text,
        isLocal: true,
      ));
    });
    _inputController.clear();
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('wzxClaw'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // -- Connection status bar --
          StreamBuilder<WsConnectionState>(
            stream: ConnectionManager.instance.stateStream,
            initialData: ConnectionManager.instance.state,
            builder: (context, snapshot) {
              final state = snapshot.data ?? WsConnectionState.disconnected;
              return ConnectionStatusBar(state: state);
            },
          ),

          // -- Message list --
          Expanded(
            child: StreamBuilder<WsMessage>(
              stream: ConnectionManager.instance.messageStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final msg = snapshot.data!;
                  // Only add if it is not a duplicate of the last message
                  // (StreamBuilder rebuilds can cause re-emission).
                  final entry = _MessageEntry(
                    event: msg.event,
                    content: msg.data?.toString() ?? '',
                    isLocal: false,
                  );
                  // Avoid duplicate entries on rebuild.
                  if (_messages.isEmpty ||
                      _messages.last.event != entry.event ||
                      _messages.last.content != entry.content) {
                    _messages.add(entry);
                    _scrollToBottom();
                  }
                }

                if (_messages.isEmpty) {
                  return const Center(
                    child: Text(
                      '暂无消息',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final entry = _messages[index];
                    return _buildMessageTile(entry);
                  },
                );
              },
            ),
          ),

          // -- Input bar --
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageTile(_MessageEntry entry) {
    const surfaceColor = Color(0xFF16213E);
    final accentColor = entry.isLocal ? const Color(0xFF6366F1) : Colors.teal;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withOpacity(0.2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.event,
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.content,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    const surfaceColor = Color(0xFF16213E);

    return StreamBuilder<WsConnectionState>(
      stream: ConnectionManager.instance.stateStream,
      initialData: ConnectionManager.instance.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? WsConnectionState.disconnected;
        final isConnected = state == WsConnectionState.connected;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            color: surfaceColor,
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
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: isConnected ? (_) => _sendMessage() : null,
                ),
              ),
              const SizedBox(width: 8),
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

/// Simple data class for messages displayed in the log.
class _MessageEntry {
  final String event;
  final String content;
  final bool isLocal;

  _MessageEntry({
    required this.event,
    required this.content,
    this.isLocal = false,
  });
}
