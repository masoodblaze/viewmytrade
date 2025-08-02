// app_route.dart
import '../presentation/pages/admin_home_page.dart';
import 'package:get/get.dart';

import '../presentation/pages/subscription_management_page.dart';

class AppRoutes {
  static const String home = '/home';
  static const String login = '/login';
  static const String adminHome = '/admin';
  static const String subscriptionManagement = '/admin/subscriptions';

  static final routes = [
    GetPage(name: adminHome, page: () => const AdminHomePage()),
    GetPage(
      name: subscriptionManagement,
      page: () => SubscriptionManagementPage(),
    ),
  ];
}