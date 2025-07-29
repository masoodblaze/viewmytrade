// widgets/page_wrapper.dart
import 'package:flutter/material.dart';
import 'header.dart';
import 'footer.dart';

class PageWrapper extends StatelessWidget {
  final Widget child;
  const PageWrapper({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Header(),
        Expanded(child: child),
        const Footer(),
      ],
    );
  }
}
