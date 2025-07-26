import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Header(),

            // 🔻 Banner section (inline)
            Container(
              height: 400,
              width: double.infinity,
              color: Colors.deepPurple.shade100,
              alignment: Alignment.center,
              child: const Text(
                "Welcome to MySite!",
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
            ),

            // 🔻 About us section (inline)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.centerLeft,
              width: double.infinity,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("About Us",
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text(
                    "We are building a Flutter Web app for screen sharing, voice, and more.",
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),

            // 🔻 You can add more sections here...

            const Footer(),
          ],
        ),
      ),
    );
  }
}
