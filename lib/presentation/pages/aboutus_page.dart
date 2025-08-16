import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/page_wrapper.dart';
import '../controllers/homepage_controller.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

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
                    height: 400,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('images/aboutbanner.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    height: 400,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 40,
                    bottom: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "About ViewMyTrade",
                          style: GoogleFonts.poppins(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 60,
                          height: 4,
                          color: const Color(0xFFEAB308), // accent line
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "Empowering traders through live learning and real-time insights.",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),

              // 🔹 Our Story Section
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                child: LayoutBuilder(builder: (context, constraints) {
                  bool isMobile = constraints.maxWidth < 800;
                  return Flex(
                    direction: isMobile ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'images/aboutbanner1.jpg',
                            height: 300,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(width: isMobile ? 0 : 30, height: isMobile ? 30 : 0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Our Story",
                              style: GoogleFonts.poppins(
                                  fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 50,
                              height: 3,
                              color: const Color(0xFFEAB308),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "ViewMyTrade started with a simple idea — to make professional trading more transparent "
                                  "and accessible to everyone. We bring expert traders and learners together on one platform, "
                                  "allowing real-time interaction and skill building through live trading sessions.",
                              style: const TextStyle(fontSize: 16, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),

              // 🔹 Mission & Vision
        Container(
          color: const Color(0xfff9f9f9),
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 900;

              return Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Card
                  Flexible(
                    flex: isMobile ? 0 : 1, // No forced expansion on mobile
                    child: _MissionVisionCard(
                      icon: Icons.flag,
                      title: "Our Mission",
                      description:
                      "To democratize trading education by connecting learners directly with experienced traders, "
                          "fostering practical knowledge and confidence.",
                    ),
                  ),

                  SizedBox(width: isMobile ? 0 : 30, height: isMobile ? 30 : 0),

                  // Join Us CTA - styled as a rounded card
                  Flexible(
                    flex: isMobile ? 0 : 1,
                    child: Container(
                      margin: isMobile
                          ? const EdgeInsets.symmetric(vertical: 20)
                          : EdgeInsets.zero,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
                      child: Column(
                        children: [
                          Text(
                            "Join Us on This Journey",
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "Be part of a growing community where knowledge flows freely and trading skills thrive.",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 25),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0D1B2A),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 0 : 40,
                                vertical: 18,
                              ),
                              minimumSize: isMobile
                                  ? const Size(double.infinity, 50) // full-width on mobile
                                  : const Size(0, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
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
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 40, vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: controller.isLoading.value
                                                ? null
                                                : controller.subscribe,
                                            child: controller.isLoading.value
                                                ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2, color: Colors.white),
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
                            child: Text(
                              "Get Started",
                              style: GoogleFonts.poppins(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )

                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: isMobile ? 0 : 30, height: isMobile ? 30 : 0),

                  // Right Card
                  Flexible(
                    flex: isMobile ? 0 : 1,
                    child: _MissionVisionCard(
                      icon: Icons.visibility,
                      title: "Our Vision",
                      description:
                      "To become the go-to platform for aspiring traders worldwide, "
                          "providing an authentic, interactive, and community-driven learning experience.",
                    ),
                  ),
                ],
              );
            },
          ),
        )


        ],
          ),
        ),
      ),
    );
  }
}

class _MissionVisionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _MissionVisionCard(
      {required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 36, color: const Color(0xFF0D1B2A)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }
}
