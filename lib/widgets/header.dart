import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../route/app_routes.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      color: Colors.deepPurple,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("MySite", style: TextStyle(color: Colors.white, fontSize: 24)),
          Row(
            children: [
              _navItem("Home", AppRoutes.home),
              _navItem("About", "/about"),
              if (user == null)
                _navItem("Login", AppRoutes.login)
              else
                InkWell(
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Get.offAllNamed(AppRoutes.login);
                  },
                  hoverColor: Colors.white24,
                  mouseCursor: SystemMouseCursors.click,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("Logout", style: TextStyle(color: Colors.white)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navItem(String label, String route) {
    return InkWell(
      onTap: () => Get.toNamed(route),
      hoverColor: Colors.white24,
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
