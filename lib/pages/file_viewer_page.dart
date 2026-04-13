import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:highlight/highlight.dart' show highlight;

import '../config/app_colors.dart';
import '../services/file_sync_service.dart';

/// Full-screen code viewer with syntax highlighting.
class FileViewerPage extends StatefulWidget {
  final String filePath;
  final String fileName;

  const FileViewerPage({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  FileContent? _content;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content = await FileSyncService.instance.readFile(widget.filePath);
      if (mounted) {
        setState(() {
          _content = content;
          _loading = false;
          if (content == null) _error = '无法读取文件';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _copyContent() {
    if (_content == null) return;
    Clipboard.setData(ClipboardData(text: _content!.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制文件内容'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        backgroundColor: colors.bgSecondary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
            ),
            if (_content != null)
              Text(
                '${_content!.language} · ${_formatSize(_content!.size)}',
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
          ],
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '复制全文',
            onPressed: _copyContent,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFile,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final colors = AppColors.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadFile, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_content == null) return const SizedBox.shrink();

    // Syntax highlight
    List<TextSpan> spans;
    try {
      final result = _content!.language.isNotEmpty
          ? highlight.parse(_content!.content, language: _content!.language)
          : highlight.parse(_content!.content, autoDetection: true);
      spans = _convertNodes(result.nodes ?? []);
    } catch (_) {
      spans = [TextSpan(text: _content!.content)];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText.rich(
            TextSpan(
              children: spans,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<TextSpan> _convertNodes(List<dynamic> nodes) {
    final spans = <TextSpan>[];
    for (final node in nodes) {
      if (node is String) {
        spans.add(TextSpan(text: node));
      } else if (node.className != null) {
        final style = vs2015Theme[node.className] ?? const TextStyle();
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
