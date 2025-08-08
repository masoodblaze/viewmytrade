import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomePageController extends GetxController {
  final emailCtrl = TextEditingController();
  final isLoading = false.obs;

  Future<void> subscribe() async {
    if (emailCtrl.text.trim().isEmpty) {
      Get.snackbar("Error", "Please enter a valid email",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      return;
    }

    isLoading.value = true;

    try {
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'email': emailCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      emailCtrl.clear();

      Get.back(); // Close dialog
      Get.snackbar("Success", "You have been subscribed!",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", "Failed to subscribe: $e",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }

    isLoading.value = false;
  }
}
