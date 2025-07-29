import 'package:flutter/material.dart';
import '../screens/admin_home_page.dart';
import '../screens/home_page.dart';
import '../screens/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 🔸 If still checking auth state, show loader
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 🔸 User not logged in → show HomePage publicly
        if (!snapshot.hasData) {
          return const HomePage();
        }

        // 🔸 User logged in → check role from Firestore
        final user = snapshot.data!;
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // Invalid user doc — logout and show HomePage
              FirebaseAuth.instance.signOut();
              return const HomePage();
            }

            final role = userSnapshot.data!.get('role');
            if (role == 'admin') {
              return const AdminHomePage();
            } else {
              return const HomePage();
            }
          },
        );
      },
    );
  }
}
