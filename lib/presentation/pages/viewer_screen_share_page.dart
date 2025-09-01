// viewer_screen_share_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:viewmytrade/widgets/page_wrapper.dart';
import 'dart:math';
import 'dart:async';

import '../../main.dart';

class ViewerScreenSharePage extends StatefulWidget {
  @override
  _ViewerScreenSharePageState createState() => _ViewerScreenSharePageState();
}

class _ViewerScreenSharePageState extends State<ViewerScreenSharePage> {
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  bool _isConnected = false;
  bool _isLoading = false;
  late String _viewerId;
  late FirebaseSignaling _signaling;
  final Map<String, StreamSubscription> _subscriptions = {};
  final _random = Random();

  // Connection state tracking
  RTCIceConnectionState _iceConnectionState = RTCIceConnectionState.RTCIceConnectionStateNew;
  RTCPeerConnectionState _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateNew;
  String _connectionError = '';
  bool _waitingForAdmin = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _initRenderer();
    _generateViewerId();
    _getActiveSession();
  }

  Future<void> _getActiveSession() async {
    final sessionDoc = await FirebaseFirestore.instance
        .collection('session')
        .doc('current')
        .get();

    if (sessionDoc.exists && sessionDoc.data()?['active'] == true) {
      setState(() {
        _sessionId = sessionDoc.data()?['sessionId'];
      });

      if (_sessionId != null) {
        _signaling = FirebaseSignaling(
            sessionId: _sessionId!,
            peerId: _viewerId
        );
        _checkSessionAndJoin();
      }
    } else {
      setState(() {
        _connectionError = 'No active session found';
        _isLoading = false;
      });
    }
  }

  Future<void> _initRenderer() async => await _remoteRenderer.initialize();

  void _generateViewerId() {
    _viewerId = 'viewer_${_random.nextInt(100000)}';
  }

  Future<void> _checkSessionAndJoin() async {
    setState(() {
      _isLoading = true;
      _connectionError = '';
      _waitingForAdmin = false;
    });

    try {
      // First check if session exists
      final sessionExists = await _signaling.sessionExists();

      if (!sessionExists) {
        setState(() {
          _isLoading = false;
          _waitingForAdmin = true;
          _connectionError = 'Waiting for admin to create session...';
        });

        // Wait for session to be created
        final sessionCreated = await _signaling.waitForSession(timeoutSeconds: 30);

        if (!sessionCreated) {
          setState(() {
            _connectionError = 'Admin did not create session within timeout';
            _waitingForAdmin = false;
          });
          return;
        }
      }

      // Session exists, join it
      await _signaling.viewerJoined();
      _subscriptions['offer'] = _signaling.onOffer.listen(_handleOffer);
      setState(() {
        _isLoading = false;
        _waitingForAdmin = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _connectionError = 'Failed to join session: $e';
        _waitingForAdmin = false;
      });
    }
  }

  Future<void> _handleOffer(RTCSessionDescription offer) async {
    try {
      print('Received offer from admin');
      setState(() {
        _isLoading = true;
        _connectionError = '';
      });

      _peerConnection = await _createPeerConnection();

      // Set up the ontrack event handler BEFORE setting remote description
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('onTrack fired. Streams: ${event.streams.length}, Track: ${event.track.kind}');

        if (event.streams.isNotEmpty) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            _isConnected = true;
            _isLoading = false;
          });
        } else {
          createLocalMediaStream('remoteStream').then((MediaStream stream) {
            stream.addTrack(event.track);
            setState(() {
              _remoteRenderer.srcObject = stream;
              _isConnected = true;
              _isLoading = false;
            });
          });
        }
      };

      // Set remote description
      await _peerConnection!.setRemoteDescription(offer);

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer back
      await _signaling.sendAnswer(answer);
      print('Sent answer to admin');

      // ICE candidate handling - send ours
      _peerConnection!.onIceCandidate = (candidate) {
        print('Viewer sending ICE candidate: ${candidate.candidate}');
        _signaling.sendIceCandidate(
          'webrtc/sessions/${_sessionId}/viewers/$_viewerId/viewerIceCandidates',
          candidate,
        );
      };

      // ICE candidate handling - receive theirs
      _subscriptions['ice'] = _signaling.onIceCandidates(
        'webrtc/sessions/${_sessionId}/viewers/$_viewerId/adminIceCandidates',
      ).listen((candidate) {
        print('Viewer received ICE candidate: ${candidate.candidate}');
        _peerConnection?.addCandidate(candidate);
      });
    } catch (e) {
      print('Error handling offer: $e');
      setState(() {
        _isLoading = false;
        _connectionError = 'Failed to handle offer: $e';
      });
      Get.snackbar(
          "Connection Error",
          "Failed to connect: $e",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red
      );
    }
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
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

    pc.onConnectionState = (state) {
      print('Viewer connection state: $state');
      setState(() {
        _connectionState = state;
        _isConnected = state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      });
    };

    pc.onIceConnectionState = (state) {
      print('Viewer ICE connection state: $state');
      setState(() {
        _iceConnectionState = state;
      });

      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        setState(() => _isConnected = false);
      }
    };

    return pc;
  }

  Future<void> _reconnect() async {
    setState(() {
      _isConnected = false;
      _isLoading = true;
      _connectionError = '';
      _waitingForAdmin = false;
      _remoteRenderer.srcObject = null;
    });

    // Clean up old connection
    _peerConnection?.close();
    for (var sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();

    // Try to join again
    await _getActiveSession();
  }

  @override
  void dispose() {
    _peerConnection?.close();
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _signaling.cleanup();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Trading Session'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _reconnect,
          ),
        ],
      ),
      body: PageWrapper(
        child: Center(
          child: _isLoading
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Connecting to session...'),
              if (_waitingForAdmin) SizedBox(height: 10),
              if (_waitingForAdmin) Text('Waiting for admin to start session', style: TextStyle(fontSize: 12)),
            ],
          )
              : _isConnected
              ? RTCVideoView(_remoteRenderer)
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Not connected to trading session'),
              SizedBox(height: 10),
              Text('ICE State: $_iceConnectionState', style: TextStyle(fontSize: 12)),
              Text('Connection State: $_connectionState', style: TextStyle(fontSize: 12)),
              if (_connectionError.isNotEmpty)
                Text('Error: $_connectionError', style: TextStyle(fontSize: 12, color: Colors.red)),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _reconnect,
                child: Text('Reconnect'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}