import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:viewmytrade/presentation/controllers/screen_share_controller.dart';
import '../../../data/signaling/signaling_service.dart';

class UserWatchPage extends StatefulWidget {
  @override
  State<UserWatchPage> createState() => _UserWatchPageState();
}

class _UserWatchPageState extends State<UserWatchPage> {
  // Note: On Web, ensure user interacted with the page to allow autoplay audio.
  // Some browsers block autoplaying audio until a tap/click occurs.
  final _renderer = RTCVideoRenderer();
  final _controller = ScreenShareController(SignalingService("global-broadcast"));

  StreamSubscription<bool>? _statusSub;
  bool _isActive = false;
  bool _isWatching = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _renderer.initialize();

    // 1) Immediate re-join if the session is already active when landing here
    try {
      final activeNow = await _controller.isShareActiveOnce();
      if (activeNow && mounted) {
        setState(() => _isActive = true);
        _startWatchingIfNeeded();
      }
    } catch (e) {
      debugPrint('Active check failed: $e');
    }

    // 2) Also listen for changes to the active status so we re-attach later
    _statusSub = _controller.watchCallStatus().listen((active) async {
      if (!mounted) return;
      setState(() => _isActive = active);

      if (active) {
        _startWatchingIfNeeded();
      } else {
        _isWatching = false;
        _renderer.srcObject = null;
      }
    });
  }

  Future<void> _startWatchingIfNeeded() async {
    if (_isWatching) return;
    _isWatching = true;
    try {
      await _controller.watchScreen((stream) {
        if (!mounted) return;
        _renderer.srcObject = stream;
      });
    } catch (e) {
      if (!mounted) return;
      _isWatching = false; // allow retry on next status event
      debugPrint('Error starting watch: $e');
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();          // stop callbacks after leaving the page
    _renderer.srcObject = null;    // release media source
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Watch Screen')),
      body: _isActive
          ? RTCVideoView(_renderer)
          : const Center(child: Text('No screen sharing active')),
    );
  }
}
