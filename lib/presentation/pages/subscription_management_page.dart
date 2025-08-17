import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:viewmytrade/controllers/admin_functions_controller.dart';
import 'package:viewmytrade/widgets/page_wrapper.dart';

class SubscriptionManagementPage extends StatelessWidget {
  SubscriptionManagementPage({super.key});
  final AdminFunctionsController _controller =
  Get.put(AdminFunctionsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Subscriptions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: PageWrapper(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'User Subscriptions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _controller.getUsersWithSubscriptions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No users found'));
                    }

                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor:
                                MaterialStateProperty.all(Colors.grey[200]),
                                columns: const [
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Role')),
                                  DataColumn(label: Text('Remaining Days')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: snapshot.data!.docs.map((doc) {
                                  final data =
                                  doc.data() as Map<String, dynamic>;
                                  final email = data['email'] ?? '';
                                  final role = data['role'] ?? 'user';
                                  final endDate =
                                  data.containsKey('subscriptionEndDate')
                                      ? data['subscriptionEndDate']
                                  as Timestamp?
                                      : null;
                                  final remainingDays = _controller
                                      .calculateRemainingDays(endDate);

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(email)),
                                      DataCell(Text(role)),
                                      DataCell(Text(remainingDays > 0
                                          ? "$remainingDays days"
                                          : 'No subscription')),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blueAccent),
                                          onPressed: () =>
                                              _showAddSubscriptionDialog(
                                                  context, doc.id, endDate),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSubscriptionDialog(
      BuildContext context, String userId, Timestamp? currentEndDate) {
    DateTime selectedDate =
        currentEndDate?.toDate() ?? DateTime.now().add(const Duration(days: 30));
    final controller = Get.find<AdminFunctionsController>();
    var isLoading = false.obs;

    showDialog(
      context: context,
      builder: (context) {
        return Obx(() => AlertDialog(
          title: const Text('Update Subscription'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select new subscription end date:'),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 300,
                    child: CalendarDatePicker(
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365 * 2)),
                      onDateChanged: (date) => selectedDate = date,
                    ),
                  ),
                  if (isLoading.value)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading.value ? null : () => Get.back(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading.value
                  ? null
                  : () async {
                isLoading.value = true;
                try {
                  await controller.updateSubscription(
                      userId, selectedDate);
                } catch (e) {
                  isLoading.value = false;
                } finally {
                  isLoading.value = false;
                  Get.back(); // Close dialog
                }
              },
              child: const Text('Save'),
            ),
          ],
        ));
      },
    );
  }
}
