import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'dart:math';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(WebRTCScreenSharingApp());
}

// ---------------------
// Firebase Signaling (Improved)
// ---------------------
class FirebaseSignaling {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final String sessionId;
  final String peerId;
  final bool isAdmin;

  FirebaseSignaling({
    required this.sessionId,
    required this.peerId,
    this.isAdmin = false
  });

  // Clean up session data when done
  Future<void> cleanup() async {
    if (isAdmin) {
      // Admin cleans up the entire session
      await _db.child('webrtc/sessions/$sessionId').remove();
    } else {
      // Viewer cleans up only their data
      await _db.child('webrtc/sessions/$sessionId/viewers/$peerId').remove();
    }
  }

  // Admin: create session
  Future<void> createSession() async {
    await _db.child('webrtc/sessions/$sessionId').set({
      'createdAt': ServerValue.timestamp,
      'adminId': peerId,
    });
  }

  // Admin: listen for new viewers
  Stream<String> get onViewerJoined {
    return _db.child('webrtc/sessions/$sessionId/viewers')
        .onChildAdded
        .map((event) => event.snapshot.key!);
  }

  // Admin: send offer
  Future<void> sendOfferToViewer(String viewerId, RTCSessionDescription offer) async {
    await _db.child('webrtc/sessions/$sessionId/viewers/$viewerId/offer')
        .set({'sdp': offer.sdp, 'type': offer.type});
  }

  // Viewer: listen for offer
  Stream<RTCSessionDescription> get onOffer {
    return _db.child('webrtc/sessions/$sessionId/viewers/$peerId/offer')
        .onValue
        .where((event) => event.snapshot.value != null)
        .map((event) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return RTCSessionDescription(data['sdp'], data['type']);
    });
  }

  // Viewer: send answer
  Future<void> sendAnswer(RTCSessionDescription answer) async {
    await _db.child('webrtc/sessions/$sessionId/viewers/$peerId/answer')
        .set({'sdp': answer.sdp, 'type': answer.type});
  }

  // Admin: listen for answer from specific viewer
  Stream<RTCSessionDescription> onAnswer(String viewerId) {
    return _db.child('webrtc/sessions/$sessionId/viewers/$viewerId/answer')
        .onValue
        .where((event) => event.snapshot.value != null)
        .map((event) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return RTCSessionDescription(data['sdp'], data['type']);
    });
  }

  // Send ICE candidate
  Future<void> sendIceCandidate(String targetPath, RTCIceCandidate candidate) async {
    await _db.child(targetPath).push().set({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex
    });
  }

  // Listen for ICE candidates
  Stream<RTCIceCandidate> onIceCandidates(String sourcePath) {
    return _db.child(sourcePath).onChildAdded.map((event) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex']
      );
    });
  }

  // Notify that viewer joined (creates a node in DB)
  Future<void> viewerJoined() async {
    await _db.child('webrtc/sessions/$sessionId/viewers/$peerId').set({
      'joined': true,
      'timestamp': ServerValue.timestamp
    });
  }

  // Check if session exists
  Future<bool> sessionExists() async {
    final snapshot = await _db.child('webrtc/sessions/$sessionId').get();
    return snapshot.exists && snapshot.value != null;
  }

  // Wait for session to be created with timeout
  Future<bool> waitForSession({int timeoutSeconds = 30}) async {
    final completer = Completer<bool>();
    final timer = Timer(Duration(seconds: timeoutSeconds), () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    final subscription = _db.child('webrtc/sessions/$sessionId')
        .onValue
        .where((event) => event.snapshot.exists)
        .listen((event) {
      if (!completer.isCompleted) {
        timer.cancel();
        completer.complete(true);
      }
    });

    final exists = await completer.future;
    await subscription.cancel();
    return exists;
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
// Home Screen (Improved)
// ---------------------
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sessionIdController = TextEditingController();
  final _random = Random();

  @override
  void initState() {
    super.initState();
    // Generate a random session ID
    _sessionIdController.text = 'session_${_random.nextInt(9000) + 1000}';
  }

  @override
  void dispose() {
    _sessionIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebRTC Screen Sharing'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _sessionIdController,
              decoration: InputDecoration(
                labelText: 'Session ID',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) =>
                      AdminScreen(sessionId: _sessionIdController.text)),
                );
              },
              child: Text('Start as Admin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) =>
                      ViewerScreen(sessionId: _sessionIdController.text)),
                );
              },
              child: Text('Join as Viewer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------
// Admin Screen (Improved)
// ---------------------
class AdminScreen extends StatefulWidget {
  final String sessionId;

  AdminScreen({required this.sessionId});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _isSharing = false;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  final List<String> _viewerIds = [];

  late FirebaseSignaling _signaling;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _signaling = FirebaseSignaling(
        sessionId: widget.sessionId,
        peerId: 'admin_${_random.nextInt(10000)}',
        isAdmin: true
    );

    // Create the session first
    _signaling.createSession().then((_) {
      // Then listen for new viewers
      _subscriptions['viewers'] = _signaling.onViewerJoined.listen(_handleViewerJoined);
    });
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

      _localStream!.getVideoTracks().first.onEnded = () {
        _stopScreenSharing();
      };
    } catch (e) {
      print('Error starting screen sharing: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start screen sharing: $e'))
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
        'webrtc/sessions/${widget.sessionId}/viewers/$viewerId/adminIceCandidates',
        candidate,
      );
    };

    // ICE candidate handling - receive theirs
    _subscriptions['ice_$viewerId'] = _signaling.onIceCandidates(
      'webrtc/sessions/${widget.sessionId}/viewers/$viewerId/viewerIceCandidates',
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

    print('Creating peer connection with config: $config');

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

    pc.onIceGatheringState = (state) {
      print('Admin -> Viewer($viewerId) ICE gathering state: $state');
    };

    pc.onSignalingState = (state) {
      print('Admin -> Viewer($viewerId) signaling state: $state');
    };

    pc.onIceCandidate = (candidate) {
      print('Admin -> Viewer($viewerId) ICE candidate: ${candidate.candidate}');
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
        title: Text('Admin - ${widget.sessionId}'),
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
    );
  }
}

// ---------------------
// Viewer Screen (Improved)
// ---------------------
class ViewerScreen extends StatefulWidget {
  final String sessionId;

  ViewerScreen({required this.sessionId});

  @override
  _ViewerScreenState createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
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

  @override
  void initState() {
    super.initState();
    _initRenderer();
    _generateViewerId();
    _signaling = FirebaseSignaling(
        sessionId: widget.sessionId,
        peerId: _viewerId
    );
    _checkSessionAndJoin();
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
          'webrtc/sessions/${widget.sessionId}/viewers/$_viewerId/viewerIceCandidates',
          candidate,
        );
      };

      // ICE candidate handling - receive theirs
      _subscriptions['ice'] = _signaling.onIceCandidates(
        'webrtc/sessions/${widget.sessionId}/viewers/$_viewerId/adminIceCandidates',
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e'))
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

    print('Creating peer connection with config: $config');

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

    pc.onIceGatheringState = (state) {
      print('Viewer ICE gathering state: $state');
    };

    pc.onSignalingState = (state) {
      print('Viewer signaling state: $state');
    };

    pc.onIceCandidate = (candidate) {
      print('Viewer ICE candidate: ${candidate.candidate}');
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
    await _checkSessionAndJoin();
  }

  void _showConnectionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connection Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Viewer ID: $_viewerId', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Session: ${widget.sessionId}'),
            SizedBox(height: 10),
            Text('ICE State: $_iceConnectionState'),
            Text('Connection State: $_connectionState'),
            Text('Connected: $_isConnected'),
            if (_connectionError.isNotEmpty) ...[
              SizedBox(height: 10),
              Text('Error: $_connectionError', style: TextStyle(color: Colors.red)),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
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
        title: Text('Viewer - ${widget.sessionId}'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _reconnect,
          ),
          IconButton(
            icon: Icon(Icons.info),
            onPressed: _showConnectionInfo,
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Connecting...'),
            if (_waitingForAdmin) SizedBox(height: 10),
            if (_waitingForAdmin) Text('Waiting for admin to start session', style: TextStyle(fontSize: 12)),
          ],
        )
            : _isConnected
            ? RTCVideoView(_remoteRenderer)
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Not connected to admin stream'),
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
    );
  }
}