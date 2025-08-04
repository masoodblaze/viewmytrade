import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../data/signaling/signaling_service.dart';

class ScreenShareController {
  final SignalingService signalingService;

  ScreenShareController(this.signalingService);

  MediaStream? _currentStream; // ✅ Prevent double stream

  /// Admin starts sharing screen
  Future<void> startScreenShare() async {
    try {
      if (_currentStream != null) {
        print("⚠️ Screen sharing already active.");
        return;
      }

      final pc = await signalingService.initPeerConnection();

      // ✅ Modern constraint format for Flutter Web + Chrome
      final stream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false,
      });

      _currentStream = stream;

      print("✅ Screen capture started. Stream ID: ${stream.id}");

      await signalingService.createOffer(stream);
      signalingService.listenForAnswer();
    } catch (e) {
      print("❌ Failed to start screen share: $e");
    }
  }

  /// User watches the shared screen
  Future<void> watchScreen(Function(MediaStream) onAddRemoteStream) async {
    try {
      final pc = await signalingService.initPeerConnection();
      await signalingService.answerCall(onAddRemoteStream);
    } catch (e) {
      print("❌ Failed to watch screen: $e");
    }
  }

  /// Listen to whether screen sharing is active or ended
  Stream<bool> watchCallStatus() => signalingService.screenShareStatusStream();

  /// End screen share session (admin)
  Future<void> stopScreenShare() async {
    try {
      await signalingService.endCall();

      if (_currentStream != null) {
        _currentStream?.getTracks().forEach((track) => track.stop());
        print("🛑 Screen share stopped.");
        _currentStream = null;
      }
    } catch (e) {
      print("❌ Failed to stop screen share: $e");
    }
  }
}
