import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/page_wrapper.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageWrapper(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 🔹 Hero Banner
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
                          "Terms & Conditions",
                          style: GoogleFonts.poppins(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 60,
                          height: 4,
                          color: const Color(0xFFEAB308),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "Please read these terms carefully before using our services.",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 🔹 Terms Section
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                child: Column(
                  children: [
                    Text(
                      "User Agreement",
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(width: 50, height: 3, color: const Color(0xFFEAB308)),
                    const SizedBox(height: 30),

                    // Grid / List of Terms
                    LayoutBuilder(
                      builder: (context, constraints) {
                        bool isMobile = constraints.maxWidth < 900;
                        return Wrap(
                          spacing: 30,
                          runSpacing: 30,
                          alignment: WrapAlignment.center,
                          children: const [
                            _TermsCard(
                              number: "1",
                              title: "Nature of Service",
                              description:
                              "ViewMyTrade provides subscription-based access to live trading screen-sharing sessions. "
                                  "Our service is for educational purposes only and does not guarantee financial gain.",
                            ),
                            _TermsCard(
                              number: "2",
                              title: "No Financial Advice",
                              description:
                              "All content shared by traders is for informational and learning purposes only. "
                                  "We are not licensed financial advisors, and users remain solely responsible for their trading decisions.",
                            ),
                            _TermsCard(
                              number: "3",
                              title: "Risk Acknowledgment",
                              description:
                              "Trading in financial markets involves significant risk. You may lose part or all of your investment. "
                                  "By using our service, you acknowledge that you accept these risks.",
                            ),
                            _TermsCard(
                              number: "4",
                              title: "Subscription Policy",
                              description:
                              "Subscriptions are non-transferable and non-refundable once activated. "
                                  "Access is limited to the registered account holder only.",
                            ),
                            _TermsCard(
                              number: "5",
                              title: "Confidentiality",
                              description:
                              "Screen-sharing sessions, strategies, or proprietary content must not be recorded, redistributed, or resold "
                                  "without prior written consent from ViewMyTrade.",
                            ),
                            _TermsCard(
                              number: "6",
                              title: "Code of Conduct",
                              description:
                              "Users are expected to behave respectfully during live sessions. "
                                  "Any abusive, disruptive, or fraudulent behavior may lead to suspension without refund.",
                            ),
                            _TermsCard(
                              number: "7",
                              title: "Compliance with Laws",
                              description:
                              "Users must comply with all applicable laws and trading regulations in their jurisdiction. "
                                  "We do not take responsibility for violations of local laws.",
                            ),
                            _TermsCard(
                              number: "8",
                              title: "Limitation of Liability",
                              description:
                              "ViewMyTrade, its traders, and affiliates are not liable for any losses or damages "
                                  "resulting from the use of our services.",
                            ),
                            _TermsCard(
                              number: "9",
                              title: "Termination of Service",
                              description:
                              "We reserve the right to suspend or terminate your access if you violate these terms or misuse the platform.",
                            ),
                            _TermsCard(
                              number: "10",
                              title: "Amendments",
                              description:
                              "These terms may be updated from time to time. Users will be notified of major changes, "
                                  "and continued use of the service constitutes acceptance.",
                            ),
                          ],
                        );
                      },
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

class _TermsCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _TermsCard({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEAB308),
            child: Text(
              number,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0D1B2A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}
