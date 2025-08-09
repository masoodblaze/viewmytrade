import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminFunctionsController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> updateSubscription(String userId, DateTime endDate) async {
    print(userId);
    print(endDate);
    try {
      final user = _auth.currentUser;
      if (user == null) throw "Authentication required";

      //final adminDoc = await _firestore.collection('users').doc(user.uid).get();
      // if (!adminDoc.exists || adminDoc['role'] != 'admin') {
      //   throw "Admin privileges required";
      // }

      await _firestore.collection('users').doc(userId).update({
        'subscriptionEndDate': Timestamp.fromDate(endDate),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Show success message after update but before closing dialog
      Get.snackbar("Success", "Subscription updated successfully",
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2));

    } on FirebaseException catch (e) {
      String errorMessage = "Failed to update subscription: ${e.message}";
      if (e.code == 'permission-denied') {
        errorMessage = "Admin privileges required";
      }
      throw errorMessage; // Rethrow to be caught by the dialog
    } catch (e) {
      throw e.toString(); // Rethrow to be caught by the dialog
    }
  }

  Stream<QuerySnapshot> getUsersWithSubscriptions() {
    return _firestore.collection('users')
        .where('role', isNotEqualTo: 'admin') // Filter out other admins
        .snapshots();
  }

  int calculateRemainingDays(Timestamp? endDate) {
    if (endDate == null) return 0;
    final remaining = endDate.toDate().difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  // Helper method to check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.exists && doc['role'] == 'admin';
  }
}