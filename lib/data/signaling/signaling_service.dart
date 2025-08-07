import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String callId;

  SignalingService(this.callId);

  RTCPeerConnection? _peerConnection;
  final _config = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
    ]
  };

  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _candidateQueue = [];
  StreamSubscription? _offerListener;
  StreamSubscription? _answerListener;
  StreamSubscription? _candidateListener;

  Future<RTCPeerConnection> initPeerConnection() async {
    if (_peerConnection != null &&
        _peerConnection!.signalingState ==
            RTCSignalingState.RTCSignalingStateClosed) {
      await _peerConnection!.close();
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
          });
        }
      };
    }

    return _peerConnection!;
  }

  /// Admin listens for answer
  void listenForAnswer() {
    _firestore.collection('calls').doc(callId).snapshots().listen((doc) async {
      final data = doc.data();
      if (data?['answer'] != null && !_remoteDescriptionSet) {
        final answer = data!['answer'];

        final pc = await initPeerConnection();
        await pc.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
        _remoteDescriptionSet = true;

        for (var candidate in _candidateQueue) {
          await pc.addCandidate(candidate);
        }
        _candidateQueue.clear();
      }
    });

    _listenToCandidates();
  }

  Future<void> createOffer(MediaStream stream) async {
    final pc = await initPeerConnection();
    _remoteDescriptionSet = false;

    for (var track in stream.getTracks()) {
      pc.addTrack(track, stream);
    }

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    await _firestore.collection('calls').doc(callId).set({
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'active': true,
      'timestamp': FieldValue.serverTimestamp()
    });

    _listenForAnswer(); // Admin listens for answer
  }

  Future<void> answerCall(Function(MediaStream) onAddRemoteStream) async {
    final pc = await initPeerConnection();
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

      if (offer != null && !_remoteDescriptionSet) {
        await pc.setRemoteDescription(
          RTCSessionDescription(offer['sdp'], offer['type']),
        );
        _remoteDescriptionSet = true;

        for (var candidate in _candidateQueue) {
          await pc.addCandidate(candidate);
        }
        _candidateQueue.clear();

        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);

        await _firestore.collection('calls').doc(callId).update({
          'answer': {'sdp': answer.sdp, 'type': answer.type}
        });
      }
    });

    _listenToCandidates(); // Viewer listens to ICE
  }

  void _listenForAnswer() {
    _answerListener?.cancel();
    _answerListener = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      if (data?['answer'] != null && !_remoteDescriptionSet) {
        final answer = data?['answer'];
        final pc = await initPeerConnection();

        await pc.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
        _remoteDescriptionSet = true;

        for (var candidate in _candidateQueue) {
          await pc.addCandidate(candidate);
        }
        _candidateQueue.clear();
      }
    });

    _listenToCandidates(); // Admin listens to ICE
  }

  void _listenToCandidates() {
    _candidateListener?.cancel();
    _candidateListener = _firestore
        .collection('calls')
        .doc(callId)
        .collection('candidates')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        final data = doc.doc.data();
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

  Stream<bool> screenShareStatusStream() {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['active'] == true);
  }

  Future<void> endCall() async {
    try {
      await _firestore.collection('calls').doc(callId).delete();

      _offerListener?.cancel();
      _answerListener?.cancel();
      _candidateListener?.cancel();

      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }

      _remoteDescriptionSet = false;
      _candidateQueue.clear();
    } catch (e) {
      print("❌ Error in endCall: $e");
    }
  }
}
