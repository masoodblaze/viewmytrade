import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserSessionViewPage extends StatelessWidget {
  const UserSessionViewPage({super.key});

  Stream<DocumentSnapshot<Map<String, dynamic>>> getSessionStream() {
    return FirebaseFirestore.instance.collection('session').doc('current').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Session View'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: getSessionStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data()!['active'] == false) {
            return const Center(child: Text('No live session available right now.'));
          }

          final sessionData = snapshot.data!.data()!;
          final screenUrl = sessionData['screenUrl'];

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Live Screen from Admin:"),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(screenUrl, fit: BoxFit.contain),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
