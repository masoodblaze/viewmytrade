import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
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

  final _localPreview = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _localPreview.initialize();
  }

  @override
  void dispose() {
    _localPreview.dispose();
    super.dispose();
  }

  Future<void> _toggleScreenShare() async {
    try {
      if (_isSharing) {
        await _controller.stopScreenShare();
        setState(() => _isSharing = false);
        _localPreview.srcObject = null;
      } else {
        await _controller.startScreenShare();
        setState(() => _isSharing = true);
      }
      _error = null;
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _toggleMic() async {
    await _controller.toggleMic();
    setState(() {});
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    Color? bg,
    bool selected = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Ink(
          decoration: BoxDecoration(
            color: bg ?? (selected ? Colors.red.withOpacity(.1) : Colors.white),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black12)],
          ),
          child: IconButton(
            icon: Icon(icon, color: color ?? (selected ? Colors.red : Colors.black87)),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMicOn = _controller.isMicEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Controls')),
      body: Stack(
        children: [
          // Backdrop / placeholder preview
          Positioned.fill(
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: _isSharing
                  ? const Text("Sharing in progress…", style: TextStyle(color: Colors.white70))
                  : const Text("Not sharing", style: TextStyle(color: Colors.white54)),
            ),
          ),

          // Bottom control dock (Meet/Teams-like)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black12)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      icon: isMicOn ? Icons.mic : Icons.mic_off,
                      label: isMicOn ? 'Mute' : 'Unmute',
                      onPressed: _toggleMic,
                      color: isMicOn ? Colors.black87 : Colors.red,
                      selected: !isMicOn,
                    ),
                    _controlButton(
                      icon: _isSharing ? Icons.stop_screen_share : Icons.screen_share,
                      label: _isSharing ? 'Stop' : 'Share',
                      onPressed: _toggleScreenShare,
                      color: _isSharing ? Colors.red : Colors.black87,
                      selected: _isSharing,
                    ),
                    _controlButton(
                      icon: Icons.call_end,
                      label: 'End',
                      onPressed: () async {
                        if (_isSharing) await _controller.stopScreenShare();
                        if (mounted) setState(() => _isSharing = false);
                      },
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 96,
              child: Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
