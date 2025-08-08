import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:viewmytrade/core/app_routes.dart';

class Header extends StatefulWidget {
  const Header({super.key});

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 700;

        return Container(
          color: const Color(0xFF0D1B2A),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          child: isMobile
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _logo(),
                  IconButton(
                    icon: Icon(
                      _menuOpen ? Icons.close : Icons.menu,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _menuOpen = !_menuOpen;
                      });
                    },
                  ),
                ],
              ),
              if (_menuOpen) ...[
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildNavItems(user),
                ),
              ]
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _logo(),
              Row(
                children: _buildNavItems(user),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _logo() {
    return const Text(
      "VMT",
      style: TextStyle(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  List<Widget> _buildNavItems(User? user) {
    return [
      _navItem("Home", AppRoutes.home),
      _navItem("About", "/about"),
      if (user != null) _navItem("Join as Viewer", AppRoutes.userWatch),
      if (user == null)
        _navItem("Login", AppRoutes.login)
      else
        InkWell(
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            Get.offAllNamed(AppRoutes.home);
          },
          hoverColor: Colors.white24,
          mouseCursor: SystemMouseCursors.click,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ),
    ];
  }

  Widget _navItem(String label, String route) {
    return InkWell(
      onTap: () {
        Get.toNamed(route);
        setState(() {
          _menuOpen = false; // close menu after navigation
        });
      },
      hoverColor: Colors.white24,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
