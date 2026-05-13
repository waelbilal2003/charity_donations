import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';

class OpeningBalancesScreen extends StatefulWidget {
  const OpeningBalancesScreen({super.key});

  @override
  State<OpeningBalancesScreen> createState() => _OpeningBalancesScreenState();
}

class _OpeningBalancesScreenState extends State<OpeningBalancesScreen> {
  static const String _keyBoxBalance = 'opening_box_balance';
  static const String _keyCapital = 'opening_capital';

  final TextEditingController _boxBalanceController = TextEditingController();
  final TextEditingController _capitalController = TextEditingController();

  bool _isSaved = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  @override
  void dispose() {
    _boxBalanceController.dispose();
    _capitalController.dispose();
    super.dispose();
  }

  Future<void> _loadBalances() async {
    final settings = AppSettingsService();
    final boxVal = await settings.getString(_keyBoxBalance);
    final capVal = await settings.getString(_keyCapital);
    setState(() {
      _isSaved = boxVal != null || capVal != null;
      _boxBalanceController.text = boxVal ?? '';
      _capitalController.text = capVal ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveBalances() async {
    final boxText = _boxBalanceController.text.trim();
    final capText = _capitalController.text.trim();

    final boxVal = double.tryParse(boxText);
    final capVal = double.tryParse(capText);

    if (boxVal == null || capVal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال أرقام صحيحة في الحقلين'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final settings = AppSettingsService();
    await settings.setString(_keyBoxBalance, boxText);
    await settings.setString(_keyCapital, capText);

    setState(() => _isSaved = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ أرصدة البداية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أرصدة البداية'),
        backgroundColor: Colors.deepOrange[700],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── أيقونة وعنوان ──
                    Icon(Icons.account_balance_wallet,
                        size: 64, color: Colors.deepOrange[700]),
                    const SizedBox(height: 12),
                    Text(
                      'أرصدة البداية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange[800]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSaved
                          ? 'تم حفظ الأرصدة مسبقاً — يمكنك تعديلها وإعادة الحفظ'
                          : 'أدخل أرصدة البداية مرة واحدة — ستبقى ثابتة',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 40),

                    // ── حقل رصيد الصندوق ──
                    Text(
                      'رصيد الصندوق الابتدائي',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange[800]),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _boxBalanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.inbox),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.deepOrange[700]!, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.deepOrange[50],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── حقل رأس المال ──
                    Text(
                      'رأس المال الابتدائي',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange[800]),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _capitalController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.account_balance),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.deepOrange[700]!, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.deepOrange[50],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── زر الحفظ ──
                    ElevatedButton.icon(
                      onPressed: _saveBalances,
                      icon: const Icon(Icons.save, size: 24),
                      label: Text(
                        _isSaved ? 'تحديث الأرصدة' : 'حفظ الأرصدة',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 5,
                      ),
                    ),

                    // ── مؤشر الحفظ ──
                    if (_isSaved) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'الأرصدة محفوظة وتؤثر على الميزانية الختامية',
                              style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
