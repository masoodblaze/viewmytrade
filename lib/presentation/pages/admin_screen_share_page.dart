import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart' hide navigator;
import 'package:viewmytrade/widgets/page_wrapper.dart';
import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';


import '../../main.dart';

class AdminScreenSharePage extends StatefulWidget {
  @override
  _AdminScreenSharePageState createState() => _AdminScreenSharePageState();
}

class _AdminScreenSharePageState extends State<AdminScreenSharePage> {
  final _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _isSharing = false;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  final List<String> _viewerIds = [];

  bool _micEnabled = true;

  late FirebaseSignaling _signaling;
  final _random = Random();
  final String sessionId = 'trading_session_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _signaling = FirebaseSignaling(
        sessionId: sessionId,
        peerId: 'admin_${_random.nextInt(10000)}',
        isAdmin: true
    );

    // Create the session first
    _signaling.createSession().then((_) {
      // Then listen for new viewers
      _subscriptions['viewers'] = _signaling.onViewerJoined.listen(_handleViewerJoined);
    });
  }

  void _toggleMic() {
    if (_localStream == null) return;

    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      final enabled = audioTracks[0].enabled;
      audioTracks[0].enabled = !enabled;

      setState(() {
        _micEnabled = !enabled;
      });
    }
  }


  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
  }

  Future<void> _startScreenSharing() async {
    try {
      final stream = await navigator.mediaDevices.getDisplayMedia({
        'video': {
          'width': 1280,
          'height': 720,
          'frameRate': 30,
          'cursor': 'always'
        },
        'audio': true,
      });

      setState(() {
        _localStream = stream;
        _localRenderer.srcObject = _localStream;
        _isSharing = true;
      });

      // Also update the session status in Firestore
      await FirebaseFirestore.instance.collection('session').doc('current').set({
        'active': true,
        'startedAt': DateTime.now(),
        'sessionId': sessionId,
      });

      _localStream!.getVideoTracks().first.onEnded = () {
        _stopScreenSharing();
      };
    } catch (e) {
      print('Error starting screen sharing: $e');
      Get.snackbar(
          "Error",
          "Failed to start screen sharing: $e",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red
      );
    }
  }

  Future<void> _stopScreenSharing() async {
    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    for (var sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();

    _localStream?.getTracks().forEach((track) => track.stop());

    setState(() {
      _isSharing = false;
      _localStream = null;
      _localRenderer.srcObject = null;
      _viewerIds.clear();
    });

    // Clean up signaling data
    await _signaling.cleanup();

    // Update session status in Firestore
    await FirebaseFirestore.instance.collection('session').doc('current').set({
      'active': false,
      'endedAt': DateTime.now(),
    });
  }

  Future<void> _handleViewerJoined(String viewerId) async {
    if (!_isSharing || _peerConnections.containsKey(viewerId)) return;

    print('Viewer joined: $viewerId');
    setState(() => _viewerIds.add(viewerId));

    final pc = await _createPeerConnection(viewerId);
    _peerConnections[viewerId] = pc;

    // Add tracks to the peer connection
    _localStream!.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    // Create and send offer
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _signaling.sendOfferToViewer(viewerId, offer);

    // Listen for answer
    _subscriptions['answer_$viewerId'] = _signaling.onAnswer(viewerId).listen((answer) async {
      print('Received answer from $viewerId');
      try {
        await pc.setRemoteDescription(answer);
      } catch (e) {
        print('Error setting remote description: $e');
      }
    });

    // ICE candidate handling - send ours
    pc.onIceCandidate = (candidate) {
      print('Admin sending ICE candidate for $viewerId: ${candidate.candidate}');
      _signaling.sendIceCandidate(
        'webrtc/sessions/$sessionId/viewers/$viewerId/adminIceCandidates',
        candidate,
      );
    };

    // ICE candidate handling - receive theirs
    _subscriptions['ice_$viewerId'] = _signaling.onIceCandidates(
      'webrtc/sessions/$sessionId/viewers/$viewerId/viewerIceCandidates',
    ).listen((candidate) {
      print('Admin received ICE candidate from $viewerId: ${candidate.candidate}');
      pc.addCandidate(candidate);
    });
  }

  Future<RTCPeerConnection> _createPeerConnection(String viewerId) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        // Add your TURN servers here for better connectivity
        {
          'urls': "stun:stun.relay.metered.ca:80",
        },
        {
          'urls': "turn:standard.relay.metered.ca:80",
          'username': "f3b3d3b9714bd6cece2b0df9",
          'credential': "3TgQGiz5tcxmvVo2",
        },
        {
          'urls': "turn:standard.relay.metered.ca:80?transport=tcp",
          'username': "f3b3d3b9714bd6cece2b0df9",
          'credential': "3TgQGiz5tcxmvVo2",
        },
        {
          'urls': "turn:standard.relay.metered.ca:443",
          'username': "f3b3d3b9714bd6cece2b0df9",
          'credential': "3TgQGiz5tcxmvVo2",
        },
        {
          'urls': "turns:standard.relay.metered.ca:443?transport=tcp",
          'username': "f3b3d3b9714bd6cece2b0df9",
          'credential': "3TgQGiz5tcxmvVo2",
        },
      ]
    };

    final pc = await createPeerConnection(config, {});

    // Add connection state logging
    pc.onConnectionState = (state) {
      print('Admin -> Viewer($viewerId) connection: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        // Clean up if disconnected
        _cleanupViewer(viewerId);
      }
    };

    pc.onIceConnectionState = (state) {
      print('Admin -> Viewer($viewerId) ICE state: $state');
    };

    return pc;
  }

  void _cleanupViewer(String viewerId) {
    _peerConnections[viewerId]?.close();
    _peerConnections.remove(viewerId);
    _subscriptions['answer_$viewerId']?.cancel();
    _subscriptions['ice_$viewerId']?.cancel();
    _subscriptions.remove('answer_$viewerId');
    _subscriptions.remove('ice_$viewerId');
    setState(() => _viewerIds.remove(viewerId));
  }

  @override
  void dispose() {
    _stopScreenSharing();
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Screen Sharing - Active Session'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSharing ? Icons.stop : Icons.screen_share),
            onPressed: _isSharing ? _stopScreenSharing : _startScreenSharing,
          ),
          if (_isSharing)  // show only when sharing
            IconButton(
              icon: Icon(
                _micEnabled ? Icons.mic : Icons.mic_off,
                color: _micEnabled ? Colors.green : Colors.red,
              ),
              onPressed: _toggleMic,
            ),
        ],
      ),
      body: PageWrapper(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: _isSharing
                  ? RTCVideoView(_localRenderer, mirror: false)
                  : Center(child: Text('Press share to start screen sharing')),
            ),
            Divider(),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Connected Viewers: ${_viewerIds.length}'),
            ),
            Expanded(
              flex: 1,
              child: ListView.builder(
                itemCount: _viewerIds.length,
                itemBuilder: (_, index) {
                  return ListTile(
                    leading: Icon(Icons.person),
                    title: Text('Viewer ${_viewerIds[index]}'),
                    trailing: Icon(Icons.videocam, color: Colors.green),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}