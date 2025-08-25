import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(WebRTCScreenSharingApp());
}

// ---------------------
// Firebase Signaling
// ---------------------
class FirebaseSignaling {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final String sessionId;
  final String viewerId;

  FirebaseSignaling({required this.sessionId, required this.viewerId});

  // Admin: listen for new viewers
  void listenForViewers(Function(String viewerId) onViewerJoined) {
    _db.child('webrtc/sessions/$sessionId/viewers')
        .onChildAdded
        .listen((event) {
      onViewerJoined(event.snapshot.key!);
    });
  }

  // Admin: send offer
  Future<void> sendOfferToViewer(String viewerId, RTCSessionDescription offer) async {
    await _db.child('webrtc/sessions/$sessionId/viewers/$viewerId/offer')
        .set({'sdp': offer.sdp, 'type': offer.type});
  }

  // Viewer: listen for offer
  void listenForOffer(Function(RTCSessionDescription offer) onOffer) {
    _db.child('webrtc/sessions/$sessionId/viewers/$viewerId/offer')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final offer = RTCSessionDescription(data['sdp'], data['type']);
        onOffer(offer);
      }
    });
  }

  // Viewer: send answer
  Future<void> sendAnswer(RTCSessionDescription answer) async {
    await _db.child('webrtc/sessions/$sessionId/viewers/$viewerId/answer')
        .set({'sdp': answer.sdp, 'type': answer.type});
  }

  // Admin: listen for answer
  void listenForAnswer(String viewerId, Function(RTCSessionDescription answer) onAnswer) {
    _db.child('webrtc/sessions/$sessionId/viewers/$viewerId/answer')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final answer = RTCSessionDescription(data['sdp'], data['type']);
        onAnswer(answer);
      }
    });
  }

  // Send ICE candidate
  Future<void> sendIceCandidate(String path, RTCIceCandidate candidate) async {
    await _db.child(path).push().set({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex
    });
  }

  // Listen for ICE candidates
  void listenForIceCandidates(String path, Function(RTCIceCandidate candidate) onCandidate) {
    _db.child(path).onChildAdded.listen((event) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex']
      );
      onCandidate(candidate);
    });
  }

  // Notify that viewer joined (creates a node in DB)
  Future<void> viewerJoined() async {
    await _db.child('webrtc/sessions/$sessionId/viewers/$viewerId').set({'joined': true});
  }
}

// ---------------------
// Main App
// ---------------------
class WebRTCScreenSharingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebRTC Screen Sharing',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ---------------------
// Home Screen
// ---------------------
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebRTC Screen Sharing'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminScreen()),
                );
              },
              child: Text('Start as Admin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ViewerScreen()),
                );
              },
              child: Text('Join as Viewer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------
// Admin Screen
// ---------------------
class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _isSharing = false;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final List<String> _viewerIds = [];
  final String sessionId = 'mySession';

  late FirebaseSignaling _signaling;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _signaling = FirebaseSignaling(sessionId: sessionId, viewerId: '');
    _signaling.listenForViewers(_handleViewerJoined);
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
  }

  Future<void> _startScreenSharing() async {
    try {
      final stream = await navigator.mediaDevices.getDisplayMedia({
        'video': {'width': 1280, 'height': 720, 'frameRate': 30},
        'audio': true,
      });

      setState(() {
        _localStream = stream;
        _localRenderer.srcObject = _localStream;
        _isSharing = true;
      });

      _localStream!.getVideoTracks().first.onEnded = () {
        _stopScreenSharing();
      };
    } catch (e) {
      print('Error starting screen sharing: $e');
    }
  }

  Future<void> _stopScreenSharing() async {
    for (var pc in _peerConnections.values) {
      await pc.close();
    }

    _localStream?.getTracks().forEach((track) => track.stop());

    setState(() {
      _isSharing = false;
      _localStream = null;
      _localRenderer.srcObject = null;
      _peerConnections.clear();
      _viewerIds.clear();
    });
  }

  Future<void> _handleViewerJoined(String viewerId) async {
    if (!_isSharing) return;
    if (_viewerIds.contains(viewerId)) return;

    print('Viewer joined: $viewerId');
    setState(() => _viewerIds.add(viewerId));

    final pc = await _createPeerConnection(viewerId);
    _peerConnections[viewerId] = pc;
    if (_localStream == null) {
      print('No local stream to send!');
      return;
    }
    // Add tracks to the peer connection
    _localStream!.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    // Create and send offer
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _signaling.sendOfferToViewer(viewerId, offer);

    // Listen for answer
    _signaling.listenForAnswer(viewerId, (answer) async {
      print('Received answer from $viewerId');
      await pc.setRemoteDescription(answer);
    });

    // ICE candidate handling
    pc.onIceCandidate = (candidate) {
      print('Admin sending ICE candidate for $viewerId: ${candidate.candidate}');
      _signaling.sendIceCandidate(
        'webrtc/sessions/$sessionId/viewers/$viewerId/adminIceCandidates',
        candidate,
      );
    };

    _signaling.listenForIceCandidates(
      'webrtc/sessions/$sessionId/viewers/$viewerId/viewerIceCandidates',
          (candidate) {
        print('Admin received ICE candidate from $viewerId: ${candidate.candidate}');
        pc.addCandidate(candidate);
      },
    );
  }

  Future<RTCPeerConnection> _createPeerConnection(String viewerId) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {'urls': 'stun:stun3.l.google.com:19302'},
        {'urls': 'stun:stun4.l.google.com:19302'},
      ]
    };

    final sdpConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };

    final pc = await createPeerConnection(config, sdpConstraints);

    // Add connection state logging
    pc.onConnectionState = (state) {
      print('Admin -> Viewer($viewerId) connection: $state');
    };

    pc.onIceConnectionState = (state) {
      print('Admin -> Viewer($viewerId) ICE state: $state');
    };

    pc.onSignalingState = (state) {
      print('Admin -> Viewer($viewerId) Signaling state: $state');
    };

    pc.onIceGatheringState = (state) {
      print('Admin -> Viewer($viewerId) ICE gathering: $state');
    };

    return pc;
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
        title: Text('Admin Screen Sharing'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(_isSharing ? Icons.stop : Icons.screen_share),
            onPressed: _isSharing ? _stopScreenSharing : _startScreenSharing,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: _isSharing
                ? RTCVideoView(_localRenderer, mirror: false)
                : Center(child: Text('Press share to start')),
          ),
          Divider(),
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
    );
  }
}

// ---------------------
// Viewer Screen (Fixed)
// ---------------------
class ViewerScreen extends StatefulWidget {
  @override
  _ViewerScreenState createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;
  bool _isConnected = false;
  late String _viewerId;
  final String sessionId = 'mySession';
  late FirebaseSignaling _signaling;

  @override
  void initState() {
    super.initState();
    _initRenderer();
    _generateViewerId();
    _signaling = FirebaseSignaling(sessionId: sessionId, viewerId: _viewerId);
    _signaling.viewerJoined();
    _signaling.listenForOffer(_handleOffer);
  }

  Future<void> _initRenderer() async => await _remoteRenderer.initialize();

  void _generateViewerId() {
    final random = Random();
    _viewerId = 'viewer_${random.nextInt(100000)}'; // increased randomness
  }

  Future<void> _handleOffer(RTCSessionDescription offer) async {
    try {
      print('Received offer from admin');
      _peerConnection = await _createPeerConnection();

      // Set remote description
      await _peerConnection!.setRemoteDescription(offer);

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer back
      await _signaling.sendAnswer(answer);
      print('Sent answer to admin');

      // FIXED: onTrack handling
      _peerConnection!.onTrack = (event) {
        print('onTrack fired. Event streams length: ${event.streams.length}');
        print('onTrack triggered: ${event.track.kind}');
        if (event.track.kind == 'video') {
          // Use the first stream if available
          if (event.streams.isNotEmpty) {
            setState(() {
              _remoteStream = event.streams[0];
              _remoteRenderer.srcObject = _remoteStream;
              _isConnected = true;
            });
          } else {
            // On web, create a new local MediaStream and add track
            createLocalMediaStream('remoteStream').then((stream) {
              stream.addTrack(event.track);
              setState(() {
                _remoteStream = stream;
                _remoteRenderer.srcObject = _remoteStream;
                _isConnected = true;
              });
            });
          }
        }
      };

      // ICE candidate handling
      _peerConnection!.onIceCandidate = (candidate) {
        print('Viewer sending ICE candidate: ${candidate.candidate}');
        _signaling.sendIceCandidate(
          'webrtc/sessions/$sessionId/viewers/$_viewerId/viewerIceCandidates',
          candidate,
        );
      };

      _signaling.listenForIceCandidates(
        'webrtc/sessions/$sessionId/viewers/$_viewerId/adminIceCandidates',
            (candidate) {
          print('Viewer received ICE candidate: ${candidate.candidate}');
          _peerConnection?.addCandidate(candidate);
        },
      );
    } catch (e) {
      print('Error handling offer: $e');
    }
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {'urls': 'stun:stun3.l.google.com:19302'},
        {'urls': 'stun:stun4.l.google.com:19302'},
      ]
    };

    final sdpConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };

    final pc = await createPeerConnection(config, sdpConstraints);

    pc.onConnectionState = (state) {
      print('Viewer connection state: $state');
      setState(() => _isConnected = state == RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    };

    pc.onIceConnectionState = (state) {
      print('Viewer ICE connection state: $state');
    };

    pc.onSignalingState = (state) {
      print('Viewer signaling state: $state');
    };

    pc.onIceGatheringState = (state) {
      print('Viewer ICE gathering state: $state');
    };

    return pc;
  }

  @override
  void dispose() {
    _peerConnection?.close();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Viewer - $_viewerId'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: _isConnected
            ? RTCVideoView(_remoteRenderer)
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Waiting for admin stream...'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _signaling.viewerJoined(),
              child: Text('Reconnect'),
            ),
          ],
        ),
      ),
    );
  }
}
