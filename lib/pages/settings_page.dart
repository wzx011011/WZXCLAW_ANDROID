import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/connection_state.dart';
import '../services/connection_manager.dart';

/// Settings page for configuring WebSocket connection parameters.
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
  bool _pushEnabled = true;

  static const _serverUrlKey = 'server_url';
  static const _authTokenKey = 'auth_token';
  static const _pushEnabledKey = 'push_notifications_enabled';

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
    _pushEnabled = prefs.getBool(_pushEnabledKey) ?? true;
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

    final uri = Uri.parse(serverUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    params['role'] = 'mobile';
    if (token.isNotEmpty) {
      params['token'] = token;
    }
    final fullUrl = uri.replace(queryParameters: params).toString();
    ConnectionManager.instance.connect(fullUrl);
  }

  void _disconnect() {
    ConnectionManager.instance.disconnect();
  }

  Future<void> _togglePushNotifications(bool value) async {
    setState(() => _pushEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushEnabledKey, value);
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const _QrScannerPage()),
    );
    if (result != null && result.isNotEmpty && mounted) {
      // Validate it looks like a wzxClaw relay URL
      if (!result.startsWith('wss://') && !result.startsWith('ws://')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请扫描桌面端 wzxClaw 的连接二维码'), duration: Duration(seconds: 2)),
        );
        return;
      }
      try {
        final uri = Uri.parse(result);
        _serverUrlController.text = uri.origin + uri.path;
        _tokenController.text = uri.queryParameters['token'] ?? '';
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('二维码内容无法解析'), duration: Duration(seconds: 2)),
        );
      }
    }
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
                // -- Server URL field with scan button --
                const Text(
                  '服务器地址',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _serverUrlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'wss://5945.top/relay/',
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
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: accentColor, size: 28),
                      onPressed: _scanQrCode,
                      tooltip: '扫描二维码',
                    ),
                  ],
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
                const SizedBox(height: 24),

                // -- Push notification toggle --
                SwitchListTile(
                  title: const Text('推送通知', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('AI 任务完成时发送通知',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  value: _pushEnabled,
                  activeColor: const Color(0xFF6366F1),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  onChanged: _togglePushNotifications,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

/// Full-screen QR scanner page with scan frame overlay and torch toggle.
class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanSize = size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('扫描二维码'),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white70),
            onPressed: () {
              setState(() => _torchOn = !_torchOn);
              _controller.toggleTorch();
            },
            tooltip: '手电筒',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcode = capture.barcodes.first;
              if (barcode.rawValue != null) {
                _controller.stop();
                Navigator.pop(context, barcode.rawValue);
              }
            },
          ),
          // Dimmed overlay with transparent scan window
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut),
                ),
                Center(
                  child: Container(
                    width: scanSize,
                    height: scanSize,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scan frame corners
          Center(
            child: SizedBox(
              width: scanSize,
              height: scanSize,
              child: CustomPaint(painter: _ScanFramePainter()),
            ),
          ),
          // Hint text
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * 0.2,
            child: const Text(
              '将二维码放入框内自动扫描',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints four corner brackets for the scan frame.
class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cornerLen = 24.0;
    const strokeWidth = 3.0;
    final paint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(const Offset(0, cornerLen), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(cornerLen, 0), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - cornerLen, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLen), paint);
    // Bottom-left
    canvas.drawLine(Offset.zero, Offset(0, size.height - cornerLen), paint);
    canvas.drawLine(Offset.zero, Offset(cornerLen, size.height), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height - cornerLen), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width - cornerLen, size.height), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
      ),
    );
  }
}
