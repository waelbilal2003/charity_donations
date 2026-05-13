import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import 'customer_management_screen.dart';
import 'supplier_management_screen.dart';
import 'preferences_screen.dart';
import 'sales_screen.dart';
import 'purchases_screen.dart';
import 'box_screen.dart';

class MainMenuScreen extends StatefulWidget {
  final String selectedDate;

  const MainMenuScreen({super.key, required this.selectedDate});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  String _sellerName = '';
  String _storeName = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final settings = AppSettingsService();
    setState(() {
      _sellerName = '';
      _storeName = '';
    });
    final seller = await settings.getString('seller_name');
    final store = await settings.getString('store_name');
    setState(() {
      _sellerName = seller ?? '';
      _storeName = store ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 247, 247, 248),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _storeName.isNotEmpty ? _storeName : 'القائمة الرئيسية',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              widget.selectedDate,
              style: TextStyle(
                fontSize: 12,
                color: Colors.teal[100],
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F4C5C),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F4C5C), Color(0xFF1A7A8A)],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal.withOpacity(0),
                  Colors.tealAccent.withOpacity(0.6),
                  Colors.teal.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              children: [
                if (_sellerName.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.tealAccent.withOpacity(0.2), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline,
                            size: 16, color: Colors.teal[300]),
                        const SizedBox(width: 8),
                        Text(
                          'مرحباً، $_sellerName',
                          style: TextStyle(
                            color: Colors.teal[200],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Row(
                    children: [
                      // ✅ العمود الأيمن (من الأعلى للأسفل: الزبائن، المبيعات، التفصيلات)
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: _buildMenuButton(
                                context: context,
                                text: 'الزبائن',
                                icon: Icons.person_add_alt_1,
                                gradientColors: const [
                                  Color(0xFF0D9488),
                                  Color(0xFF0F766E)
                                ],
                                accentColor: Colors.tealAccent,
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              CustomerManagementScreen(
                                                  selectedDate:
                                                      widget.selectedDate)));
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: _buildMenuButton(
                                context: context,
                                text: 'المبيعات',
                                icon: Icons.sell_rounded,
                                gradientColors: const [
                                  Color(0xFF15803D),
                                  Color(0xFF166534)
                                ],
                                accentColor: Colors.greenAccent,
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => SalesScreen(
                                              selectedDate:
                                                  widget.selectedDate)));
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: _buildMenuButton(
                                context: context,
                                text: 'التفصيلات',
                                icon: Icons.tune_rounded,
                                gradientColors: const [
                                  Color(0xFF475569),
                                  Color(0xFF334155)
                                ],
                                accentColor: Colors.blueGrey[200]!,
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => PreferencesScreen(
                                              selectedDate:
                                                  widget.selectedDate)));
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // ✅ العمود الأيسر (من الأعلى للأسفل: الموردين، المشتريات، الصندوق)
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: _buildMenuButton(
                                context: context,
                                text: 'الموردين',
                                icon: Icons.local_shipping_rounded,
                                gradientColors: const [
                                  Color(0xFF92400E),
                                  Color(0xFF78350F)
                                ],
                                accentColor: Colors.orange[200]!,
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              SupplierManagementScreen(
                                                  selectedDate:
                                                      widget.selectedDate)));
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: _buildMenuButton(
                                context: context,
                                text: 'المشتريات',
                                icon: Icons.shopping_cart_rounded,
                                gradientColors: const [
                                  Color(0xFF1D4ED8),
                                  Color(0xFF1E40AF)
                                ],
                                accentColor: Colors.lightBlueAccent,
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => PurchasesScreen(
                                              selectedDate:
                                                  widget.selectedDate)));
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: _buildMenuButton(
                                context: context,
                                text: 'الصندوق',
                                icon: Icons.account_balance_wallet_rounded,
                                gradientColors: const [
                                  Color.fromARGB(255, 220, 145, 5),
                                  Color.fromARGB(255, 196, 129, 6)
                                ],
                                accentColor: Colors.amberAccent,
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => BoxScreen(
                                              selectedDate: widget.selectedDate,
                                              sellerName: _sellerName,
                                              storeName: _storeName)));
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required String text,
    required IconData icon,
    required List<Color> gradientColors,
    required Color accentColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          splashColor: accentColor.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accentColor.withOpacity(0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  left: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 32, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 24,
                        height: 2,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
