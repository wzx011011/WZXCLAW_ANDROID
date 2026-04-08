import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/connection_state.dart';
import '../services/connection_manager.dart';

/// Settings page for configuring WebSocket connection parameters.
///
/// Allows the user to enter a server URL and authentication token,
/// which are persisted to SharedPreferences. Provides connect/disconnect
/// controls and shows the current connection state.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _serverUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _obscureToken = true;
  bool _loading = true;

  static const _serverUrlKey = 'server_url';
  static const _authTokenKey = 'auth_token';

  @override
  void initState() {
    super.initState();
    _loadSavedValues();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedValues() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrlController.text = prefs.getString(_serverUrlKey) ?? '';
    _tokenController.text = prefs.getString(_authTokenKey) ?? '';
    setState(() => _loading = false);
  }

  Future<void> _saveValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, _serverUrlController.text.trim());
    await prefs.setString(_authTokenKey, _tokenController.text.trim());
  }

  void _connect() {
    final serverUrl = _serverUrlController.text.trim();
    final token = _tokenController.text.trim();
    if (serverUrl.isEmpty) return;

    _saveValues();

    // Construct URL with token parameter matching desktop's expected format.
    final fullUrl = token.isEmpty ? serverUrl : '$serverUrl/?token=$token';
    ConnectionManager.instance.connect(fullUrl);
  }

  void _disconnect() {
    ConnectionManager.instance.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF1A1A2E);
    const surfaceColor = Color(0xFF16213E);
    const accentColor = Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: surfaceColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // -- Server URL field --
                const Text(
                  '服务器地址',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _serverUrlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'ws://192.168.1.100:3000',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // -- Token field --
                const Text(
                  'Token',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tokenController,
                  obscureText: _obscureToken,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '输入连接令牌',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureToken ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        setState(() => _obscureToken = !_obscureToken);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // -- Connect / Disconnect buttons --
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _connect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('连接'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _disconnect,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('断开'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // -- Connection state label --
                StreamBuilder<WsConnectionState>(
                  stream: ConnectionManager.instance.stateStream,
                  initialData: ConnectionManager.instance.state,
                  builder: (context, snapshot) {
                    final state = snapshot.data ?? WsConnectionState.disconnected;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '当前状态: ',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            state.label,
                            style: TextStyle(
                              color: _stateColor(state),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Color _stateColor(WsConnectionState state) {
    switch (state) {
      case WsConnectionState.connected:
        return Colors.green;
      case WsConnectionState.connecting:
      case WsConnectionState.reconnecting:
        return Colors.yellow;
      case WsConnectionState.disconnected:
        return Colors.red;
    }
  }
}
