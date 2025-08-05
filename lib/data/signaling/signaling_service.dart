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

  /// Initializes a fresh RTCPeerConnection
  Future<RTCPeerConnection> initPeerConnection() async {
    // Dispose existing connection if it's closed
    if (_peerConnection != null &&
        _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    // Create new connection if null
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

  /// Admin creates offer
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

    listenForAnswer(); // Start listening after offer
  }

  /// Viewer answers the call
  Future<void> answerCall(Function(MediaStream) onAddRemoteStream) async {
    final pc = await initPeerConnection();
    _remoteDescriptionSet = false;

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onAddRemoteStream(event.streams[0]);
      }
    };

    // Listen for offer
    _firestore.collection('calls').doc(callId).snapshots().listen((doc) async {
      final data = doc.data();
      final offer = data?['offer'];

      if (offer != null && !_remoteDescriptionSet) {
        await pc.setRemoteDescription(
          RTCSessionDescription(offer['sdp'], offer['type']),
        );
        _remoteDescriptionSet = true;

        // Flush queued ICE candidates
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

    _listenToCandidates(); // Listen for ICE
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

  /// Listens for ICE candidates
  void _listenToCandidates() {
    _firestore
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

  /// Observes screen sharing active state
  Stream<bool> screenShareStatusStream() {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['active'] == true);
  }

  /// Ends call session
  Future<void> endCall() async {
    await _firestore.collection('calls').doc(callId).delete();

    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    _remoteDescriptionSet = false;
    _candidateQueue.clear();
  }
}
