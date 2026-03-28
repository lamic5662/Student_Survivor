import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SyllabusWebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const SyllabusWebViewScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<SyllabusWebViewScreen> createState() => _SyllabusWebViewScreenState();
}

class _SyllabusWebViewScreenState extends State<SyllabusWebViewScreen> {
  late final WebViewController _controller;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;
            setState(() {
              _progress = value / 100.0;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _progress < 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _progress),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
