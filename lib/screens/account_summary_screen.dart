import 'package:flutter/material.dart';
import '../services/sales_storage_service.dart';
import '../services/purchases_storage_service.dart';
import '../services/box_storage_service.dart';

class AccountSummaryScreen extends StatefulWidget {
  final String selectedDate;
  const AccountSummaryScreen({super.key, required this.selectedDate});

  @override
  State<AccountSummaryScreen> createState() => _AccountSummaryScreenState();
}

class _AccountSummaryScreenState extends State<AccountSummaryScreen> {
  final SalesStorageService _salesStorageService = SalesStorageService();
  final PurchasesStorageService _purchasesStorageService =
      PurchasesStorageService();
  final BoxStorageService _boxStorageService = BoxStorageService();

  double _salesTotal = 0; // مجموع الصدقات
  double _purchasesTotal = 0; // مجموع الهبات
  double _expensesTotal = 0; // مجموع المصروف
  double _boxBalance = 0; // رصيد الصندوق
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      double sales = 0;
      double purchases = 0;
      double expensesTotalPaid = 0, expensesTotalReceived = 0;

      final allBoxDates =
          await _boxStorageService.getAvailableDatesWithNumbers();

      for (var dateInfo in allBoxDates) {
        final doc =
            await _boxStorageService.loadBoxDocumentForDate(dateInfo['date']!);
        if (doc != null) {
          for (var trans in doc.transactions) {
            if (trans.accountType == 'مصروف') {
              expensesTotalPaid += double.tryParse(trans.paid) ?? 0;
              expensesTotalReceived += double.tryParse(trans.received) ?? 0;
            } else if (trans.accountType == 'فقير') {
              // صفوف الصندوق اليدوية للفقراء → مدفوع = صدقة
              sales += double.tryParse(trans.paid) ?? 0;
              sales -= double.tryParse(trans.received) ?? 0;
            } else if (trans.accountType == 'واهب') {
              // صفوف الصندوق اليدوية للواهبين → مقبوض = هبة
              purchases += double.tryParse(trans.received) ?? 0;
              purchases -= double.tryParse(trans.paid) ?? 0;
            }
          }
        }
      }

      final double expenses = expensesTotalPaid - expensesTotalReceived;

      // جلب الصدقات من شاشة الصدقات
      final salesAllDates = await _salesStorageService.getAllAvailableDates();
      for (var date in salesAllDates) {
        final doc = await _salesStorageService.loadDocumentForDate(date);
        if (doc != null) {
          sales += double.tryParse(doc.totals['totalPayments'] ?? '0') ?? 0;
        }
      }

      // جلب الهبات من شاشة الهبات
      final purchasesAllDates =
          await _purchasesStorageService.getAllAvailableDates();
      for (var date in purchasesAllDates) {
        final doc = await _purchasesStorageService.loadDocumentForDate(date);
        if (doc != null) {
          purchases += double.tryParse(doc.totals['totalPayments'] ?? '0') ?? 0;
        }
      }

      debugPrint('Sales: $sales, Purchases: $purchases, Expenses: $expenses');

      final double boxBalance = purchases - sales - expenses;

      debugPrint('Box Balance: $boxBalance');

      if (mounted) {
        setState(() {
          _salesTotal = sales;
          _purchasesTotal = purchases;
          _expensesTotal = expenses;
          _boxBalance = boxBalance;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفصيلات الحساب'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // رأس القسم
                    Container(
                      width: double.infinity,
                      color: Colors.indigo[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Text(
                        'حساب الصندوق',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // بطاقة المعلومات
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              'مجموع الهبات',
                              _purchasesTotal.toStringAsFixed(2),
                              Colors.green.shade700,
                              Icons.volunteer_activism,
                            ),
                            const Divider(height: 20),
                            _buildInfoRow(
                              'مجموع الصدقات',
                              _salesTotal.toStringAsFixed(2),
                              Colors.orange.shade700,
                              Icons.card_giftcard,
                            ),
                            const Divider(height: 20),
                            _buildInfoRow(
                              'المصروف',
                              _expensesTotal.toStringAsFixed(2),
                              Colors.red.shade700,
                              Icons.money_off,
                            ),
                            const Divider(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _boxBalance >= 0
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _boxBalance >= 0
                                      ? Colors.green.shade300
                                      : Colors.red.shade300,
                                  width: 2,
                                ),
                              ),
                              child: _buildInfoRow(
                                'رصيد الصندوق',
                                _boxBalance.toStringAsFixed(2),
                                _boxBalance >= 0
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                Icons.account_balance_wallet,
                                isBold: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // عرض المعادلة
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.grey.shade800,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
