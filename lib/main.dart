import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:viewmytrade/core/app_routes.dart';
import 'package:viewmytrade/presentation/pages/aboutus_page.dart';
import 'package:viewmytrade/presentation/pages/admin_home_page.dart';
import 'package:viewmytrade/presentation/pages/home_page.dart';
import 'package:viewmytrade/presentation/pages/login_page.dart';
import 'package:viewmytrade/presentation/pages/subscription_management_page.dart';
import 'package:viewmytrade/presentation/pages/terms_page.dart';
import 'package:viewmytrade/presentation/pages/user_watch_page.dart';
import 'package:viewmytrade/presentation/pages/viewer_screen_share_page.dart';
import 'package:viewmytrade/presentation/widgets/authgate.dart';
import 'controllers/admin_functions_controller.dart';
import 'firebase_options.dart';
import 'presentation/pages/admin_screen_share_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';




void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      title: 'View our option trade',
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const AuthGate()), // Initial wrapper
        GetPage(name: AppRoutes.login, page: () => const LoginPage()),
        GetPage(name: AppRoutes.home, page: () => const HomePage()),
        GetPage(name: AppRoutes.aboutus, page: () => const AboutUsPage()),
        GetPage(name: AppRoutes.adminHome, page: () => const AdminHomePage()),
        GetPage(name: AppRoutes.adminScreenShare, page: () => AdminScreenSharePage()),
        GetPage(name: AppRoutes.userWatch, page: () => UserWatchPage()),
        GetPage(name: AppRoutes.subscriptionManagement, page: () => SubscriptionManagementPage()),
        GetPage(name: AppRoutes.termsAndConditions, page: () => TermsAndConditionsPage()),
        GetPage(name: AppRoutes.tradingview, page: () => ViewerScreenSharePage()),

      ],
    );
  }
}
