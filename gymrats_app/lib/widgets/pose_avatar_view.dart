import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/avatar_model.dart';
import '../models/pose_frame.dart';
import '../services/pose/avatar_pose_payload.dart';

/// Local, bundled Three.js renderer fed by the existing ML Kit PoseFrame.
/// No HTTP server, remote URLs, camera access, or second detector in WebView.
class PoseAvatarView extends StatefulWidget {
  const PoseAvatarView({
    super.key,
    this.frame,
    required this.mirror,
    required this.model,
  });
  final PoseFrame? frame;
  final bool mirror;
  final AvatarModel model;

  @override
  State<PoseAvatarView> createState() => _PoseAvatarViewState();
}

class _PoseAvatarViewState extends State<PoseAvatarView>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  Timer? _timer;
  Timer? _loadTimeout;
  bool _pageReady = false,
      _modelReady = false,
      _sending = false,
      _active = true;
  bool _dirty = true;
  int _generation = 0;
  DateTime _lastFrameAt = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      unawaited(_initialize());
    } else {
      _error = '아바타 미리보기는 Android/iOS 앱에서 사용할 수 있어요.';
    }
  }

  Future<void> _initialize() async {
    try {
      final controller = WebViewController();
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0xff182131));
      await controller.addJavaScriptChannel(
        'AvatarHost',
        onMessageReceived: _onMessage,
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              request.url.startsWith('file:') || request.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) _fail('아바타 화면을 열 수 없어요.');
          },
        ),
      );
      if (!mounted) return;
      setState(() {});
      _watchLoading();
      await controller.loadFlutterAsset('assets/avatar/index.html');
      if (!mounted) return;
      _timer = Timer.periodic(
        const Duration(milliseconds: 66),
        (_) => unawaited(_sendPose()),
      );
    } catch (_) {
      _fail('아바타 렌더러를 시작할 수 없어요. 카메라 보기로 돌아가 주세요.');
    }
  }

  void _watchLoading() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(
      const Duration(seconds: 30),
      () => _fail('아바타 로딩 시간이 초과됐어요. 카메라로 전환한 뒤 다시 시도해주세요.'),
    );
  }

  void _fail(String message) {
    if (!mounted) return;
    _loadTimeout?.cancel();
    _modelReady = false;
    setState(() => _error = message);
  }

  void _onMessage(JavaScriptMessage message) {
    if (!mounted) return;
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      switch (data['type']) {
        case 'ready':
          _pageReady = true;
          unawaited(_loadModel());
        case 'modelReady':
          if (data['id'] != widget.model.assetName) return;
          _loadTimeout?.cancel();
          setState(() {
            _modelReady = true;
            _error = null;
            _dirty = true;
          });
        case 'error':
          _fail('아바타를 표시할 수 없어요. 카메라 보기로 돌아가 주세요.');
      }
    } catch (_) {
      _fail('아바타 화면의 응답을 읽을 수 없어요.');
    }
  }

  Future<void> _loadModel() async {
    final generation = ++_generation;
    _modelReady = false;
    if (mounted) setState(() => _error = null);
    _watchLoading();
    try {
      final bytes = await rootBundle.load(widget.model.assetPath);
      final encoded = base64Encode(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      if (!mounted || generation != _generation) return;
      await _controller!.runJavaScript(
        'AvatarBridge.beginModel(${jsonEncode(widget.model.assetName)})',
      );
      // Keep platform-channel messages bounded rather than one >1 MB payload.
      for (var offset = 0; offset < encoded.length; offset += 49152) {
        if (!mounted || generation != _generation) return;
        final end = (offset + 49152).clamp(0, encoded.length);
        await _controller!.runJavaScript(
          'AvatarBridge.appendModel(${jsonEncode(encoded.substring(offset, end))})',
        );
      }
      if (!mounted || generation != _generation) return;
      await _controller!.runJavaScript('AvatarBridge.finishModel()');
    } catch (_) {
      if (generation == _generation) _fail('아바타 파일을 읽을 수 없어요.');
    }
  }

  Future<void> _sendPose() async {
    if (!mounted || !_active || !_modelReady || _sending) return;
    final stale = DateTime.now().difference(_lastFrameAt).inMilliseconds > 500;
    if (!_dirty && !stale) return;
    _dirty = false;
    _sending = true;
    try {
      final payload = avatarPosePayload(
        stale ? null : widget.frame,
        mirror: widget.mirror,
      );
      await _controller!.runJavaScript(
        'AvatarBridge.pose(${jsonEncode(payload)})',
      );
    } catch (_) {
      _fail('아바타 연결이 끊겼어요. 카메라로 전환한 뒤 다시 시도해주세요.');
    } finally {
      _sending = false;
    }
  }

  @override
  void didUpdateWidget(covariant PoseAvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.frame != oldWidget.frame) {
      _lastFrameAt = DateTime.now();
      _dirty = true;
    }
    if (widget.mirror != oldWidget.mirror) _dirty = true;
    if (widget.model != oldWidget.model && _pageReady) unawaited(_loadModel());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_pageReady) unawaited(_setActive());
  }

  Future<void> _setActive() async {
    try {
      await _controller?.runJavaScript('AvatarBridge.setActive($_active)');
    } catch (_) {
      /* A closing WebView needs no update. */
    }
  }

  @override
  void dispose() {
    ++_generation;
    _timer?.cancel();
    _loadTimeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_pageReady) unawaited(_releaseRenderer());
    super.dispose();
  }

  Future<void> _releaseRenderer() async {
    try {
      await _controller?.runJavaScript('AvatarBridge.dispose()');
    } catch (_) {
      /* Native view may already be gone. */
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff182131),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (_controller case final controller?)
          WebViewWidget(controller: controller),
        if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
          )
        else if (!_modelReady)
          const Center(child: CircularProgressIndicator()),
      ],
    ),
  );
}
