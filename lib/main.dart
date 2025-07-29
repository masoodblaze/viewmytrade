import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:viewmytrade/widgets/authgate.dart';

import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/admin_home_page.dart';
import 'route/app_routes.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // For web: removes the "#" in URLs
//  usePathUrlStrategy();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'View our option trade',
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const AuthGate()), // Initial wrapper
        GetPage(name: AppRoutes.login, page: () => const LoginPage()),
        GetPage(name: AppRoutes.home, page: () => const HomePage()),
        GetPage(name: AppRoutes.adminHome, page: () => const AdminHomePage()),
      ],
    );
  }
}
