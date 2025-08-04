import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viewmytrade/presentation/pages/admin_screen_share_page.dart';
import 'package:viewmytrade/presentation/pages/user_watch_page.dart';
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
        errorMsg = 'Error creating user: \${e.toString()}';
      });
    }

    setState(() {
      creating = false;
    });
  }

  Future<void> startSession() async {
    try {
      await FirebaseFirestore.instance.collection('session').doc('current').set({
        'active': true,
        'startedAt': Timestamp.now(),
      });
      Get.snackbar("Session Started", "Users can now view the shared screen.",
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar("Error", "Failed to start session: \${e.toString()}",
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red);
    }
  }

  Stream<QuerySnapshot> getUsersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Create User Form
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text("Create New User",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: "Email"),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passCtrl,
                          obscureText: true,
                          decoration:
                          const InputDecoration(labelText: "Password"),
                        ),
                        const SizedBox(height: 8),
                        DropdownButton<String>(
                          value: selectedRole,
                          items: const [
                            DropdownMenuItem(
                                value: 'user', child: Text('User')),
                            DropdownMenuItem(
                                value: 'admin', child: Text('Admin')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              selectedRole = val!;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (errorMsg.isNotEmpty)
                          Text(errorMsg,
                              style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: creating ? null : createUser,
                          child: creating
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Text("Create"),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: (){
                            startSession();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AdminScreenSharePage()),
                            );
                            },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text("Start Session"),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => UserWatchPage()),
                            );
                          },
                          child: Text("Join as Viewer"),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => Get.toNamed('/admin/subscriptions'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text("Manage Subscription"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // User List
              Expanded(
                flex: 3,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text("Registered Users",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: getUsersStream(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return const Text("No users found.");
                              }

                              return ListView.builder(
                                itemCount: snapshot.data!.docs.length,
                                itemBuilder: (context, index) {
                                  final doc = snapshot.data!.docs[index];
                                  final email = doc['email'];
                                  final role = doc['role'];

                                  return ListTile(
                                    leading: const Icon(Icons.person),
                                    title: Text(email),
                                    subtitle: Text('Role: \$role'),
                                  );
                                },
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
