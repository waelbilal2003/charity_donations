import 'package:flutter/material.dart';
import 'customer_preferences_screen.dart';
import 'supplier_preferences_screen.dart';
import '../services/customer_index_service.dart';
import '../services/supplier_index_service.dart';
import 'backup_info_screen.dart';
import 'opening_balances_screen.dart';
import 'account_summary_screen.dart';

class PreferencesScreen extends StatefulWidget {
  final String selectedDate;
  const PreferencesScreen({super.key, required this.selectedDate});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final CustomerIndexService _customerIndexService = CustomerIndexService();
  final SupplierIndexService _supplierIndexService = SupplierIndexService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التفصيلات'),
        backgroundColor: Colors.blueGrey[600],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountSummaryScreen(
                        selectedDate: widget.selectedDate,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: const Text('تفصيلات الحساب',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  final customers =
                      await _customerIndexService.getAllCustomersWithData();
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerPreferencesListScreen(
                        selectedDate: widget.selectedDate,
                        customers: customers,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: const Text('تفصيلات الفقراء',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  final suppliers =
                      await _supplierIndexService.getAllSuppliersWithData();
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupplierPreferencesListScreen(
                        selectedDate: widget.selectedDate,
                        suppliers: suppliers,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: const Text('تفصيلات الواهبين',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OpeningBalancesScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: const Text('أرصدة البداية',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BackupScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4C5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: const Text('النسخ الاحتياطي',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- قائمة اختيار الزبون ----
class CustomerPreferencesListScreen extends StatelessWidget {
  final String selectedDate;
  final Map<int, CustomerData> customers;

  const CustomerPreferencesListScreen(
      {super.key, required this.selectedDate, required this.customers});

  @override
  Widget build(BuildContext context) {
    final list = customers.values.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفضيلات الفقراء'),
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: list.isEmpty
            ? const Center(
                child: Text('لا يوجد فقراء مسجلين.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)))
            : Padding(
                padding: const EdgeInsets.all(12.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final customer = list[index];
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerPreferencesScreen(
                              customer: customer,
                              selectedDate: selectedDate,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: Text(
                        customer.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

// ---- قائمة اختيار المورد ----
class SupplierPreferencesListScreen extends StatelessWidget {
  final String selectedDate;
  final Map<int, SupplierData> suppliers;

  const SupplierPreferencesListScreen(
      {super.key, required this.selectedDate, required this.suppliers});

  @override
  Widget build(BuildContext context) {
    final list = suppliers.values.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفضيلات الواهبين'),
        backgroundColor: Colors.brown[600],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: list.isEmpty
            ? const Center(
                child: Text('لا يوجد واهبين مسجلين.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)))
            : Padding(
                padding: const EdgeInsets.all(12.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final supplier = list[index];
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupplierPreferencesScreen(
                              supplier: supplier,
                              selectedDate: selectedDate,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: Text(
                        supplier.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
