import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:viewmytrade/presentation/pages/admin_screen_share_page.dart';
import 'package:viewmytrade/widgets/page_wrapper.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  String selectedRole = 'user';
  bool creating = false;
  String errorMsg = '';
  bool sessionActive = false;

  @override
  void initState() {
    super.initState();
    // Listen for session status
    FirebaseFirestore.instance.collection('session')
        .doc('current')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          sessionActive = snapshot.exists && snapshot.data()?['active'] == true;
        });
      }
    });
  }

  Future<void> createUser() async {
    setState(() {
      creating = true;
      errorMsg = '';
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({'email': emailCtrl.text.trim(), 'role': selectedRole});

      emailCtrl.clear();
      passCtrl.clear();
      selectedRole = 'user';
      Get.snackbar("Success", "User created successfully",
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      setState(() {
        errorMsg = 'Error creating user: ${e.toString()}';
      });
    }

    setState(() {
      creating = false;
    });
  }

  Future<void> startSession() async {
    try {
      // Navigate to the screen sharing page - it will handle session creation
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminScreenSharePage()),
      );
    } catch (e) {
      Get.snackbar("Error", "Failed to start session: ${e.toString()}",
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red);
    }
  }

  Future<void> stopSession() async {
    try {
      await FirebaseFirestore.instance.collection('session').doc('current').set({
        'active': false,
        'endedAt': DateTime.now(),
      });
      Get.snackbar("Session Stopped", "Screen sharing has been stopped.",
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar("Error", "Failed to stop session: ${e.toString()}",
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red);
    }
  }

  Stream<QuerySnapshot> getUsersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  Stream<QuerySnapshot> getSubscriptionsStream() {
    return FirebaseFirestore.instance.collection('subscriptions').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Get.offAllNamed('/');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: PageWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive layout: if width < 900, stack vertically
              bool isWide = constraints.maxWidth > 900;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First Column - Session Management and User Creation
                  Expanded(
                    flex: isWide ? 3 : 0,
                    child: Column(
                      children: [
                        // Session Management Card
                        _buildCard(
                          title: "Session Management",
                          child: Column(
                            children: [
                              // Session status indicator
                              Row(
                                children: [
                                  Icon(
                                    sessionActive ? Icons.videocam : Icons.videocam_off,
                                    color: sessionActive ? Colors.green : Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    sessionActive ? 'Session Active' : 'No Active Session',
                                    style: TextStyle(
                                      color: sessionActive ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),

                              // Start/Stop session button
                              ElevatedButton(
                                onPressed: sessionActive ? stopSession : startSession,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: sessionActive ? Colors.red : Colors.green,
                                  minimumSize: Size(double.infinity, 50),
                                ),
                                child: Text(sessionActive ? "Stop Session" : "Start Screen Sharing"),
                              ),
                              SizedBox(height: 12),

                              // Manage Subscription button
                              ElevatedButton(
                                onPressed: () => Get.toNamed('/admin/subscriptions'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  minimumSize: Size(double.infinity, 50),
                                ),
                                child: const Text("Manage Subscription"),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isWide ? 0 : 16), // Vertical spacing only in mobile view

                        // User Creation Card
                        _buildCard(
                          title: "Create New User",
                          child: Column(
                            children: [
                              TextField(
                                controller: emailCtrl,
                                decoration: const InputDecoration(labelText: "Email"),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: passCtrl,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: "Password"),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<String>(
                                value: selectedRole,
                                items: const [
                                  DropdownMenuItem(value: 'user', child: Text('User')),
                                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    selectedRole = val!;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              if (errorMsg.isNotEmpty)
                                Text(errorMsg, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: creating ? null : createUser,
                                child: creating
                                    ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                    : const Text("Create User"),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isWide) const SizedBox(width: 16) else const SizedBox(height: 16),

                  // Second Column - Registered Users
                  Expanded(
                    flex: 4,
                    child: _buildCard(
                      title: "Registered Users",
                      child: StreamBuilder<QuerySnapshot>(
                        stream: getUsersStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Text("No users found.");
                          }

                          return Scrollbar(
                            thumbVisibility: true,
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: snapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                final doc = snapshot.data!.docs[index];
                                return ListTile(
                                  leading: const Icon(Icons.person),
                                  title: Text(doc['email']),
                                  subtitle: Text('Role: ${doc['role']}'),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  if (isWide) const SizedBox(width: 16) else const SizedBox(height: 16),

                  // Third Column - Subscribed Users
                  Expanded(
                    flex: 4,
                    child: _buildCard(
                      title: "Subscribed Users",
                      child: StreamBuilder<QuerySnapshot>(
                        stream: getSubscriptionsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Text("No subscriptions found.");
                          }

                          return Scrollbar(
                            thumbVisibility: true,
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: snapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                final doc = snapshot.data!.docs[index];
                                final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();
                                final formattedDate = createdAt != null
                                    ? DateFormat.yMMMd().add_jm().format(createdAt)
                                    : "Unknown date";

                                return ListTile(
                                  leading: const Icon(Icons.email),
                                  title: Text(doc['email'] ?? 'No Email'),
                                  subtitle: Text("Subscribed: $formattedDate"),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 400, // increased height to accommodate session controls
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}