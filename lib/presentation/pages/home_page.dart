import 'package:flutter/material.dart';
import 'package:viewmytrade/widgets/page_wrapper.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/homepage_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomePageController());
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageWrapper(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 🔹 Hero Section
              Stack(
                children: [
                  Container(
                    height: 500,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('images/trading.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    height: 500,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 40,
                    bottom: 70,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Experience Live Trading Like Never Before",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 15),
                        Text(
                          "Watch real-time trading sessions from experts.\nLearn strategies. Grow your confidence.",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),

              // 🔹 About Us
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "About ViewMyTrade",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "We believe that trading should be transparent, educational, and community-driven. "
                          "ViewMyTrade bridges the gap between seasoned traders and learners by allowing you to watch real-time trading screens, "
                          "interact during live sessions, and gain practical exposure to market strategies.\n\n"
                          "Whether you're just starting out or you're a passive investor looking to understand market behavior, "
                          "our platform gives you a front-row seat to the decision-making process of successful traders.",
                      style: TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),

              // 🔹 Features Section
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xfff4f4f4), Color(0xfffafafa)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
                child: Column(
                  children: [
                    const Text(
                      "Why Join ViewMyTrade?",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 50),
                    Wrap(
                      spacing: 30,
                      runSpacing: 30,
                      children: const [
                        _FeatureCard(
                          title: "Live Session Viewing",
                          description:
                          "Join live trading sessions from anywhere. No need to install heavy apps.",
                          icon: Icons.tv_rounded,
                        ),
                        _FeatureCard(
                          title: "Secure & Private",
                          description:
                          "We protect your access and data using end-to-end Firebase authentication.",
                          icon: Icons.lock_outline_rounded,
                        ),
                        _FeatureCard(
                          title: "Device Friendly",
                          description:
                          "Watch from mobile, tablet, or desktop. Designed for all screen sizes.",
                          icon: Icons.devices_rounded,
                        ),
                        _FeatureCard(
                          title: "No Hidden Costs",
                          description:
                          "Straightforward access. Transparent pricing. No ads or distractions.",
                          icon: Icons.attach_money_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 🔹 CTA Section
              Container(
                padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Text(
                      "Start Watching Today",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Get access to top traders' live sessions. No commitments, just learning.",
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                      ),
                      onPressed: () {
                        Get.dialog(
                          Center(
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                width: 400,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Subscribe",
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0D1B2A),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: controller.emailCtrl,
                                      decoration: const InputDecoration(
                                        labelText: "Enter your email",
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Obx(() => ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0D1B2A),
                                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: controller.isLoading.value ? null : controller.subscribe,
                                      child: controller.isLoading.value
                                          ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                          : Text(
                                        "Submit",
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        "Join Now",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 50, color: Colors.deepPurple),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
