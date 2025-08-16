import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String callId;

  SignalingService(this.callId);

  RTCPeerConnection? _peerConnection;

  // IMPORTANT: use `urls` (plural)
  final _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _candidateQueue = [];

  StreamSubscription? _offerListener;
  StreamSubscription? _answerListener;
  StreamSubscription? _candidateListener;

  // Keep admin's local stream so we can reattach tracks if needed
  MediaStream? _localStream;

  // ---------- PeerConnection helpers ----------

  Future<RTCPeerConnection> _newPeerConnection() async {
    if (_peerConnection != null) {
      try { await _peerConnection!.close(); } catch (_) {}
      _peerConnection = null;
    }
    _peerConnection = await createPeerConnection(_config);

    _peerConnection!.onIceCandidate = (candidate) async {
      if (candidate != null) {
        await _firestore
            .collection('calls')
            .doc(callId)
            .collection('candidates')
            .add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'ts': FieldValue.serverTimestamp(),
        });
      }
    };

    // Optional logs (helpful while testing)
    _peerConnection!.onIceConnectionState =
        (s) => print('ICE state [$callId]: $s');
    _peerConnection!.onConnectionState =
        (s) => print('PC state [$callId]: $s');

    return _peerConnection!;
  }

  Future<RTCPeerConnection> _ensurePeerConnection() async {
    if (_peerConnection == null) return _newPeerConnection();
    // If it's closed, recreate
    if (_peerConnection!.signalingState ==
        RTCSignalingState.RTCSignalingStateClosed) {
      return _newPeerConnection();
    }
    return _peerConnection!;
  }

  // ---------- Admin flow ----------

  Future<void> createOffer(MediaStream stream) async {
    _localStream = stream;
    _remoteDescriptionSet = false;

    // Fresh PC for a clean negotiation
    final pc = await _newPeerConnection();

    // Attach tracks
    for (final t in stream.getTracks()) {
      pc.addTrack(t, stream);
    }

    // Clear any stale ICE candidates before writing a new offer
    await _clearCandidates();

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    await _firestore.collection('calls').doc(callId).set({
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'active': true,
      'offerTimestamp': FieldValue.serverTimestamp(),
      // Clear stale answer & pending request (if any)
      'answer': FieldValue.delete(),
    }, SetOptions(merge: true));

    _listenForAnswer();   // guarded answer applier
    _listenToCandidates(); // start/refresh ICE listener
  }

  /// Admin listens for viewer's answer; guarded against wrong SDP state.
  void _listenForAnswer() {
    _answerListener?.cancel();
    _answerListener = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      final ans = data?['answer'];
      if (ans == null || _remoteDescriptionSet) return;

      final pc = await _ensurePeerConnection();

      // Only accept answer when we have a local offer pending
      if (pc.signalingState !=
          RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        // Stale/duplicate answer; ignore
        return;
      }

      await pc.setRemoteDescription(
        RTCSessionDescription(ans['sdp'], ans['type']),
      );
      _remoteDescriptionSet = true;

      // Flush queued candidates
      for (final c in _candidateQueue) {
        await pc.addCandidate(c);
      }
      _candidateQueue.clear();
    });
  }

  // ---------- Viewer flow ----------

  /// Viewer answers the **current** offer (one-shot fetch). Uses a fresh PC to avoid state errors.
  Future<void> answerCall(Function(MediaStream) onAddRemoteStream) async {
    final pc = await _newPeerConnection();
    _remoteDescriptionSet = false;

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onAddRemoteStream(event.streams[0]);
      }
    };

    // One-shot fetch of the current offer
    final callSnap =
    await _firestore.collection('calls').doc(callId).get();
    final data = callSnap.data();
    final offer = data?['offer'];
    if (offer == null) {
      print("No active offer to answer.");
      return;
    }

    await pc.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );
    _remoteDescriptionSet = true;

    // Apply queued ICE after remote desc
    for (final c in _candidateQueue) {
      await pc.addCandidate(c);
    }
    _candidateQueue.clear();

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    await _firestore.collection('calls').doc(callId).set({
      'answer': {'sdp': answer.sdp, 'type': answer.type}
    }, SetOptions(merge: true));

    _listenToCandidates(); // start/refresh ICE listener (viewer)
  }

  // ---------- ICE candidates ----------

  void _listenToCandidates() {
    _candidateListener?.cancel();
    _candidateListener = _firestore
        .collection('calls')
        .doc(callId)
        .collection('candidates')
        .orderBy('ts')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final cand = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );

        if (_remoteDescriptionSet) {
          _peerConnection?.addCandidate(cand);
        } else {
          _candidateQueue.add(cand);
        }
      }
    });
  }

  Future<void> _clearCandidates() async {
    final col = _firestore
        .collection('calls')
        .doc(callId)
        .collection('candidates');
    final snap = await col.get();
    final batch = _firestore.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  // ---------- Status & cleanup ----------

  Stream<bool> screenShareStatusStream() {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((s) => s.data()?['active'] == true);
  }

  Future<bool> isCallActiveOnce() async {
    try {
      final doc = await _firestore.collection('calls').doc(callId).get();
      return (doc.data()?['active'] ?? false) == true;
    } catch (e) {
      print("Error checking active status: $e");
      return false;
    }
  }

  Future<void> endCall() async {
    try {
      await _firestore.collection('calls').doc(callId).set({
        'active': false,
        'offer': FieldValue.delete(),
        'answer': FieldValue.delete(),
      }, SetOptions(merge: true));

      await _clearCandidates();

      _offerListener?.cancel();
      _answerListener?.cancel();
      _candidateListener?.cancel();

      if (_peerConnection != null) {
        try { await _peerConnection!.close(); } catch (_) {}
        _peerConnection = null;
      }

      _remoteDescriptionSet = false;
      _candidateQueue.clear();
      _localStream = null;
    } catch (e) {
      print("❌ Error in endCall: $e");
    }
  }
}
