import 'package:flutter/material.dart';

void main() {
  runApp(const WzxClawApp());
}

/// Root widget for wzxClaw Android.
class WzxClawApp extends StatelessWidget {
  const WzxClawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wzxClaw Android',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const _HomePage(),
    );
  }
}

/// Placeholder home page -- will be replaced in Plan 02.
class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('wzxClaw Android'),
      ),
      body: const Center(
        child: Text('wzxClaw Android'),
      ),
    );
  }
}
