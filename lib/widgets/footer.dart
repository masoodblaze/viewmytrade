import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/app_routes.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      color: Colors.grey.shade200,
      child: Center(
        child: Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "© 2025 ViewMyOptionsTrade. All rights reserved.",
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isMobile) const SizedBox(width: 12),
            if (!isMobile)
              Container(
                height: 16,
                width: 1,
                color: Colors.grey.shade400,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
            InkWell(
              onTap: () {
                Get.toNamed(AppRoutes.termsAndConditions);
              },
              borderRadius: BorderRadius.circular(4), // ripple shape
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  "Terms & Conditions",
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
