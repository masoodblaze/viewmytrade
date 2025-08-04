
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String callId;

  SignalingService(this.callId);

  late RTCPeerConnection _peerConnection;
  final _config = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
    ]
  };

  bool _remoteDescriptionSet = false;

  Future<RTCPeerConnection> initPeerConnection() async {
    _peerConnection = await createPeerConnection(_config);

    _peerConnection.onIceCandidate = (candidate) async {
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

    return _peerConnection;
  }

  Future<void> createOffer(MediaStream stream) async {
    for (var track in stream.getTracks()) {
      _peerConnection.addTrack(track, stream);
    }
    final offer = await _peerConnection.createOffer();
    await _peerConnection.setLocalDescription(offer);

    await _firestore.collection('calls').doc(callId).set({
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'active': true,
      'timestamp': FieldValue.serverTimestamp()
    });

    listenForAnswer(); // moved here to prevent duplicate listener
  }

  Future<void> answerCall(Function(MediaStream) onAddRemoteStream) async {
    _peerConnection.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onAddRemoteStream(event.streams[0]);
      }
    };

    final offerSnapshot = await _firestore.collection('calls').doc(callId).get();
    final offer = offerSnapshot.data()?['offer'];

    if (offer == null) return;

    await _peerConnection.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']));
    _remoteDescriptionSet = true;

    final answer = await _peerConnection.createAnswer();
    await _peerConnection.setLocalDescription(answer);

    await _firestore.collection('calls').doc(callId).update({
      'answer': {'sdp': answer.sdp, 'type': answer.type}
    });

    _listenToCandidates(); // start listening to ICE
  }

  void listenForAnswer() {
    _firestore.collection('calls').doc(callId).snapshots().listen((doc) {
      final data = doc.data();
      if (data?['answer'] != null && !_remoteDescriptionSet) {
        final answer = data!['answer'];
        _peerConnection.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
        _remoteDescriptionSet = true;
      }
    });

    _listenToCandidates();
  }

  void _listenToCandidates() {
    _firestore.collection('calls').doc(callId).collection('candidates').snapshots().listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (_remoteDescriptionSet) {
          _peerConnection.addCandidate(RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ));
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
    await _firestore.collection('calls').doc(callId).update({'active': false});
    await _peerConnection.close();
  }
}
