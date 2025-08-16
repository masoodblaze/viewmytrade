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

  // Re-offer plumbing
  MediaStream? _localStream; // admin's active stream (screen + mic)
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _reofferSub;

  // ------------ PeerConnection helpers ------------

  Future<RTCPeerConnection> initPeerConnection() async {
    // If closed, reset
    if (_peerConnection != null &&
        _peerConnection!.signalingState ==
            RTCSignalingState.RTCSignalingStateClosed) {
      try { await _peerConnection!.close(); } catch (_) {}
      _peerConnection = null;
    }

    if (_peerConnection == null) {
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

      // Optional: helpful logs
      _peerConnection!.onIceConnectionState =
          (s) => print('ICE state [$callId]: $s');
      _peerConnection!.onConnectionState =
          (s) => print('PC state [$callId]: $s');
    }

    return _peerConnection!;
  }

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

    _peerConnection!.onIceConnectionState =
        (s) => print('ICE state [$callId]: $s');
    _peerConnection!.onConnectionState =
        (s) => print('PC state [$callId]: $s');

    return _peerConnection!;
  }

  // ------------ Admin flow ------------

  Future<void> createOffer(MediaStream stream) async {
    _localStream = stream; // keep for re-offers
    _remoteDescriptionSet = false;

    final pc = await _newPeerConnection();

    // attach tracks
    for (var track in stream.getTracks()) {
      pc.addTrack(track, stream);
    }

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    await _firestore.collection('calls').doc(callId).set({
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'active': true,
      'offerTimestamp': FieldValue.serverTimestamp(),
      // Clear stale answer to avoid wrong-state apply
      'answer': FieldValue.delete(),
      // Clear any pending request
      'reofferRequestAt': null,
    }, SetOptions(merge: true));

    // Start answer listener with state guard
    listenForAnswer();

    // Start ICE listening for both sides (safe to call multiple times; we cancel previous)
    _listenToCandidates();
  }

  /// Admin listens for viewer's answer; guarded to avoid wrong-state
  void listenForAnswer() {
    _answerListener?.cancel();
    _answerListener =
        _firestore.collection('calls').doc(callId).snapshots().listen(
              (doc) async {
            final data = doc.data();
            if (data?['answer'] == null || _remoteDescriptionSet) return;

            final pc = await initPeerConnection();

            // Only accept answer when we have a local offer pending
            if (pc.signalingState !=
                RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
              // stale/duplicate answer — ignore
              return;
            }

            final answer = data!['answer'];
            await pc.setRemoteDescription(
              RTCSessionDescription(answer['sdp'], answer['type']),
            );
            _remoteDescriptionSet = true;

            // flush queued ICE
            for (var c in _candidateQueue) {
              await pc.addCandidate(c);
            }
            _candidateQueue.clear();
          },
        );
  }

  // ------------ Viewer flow ------------

  Future<void> answerCall(Function(MediaStream) onAddRemoteStream) async {
    // Fresh PC for each (re)join to avoid invalid states
    final pc = await _newPeerConnection();
    _remoteDescriptionSet = false;

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onAddRemoteStream(event.streams[0]);
      }
    };

    _offerListener?.cancel();
    _offerListener = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      final offer = data?['offer'];
      if (offer == null || _remoteDescriptionSet) return;

      await pc.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
      _remoteDescriptionSet = true;

      // Apply queued ICE after remote desc
      for (var c in _candidateQueue) {
        await pc.addCandidate(c);
      }
      _candidateQueue.clear();

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      await _firestore.collection('calls').doc(callId).set({
        'answer': {'sdp': answer.sdp, 'type': answer.type}
      }, SetOptions(merge: true));
    });

    _listenToCandidates(); // Viewer listens to ICE
  }

  // ------------ ICE candidates for both roles ------------

  void _listenToCandidates() {
    _candidateListener?.cancel();
    _candidateListener = _firestore
        .collection('calls')
        .doc(callId)
        .collection('candidates')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );

        if (_remoteDescriptionSet) {
          _peerConnection?.addCandidate(candidate);
        } else {
          _candidateQueue.add(candidate);
        }
      }
    });
  }

  // ------------ Re-offer plumbing ------------

  /// Viewer calls this before answering to ensure admin republishes a fresh offer
  Future<void> requestReoffer() async {
    await _firestore.collection('calls').doc(callId).set({
      'reofferRequestAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Admin calls this after starting sharing; auto re-offers when a viewer refreshes
  void listenForReoffer() {
    _reofferSub?.cancel();
    _reofferSub =
        _firestore.collection('calls').doc(callId).snapshots().listen(
              (snap) async {
            final data = snap.data();
            if (data == null) return;

            final active = (data['active'] ?? false) == true;
            if (!active) return;

            final req = data['reofferRequestAt'];
            final last = data['offerTimestamp'];

            if (req == null) return;
            if (_localStream == null) return;

            // If request is newer than last offer, regenerate offer with same local stream
            if (last == null ||
                (req is Timestamp &&
                    last is Timestamp &&
                    req.compareTo(last) > 0)) {
              print("♻️ Reoffer requested — creating a fresh offer.");
              await createOffer(_localStream!);
            }
          },
        );
  }

  // ------------ Status / cleanup ------------

  Stream<bool> screenShareStatusStream() {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((s) => s.data()?['active'] == true);
  }

  Future<void> endCall() async {
    try {
      await _firestore
          .collection('calls')
          .doc(callId)
          .set({'active': false}, SetOptions(merge: true));

      _offerListener?.cancel();
      _answerListener?.cancel();
      _candidateListener?.cancel();
      _reofferSub?.cancel();

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

  /// One-shot active check for viewer
  Future<bool> isCallActiveOnce() async {
    try {
      final doc = await _firestore.collection('calls').doc(callId).get();
      final data = doc.data();
      return (data?['active'] ?? false) == true;
    } catch (e) {
      print("Error checking active status: $e");
      return false;
    }
  }
}
