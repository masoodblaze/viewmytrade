import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../data/signaling/signaling_service.dart';

class ScreenShareController {
  final SignalingService signalingService;

  ScreenShareController(this.signalingService);

  MediaStream? _currentStream;
  MediaStreamTrack? _micAudioTrack;

  bool get isSharing => _currentStream != null;
  bool get isMicEnabled => _micAudioTrack?.enabled ?? false;

  /// Admin starts sharing screen (screen video + mic audio)
  Future<void> startScreenShare() async {
    try {
      if (_currentStream != null) {
        print("⚠️ Screen sharing already active.");
        return;
      }

      // Prepare the RTCPeerConnection
      await signalingService.initPeerConnection();

      // 1) Capture screen (video)
      final displayStream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false, // don't capture system/tab audio
      });

      // 2) Capture microphone (voice)
      final micStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      // Keep a handle to the mic track for mute/unmute
      _micAudioTrack = micStream.getAudioTracks().firstOrNull;
      if (_micAudioTrack != null) {
        _micAudioTrack!.enabled = true; // default ON
        // 3) Add mic audio track(s) to the screen stream
        displayStream.addTrack(_micAudioTrack!);
      }

      _currentStream = displayStream;

      // Attach browser stop listeners so we clean up if user stops from UI
      _attachStopListeners(displayStream);

      print("✅ Screen + mic capture started. Stream ID: ${displayStream.id}");

      // 4) Create and publish offer, then listen for answer
      await signalingService.createOffer(displayStream);
      signalingService.listenForAnswer();
    } catch (e) {
      print("❌ Failed to start screen share with mic: $e");
    }
  }

  /// Toggle mic mute/unmute
  Future<void> toggleMic() async {
    if (_micAudioTrack == null) return;
    _micAudioTrack!.enabled = !_micAudioTrack!.enabled;
    print(_micAudioTrack!.enabled ? "🎙️ Mic unmuted" : "🔇 Mic muted");
  }

  Future<void> muteMic() async {
    if (_micAudioTrack == null) return;
    _micAudioTrack!.enabled = false;
    print("🔇 Mic muted");
  }

  Future<void> unmuteMic() async {
    if (_micAudioTrack == null) return;
    _micAudioTrack!.enabled = true;
    print("🎙️ Mic unmuted");
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
        _currentStream?.getTracks().forEach((track) {
          try { track.stop(); } catch (_) {}
        });
        print("🛑 Screen share manually stopped.");
        _currentStream = null;
      }

      _micAudioTrack = null;
    } catch (e) {
      print("❌ Failed to stop screen share: $e");
    }
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : this.first;
}
