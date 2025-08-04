
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:viewmytrade/presentation/controllers/screen_share_controller.dart';
import '../../../data/signaling/signaling_service.dart';

class UserWatchPage extends StatefulWidget {
  @override
  State<UserWatchPage> createState() => _UserWatchPageState();
}

class _UserWatchPageState extends State<UserWatchPage> {
  final _renderer = RTCVideoRenderer();
  final _controller = ScreenShareController(SignalingService("global-broadcast"));

  bool _isActive = false;
  bool _isWatching = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _renderer.initialize();
    _controller.watchCallStatus().listen((active) async {
      setState(() => _isActive = active);

      if (active && !_isWatching) {
        _isWatching = true;
        try {
          await _controller.watchScreen((stream) {
            _renderer.srcObject = stream;
          });
        } catch (e) {
          print('Error starting watch: \$e');
        }
      } else if (!active) {
        _isWatching = false;
        _renderer.srcObject = null;
      }
    });
  }

  @override
  void dispose() {
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Watch Screen')),
      body: _isActive
          ? RTCVideoView(_renderer)
          : Center(child: Text('No screen sharing active')),
    );
  }
}
