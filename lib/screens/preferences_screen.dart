import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import 'customer_preferences_screen.dart';
import 'supplier_preferences_screen.dart';
import '../services/customer_index_service.dart';
import '../services/supplier_index_service.dart';
import '../services/sales_storage_service.dart';
import '../services/purchases_storage_service.dart';
import '../services/box_storage_service.dart';
import 'backup_info_screen.dart';
import 'opening_balances_screen.dart';

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
                child: const Text('تفصيلات الزبائن',
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
                child: const Text('تفصيلات الموردين',
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
        title: const Text('تفضيلات الزبائن'),
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: list.isEmpty
            ? const Center(
                child: Text('لا يوجد زبائن مسجلين.',
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
        title: const Text('تفضيلات الموردين'),
        backgroundColor: Colors.brown[600],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: list.isEmpty
            ? const Center(
                child: Text('لا يوجد موردين مسجلين.',
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

// ---- شاشة تفصيلات الحساب ----
class AccountSummaryScreen extends StatefulWidget {
  final String selectedDate;
  const AccountSummaryScreen({super.key, required this.selectedDate});

  @override
  State<AccountSummaryScreen> createState() => _AccountSummaryScreenState();
}

class _AccountSummaryScreenState extends State<AccountSummaryScreen> {
  final CustomerIndexService _customerIndexService = CustomerIndexService();
  final SupplierIndexService _supplierIndexService = SupplierIndexService();
  final SalesStorageService _salesStorageService = SalesStorageService();
  final PurchasesStorageService _purchasesStorageService =
      PurchasesStorageService();
  final BoxStorageService _boxStorageService = BoxStorageService();

  double _salesTotal = 0;
  double _purchasesTotal = 0;
  double _boxReceived = 0;
  double _expensesTotal = 0;
  double _customersBalance = 0;
  double _suppliersBalance = 0;
  double _openingBoxBalance = 0; // رصيد الصندوق الابتدائي
  double _openingCapital = 0; // رأس المال الابتدائي
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // ── المجموع الكلي للمبيعات من جميع الأيام ──
      double sales = 0;
      double purchases = 0;
      double boxReceived = 0, boxPaid = 0;
      double expensesTotalPaid = 0, expensesTotalReceived = 0;

      // جلب بيانات الصندوق + المصروف
      final allBoxDates =
          await _boxStorageService.getAvailableDatesWithNumbers();
      for (var dateInfo in allBoxDates) {
        final doc =
            await _boxStorageService.loadBoxDocumentForDate(dateInfo['date']!);
        if (doc != null) {
          boxReceived +=
              double.tryParse(doc.totals['totalReceived'] ?? '0') ?? 0;
          boxPaid += double.tryParse(doc.totals['totalPaid'] ?? '0') ?? 0;
          for (var trans in doc.transactions) {
            if (trans.accountType == 'مصروف') {
              expensesTotalPaid += double.tryParse(trans.paid) ?? 0;
              expensesTotalReceived += double.tryParse(trans.received) ?? 0;
            }
          }
        }
      }
      // المصروف الكلي = مجموع المدفوع الكلي - مجموع المقبوض الكلي لجميع الأيام
      final double expenses = expensesTotalPaid - expensesTotalReceived;

      // جلب المبيعات الكلية عبر SalesStorageService
      final salesAllDates = await _salesStorageService.getAllAvailableDates();
      for (var date in salesAllDates) {
        final doc = await _salesStorageService.loadDocumentForDate(date);
        if (doc != null) {
          sales += double.tryParse(doc.totals['totalPayments'] ?? '0') ?? 0;
        }
      }

      // جلب المشتريات الكلية عبر PurchasesStorageService
      final purchasesAllDates =
          await _purchasesStorageService.getAllAvailableDates();
      for (var date in purchasesAllDates) {
        final doc = await _purchasesStorageService.loadDocumentForDate(date);
        if (doc != null) {
          purchases += double.tryParse(doc.totals['totalPayments'] ?? '0') ?? 0;
        }
      }

      final double boxBalance = boxReceived - boxPaid;

      // جلب أرصدة البداية من ملف الإعدادات
      final settings = AppSettingsService();
      final openingBox = double.tryParse(
              await settings.getString('opening_box_balance') ?? '0') ??
          0;
      final openingCap =
          double.tryParse(await settings.getString('opening_capital') ?? '0') ??
              0;

      final customers = await _customerIndexService.getAllCustomersWithData();
      final suppliers = await _supplierIndexService.getAllSuppliersWithData();
      final custBalance = customers.values.fold(0.0, (s, c) => s + c.balance);
      final suppBalance = suppliers.values.fold(0.0, (s, c) => s + c.balance);

      if (mounted) {
        setState(() {
          _salesTotal = sales;
          _purchasesTotal = purchases;
          _boxReceived = boxBalance;
          _expensesTotal = expenses;
          _customersBalance = custBalance;
          _suppliersBalance = suppBalance;
          _openingBoxBalance = openingBox;
          _openingCapital = openingCap;
          _isLoading = false;
        });
      }
    } catch (e) {
      // في حال أي خطأ (بما فيه بيئة الويب) أوقف التحميل
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── دالة مساعدة: خلية نصية وقيمة رقمية تحتها ──
  Widget _cell(String label, String value,
      {Color bgColor = Colors.white,
      Color textColor = Colors.black87,
      bool isBold = false,
      Color? valueColor}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── صف من خليتين ──
  Widget _twoColRow(Widget right, Widget left) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [right, left],
      ),
    );
  }

  // ── رأس القسم ──
  Widget _sectionHeader(String title, Color color) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  // ── رأس عمودي (يمين / يسار) ──
  /*
  Widget _colHeader(String title, Color color) {
    return Expanded(
      child: Container(
        color: color,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

 */

  // ── صف إجمالي ──
  Widget _totalRow(String rightLabel, String rightVal, String leftLabel,
      String leftVal, Color color) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell(rightLabel, rightVal,
              bgColor: color.withOpacity(0.15),
              textColor: color,
              isBold: true,
              valueColor: color),
          _cell(leftLabel, leftVal,
              bgColor: color.withOpacity(0.15),
              textColor: color,
              isBold: true,
              valueColor: color),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── المرحلة الأولى: حساب المتاجرة ──
    // المبيعات - المشتريات = x
    final double tradingX = _salesTotal - _purchasesTotal;
    final bool isTradingProfit = tradingX > 0;
    final bool isTradingEqual = tradingX == 0;

    // ── المرحلة الثانية: حساب الأرباح والخسائر ──
    // يمين: المصروف + (خسارة تجارية إن وجدت)
    // يسار: ربح تجاري إن وجد
    // صافي = يمين - يسار
    double plRight = _expensesTotal +
        (isTradingProfit || isTradingEqual ? 0 : tradingX.abs());
    double plLeft = isTradingProfit ? tradingX : 0;
    double netResult = plLeft - plRight; // موجب = ربح، سالب = خسارة
    final bool isNetProfit = netResult > 0;
    final bool isNetEqual = netResult == 0;

    // ── المرحلة الثالثة: الميزانية ──
    // رصيد الصندوق الفعلي = رصيد الصندوق الابتدائي + صافي حركة الصندوق
    final double totalBoxBalance = _openingBoxBalance + _boxReceived;
    // رأس المال الفعلي = رأس المال الابتدائي + رأس المال المحسوب
    // يمين (أصول): الزبائن + الصندوق + صافي خسارة إن وجدت
    // يسار (خصوم): الموردون + رأس المال + صافي ربح إن وجد
    // رأس المال = يمين الكلي - موردون - صافي ربح
    double balanceRight = _customersBalance +
        totalBoxBalance +
        (isNetProfit || isNetEqual ? 0 : netResult.abs());
    double capital = _openingCapital +
        (balanceRight -
            _suppliersBalance -
            (isNetProfit ? netResult : 0) -
            _openingCapital);
    // تبسيط: capital = balanceRight - suppliersBalance - netProfit
    capital = balanceRight - _suppliersBalance - (isNetProfit ? netResult : 0);
    double balanceLeft =
        _suppliersBalance + capital + (isNetProfit ? netResult : 0);

    final Color tradingColor = Colors.blueGrey.shade700;
    final Color plColor = Colors.purple.shade700;
    final Color balColor = const Color.fromARGB(255, 37, 18, 105);

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
                padding: const EdgeInsets.all(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ════════════════════════════════
                    // المرحلة الأولى: حساب المتاجرة
                    // ════════════════════════════════
                    _sectionHeader('حساب المتاجرة', tradingColor),

                    _twoColRow(
                      _cell('المشتريات', _purchasesTotal.toStringAsFixed(2)),
                      _cell('المبيعات', _salesTotal.toStringAsFixed(2)),
                    ),
                    // سطر الربح أو الخسارة التجارية
                    if (!isTradingEqual)
                      _twoColRow(
                        isTradingProfit
                            ? _cell('ربح المتاجرة', tradingX.toStringAsFixed(2),
                                bgColor: Colors.green.shade50,
                                textColor: Colors.green.shade800,
                                isBold: true,
                                valueColor: Colors.green.shade800)
                            : _cell('', ''),
                        isTradingProfit
                            ? _cell('', '')
                            : _cell('خسارة المتاجرة',
                                tradingX.abs().toStringAsFixed(2),
                                bgColor: Colors.red.shade50,
                                textColor: Colors.red.shade800,
                                isBold: true,
                                valueColor: Colors.red.shade800),
                      ),
                    // صف المجاميع - كلا الطرفين يجب أن يتساويا
                    _totalRow(
                      'المجموع',
                      // يمين: إذا ربح = مشتريات + ربح = مبيعات، إذا خسارة = مشتريات
                      isTradingProfit
                          ? _salesTotal.toStringAsFixed(2)
                          : _purchasesTotal.toStringAsFixed(2),
                      'المجموع',
                      // يسار: إذا ربح = مبيعات، إذا خسارة = مبيعات + خسارة = مشتريات
                      isTradingProfit
                          ? _salesTotal.toStringAsFixed(2)
                          : _purchasesTotal.toStringAsFixed(2),
                      tradingColor,
                    ),
                    const SizedBox(height: 7),

                    // ════════════════════════════════
                    // المرحلة الثانية: حساب الأرباح والخسائر
                    // ════════════════════════════════
                    _sectionHeader('حساب الأرباح والخسائر', plColor),

                    // المصروف دائماً في اليمين (مدين)
                    _twoColRow(
                      _cell('المصروف', _expensesTotal.toStringAsFixed(2)),
                      // الربح التجاري يُكتب في اليسار (دائن) إن وجد
                      isTradingProfit
                          ? _cell('الربح التجاري', tradingX.toStringAsFixed(2))
                          : _cell('', ''),
                    ),
                    // الخسارة التجارية تُكتب في اليمين (مدين) إن وجدت
                    if (!isTradingProfit && !isTradingEqual)
                      _twoColRow(
                        _cell('الخسارة التجارية',
                            tradingX.abs().toStringAsFixed(2)),
                        _cell('', ''),
                      ),
                    // صافي الربح في اليمين (مدين) / صافي الخسارة في اليسار (دائن)
                    if (!isNetEqual)
                      _twoColRow(
                        isNetProfit
                            ? _cell('صافي الربح', netResult.toStringAsFixed(2),
                                bgColor: Colors.green.shade50,
                                textColor: Colors.green.shade800,
                                isBold: true,
                                valueColor: Colors.green.shade800)
                            : _cell('', ''),
                        isNetProfit
                            ? _cell('', '')
                            : _cell('صافي الخسارة',
                                netResult.abs().toStringAsFixed(2),
                                bgColor: Colors.red.shade50,
                                textColor: Colors.red.shade800,
                                isBold: true,
                                valueColor: Colors.red.shade800),
                      ),
                    _totalRow(
                      'المجموع',
                      // يمين: مصروف + خسارة تجارية + صافي ربح (إن وجد) = ربح تجاري
                      (isNetProfit ? plLeft : plRight).toStringAsFixed(2),
                      'المجموع',
                      // يسار: ربح تجاري (إن وجد) أو مصروف + خسارة تجارية + صافي خسارة
                      (isNetProfit ? plLeft : plRight).toStringAsFixed(2),
                      plColor,
                    ),
                    const SizedBox(height: 7),

                    // ════════════════════════════════
                    // المرحلة الثالثة: الميزانية الختامية
                    // ════════════════════════════════
                    _sectionHeader('الميزانية الختامية', balColor),

                    // الزبائن (يمين) / الموردون (يسار)
                    _twoColRow(
                      _cell('الزبائن', _customersBalance.toStringAsFixed(2)),
                      _cell('الموردين', _suppliersBalance.toStringAsFixed(2)),
                    ),
                    // الصندوق (يمين) / رأس المال (يسار)
                    _twoColRow(
                      _cell('الصندوق', totalBoxBalance.toStringAsFixed(2)),
                      _cell('رأس المال', capital.toStringAsFixed(2)),
                    ),
                    // صافي الخسارة في اليمين إن وجدت / صافي الربح في اليسار إن وجد
                    if (!isNetEqual)
                      _twoColRow(
                        !isNetProfit
                            ? _cell('صافي الخسارة',
                                netResult.abs().toStringAsFixed(2),
                                bgColor: Colors.red.shade50,
                                textColor: Colors.red.shade800,
                                isBold: true,
                                valueColor: Colors.red.shade800)
                            : _cell('', ''),
                        isNetProfit
                            ? _cell('صافي الربح', netResult.toStringAsFixed(2),
                                bgColor: Colors.green.shade50,
                                textColor: Colors.green.shade800,
                                isBold: true,
                                valueColor: Colors.green.shade800)
                            : _cell('', ''),
                      ),
                    _totalRow(
                      'المجموع',
                      balanceRight.toStringAsFixed(2),
                      'المجموع',
                      balanceLeft.toStringAsFixed(2),
                      balColor,
                    ),
                    // الفرق إن وجد
                    if ((balanceRight - balanceLeft).abs() > 0.01)
                      Container(
                        color: Colors.orange.shade100,
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        child: Text(
                          'الفرق: ${(balanceRight - balanceLeft).toStringAsFixed(2)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
