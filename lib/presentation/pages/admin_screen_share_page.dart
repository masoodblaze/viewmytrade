
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viewmytrade/presentation/controllers/screen_share_controller.dart';
import '../../../data/signaling/signaling_service.dart';

class AdminScreenSharePage extends StatefulWidget {
  @override
  State<AdminScreenSharePage> createState() => _AdminScreenSharePageState();
}

class _AdminScreenSharePageState extends State<AdminScreenSharePage> {
  final _controller = ScreenShareController(SignalingService("global-broadcast"));
  bool _isSharing = false;
  String? _error;

  void _toggleScreenShare() async {
    if (_isSharing) {
      await _controller.stopScreenShare();
      setState(() {
        _isSharing = false;
        _error = null;
      });
    } else {
      try {
        await _controller.startScreenShare();
        setState(() {
          _isSharing = true;
          _error = null;
        });
      } catch (e) {
        print('❌ Failed to start screen share: \$e');
        setState(() {
          _error = '❌ Screen sharing failed. Check browser permissions.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Admin Screen Share")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _toggleScreenShare,
              child: Text(_isSharing ? "Stop Sharing" : "Start Sharing"),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: TextStyle(color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }
}
