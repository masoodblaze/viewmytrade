import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../data/signaling/signaling_service.dart';

class ScreenShareController {
  final SignalingService signalingService;

  ScreenShareController(this.signalingService);

  MediaStream? _currentStream;

  /// Admin starts sharing screen
  Future<void> startScreenShare() async {
    try {
      if (_currentStream != null) {
        print("⚠️ Screen sharing already active.");
        return;
      }

      final pc = await signalingService.initPeerConnection();

      // 1. Get screen (display) stream
      final displayStream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false, // Don't capture system audio
      });

      // 2. Get microphone (voice) stream
      final micStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
      });

      // 3. Add mic audio tracks to screen stream
      for (var track in micStream.getAudioTracks()) {
        displayStream.addTrack(track);
      }

      _currentStream = displayStream;

      print("✅ Screen + mic capture started. Stream ID: ${displayStream.id}");

      await signalingService.createOffer(displayStream);
      signalingService.listenForAnswer();
    } catch (e) {
      print("❌ Failed to start screen share with mic: $e");
    }
  }


  /// Attach browser stop listeners to all tracks
  void _attachStopListeners(MediaStream stream) {
    for (var track in stream.getTracks()) {
      track.onEnded = () {
        print("🛑 Browser ended screen share track.");
        stopScreenShare(); // Automatically stop from Flutter side
      };
    }
  }


  /// Viewer joins and watches the screen
  Future<void> watchScreen(Function(MediaStream) onAddRemoteStream) async {
    try {
      await signalingService.initPeerConnection();
      await signalingService.answerCall(onAddRemoteStream);
    } catch (e) {
      print("❌ Failed to watch screen: $e");
    }
  }

  /// Observable screen sharing state
  Stream<bool> watchCallStatus() => signalingService.screenShareStatusStream();

  /// End sharing
  Future<void> stopScreenShare() async {
    try {
      await signalingService.endCall();

      if (_currentStream != null) {
        _currentStream?.getTracks().forEach((track) => track.stop());
        print("🛑 Screen share manually stopped.");
        _currentStream = null;
      }
    } catch (e) {
      print("❌ Failed to stop screen share: $e");
    }
  }
}
