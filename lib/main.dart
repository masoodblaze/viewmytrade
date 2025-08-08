import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:viewmytrade/core/app_routes.dart';
import 'package:viewmytrade/presentation/pages/admin_home_page.dart';
import 'package:viewmytrade/presentation/pages/home_page.dart';
import 'package:viewmytrade/presentation/pages/login_page.dart';
import 'package:viewmytrade/presentation/pages/subscription_management_page.dart';
import 'package:viewmytrade/presentation/pages/user_watch_page.dart';
import 'package:viewmytrade/presentation/widgets/authgate.dart';
import 'controllers/admin_functions_controller.dart';
import 'firebase_options.dart';
import 'presentation/pages/admin_screen_share_page.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // For web: removes the "#" in URLs
//  usePathUrlStrategy();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
 // Get.put(AdminFunctionsController());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      title: 'View our option trade',
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const AuthGate()), // Initial wrapper
        GetPage(name: AppRoutes.login, page: () => const LoginPage()),
        GetPage(name: AppRoutes.home, page: () => const HomePage()),
        GetPage(name: AppRoutes.adminHome, page: () => const AdminHomePage()),
        GetPage(name: AppRoutes.adminScreenShare, page: () => AdminScreenSharePage()),
        GetPage(name: AppRoutes.userWatch, page: () => UserWatchPage()),
        GetPage(name: AppRoutes.subscriptionManagement, page: () => SubscriptionManagementPage()),
      ],
    );
  }
}
