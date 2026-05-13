import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_menu_screen.dart';

class DateSelectionScreen extends StatefulWidget {
  final String storeType;
  final String storeName;
  final String? sellerName;

  const DateSelectionScreen({
    super.key,
    required this.storeType,
    required this.storeName,
    this.sellerName,
  });

  @override
  State<DateSelectionScreen> createState() => _DateSelectionScreenState();
}

class _DateSelectionScreenState extends State<DateSelectionScreen> {
  DateTime _selectedDate = DateTime.now();

  void _updateDate({int? year, int? month, int? day}) {
    final currentYear = year ?? _selectedDate.year;
    final currentMonth = month ?? _selectedDate.month;
    var currentDay = day ?? _selectedDate.day;

    final daysInMonth = DateUtils.getDaysInMonth(currentYear, currentMonth);
    if (currentDay > daysInMonth) {
      currentDay = daysInMonth;
    }

    setState(() {
      _selectedDate = DateTime(currentYear, currentMonth, currentDay);
    });
  }

  Widget _buildCompactPicker(
    String label,
    int currentValue,
    VoidCallback onIncrement,
    VoidCallback onDecrement, {
    bool isMonth = false,
  }) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    String displayValue =
        isMonth ? months[currentValue - 1] : currentValue.toString();
    return Flexible(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label:',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                IconButton(
                    icon: const Icon(Icons.arrow_drop_up),
                    onPressed: onIncrement,
                    color: Colors.green[600],
                    iconSize: 24),
                SizedBox(
                    height: 30,
                    child: Center(
                        child: Text(displayValue,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)))),
                IconButton(
                    icon: const Icon(Icons.arrow_drop_down),
                    onPressed: onDecrement,
                    color: Colors.red[600],
                    iconSize: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اختيار التاريخ',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.teal[600],
          foregroundColor: Colors.white,
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                      '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54)),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCompactPicker(
                        'اليوم',
                        _selectedDate.day,
                        () => _updateDate(day: _selectedDate.day + 1),
                        () => _updateDate(day: _selectedDate.day - 1)),
                    _buildCompactPicker(
                        'الشهر',
                        _selectedDate.month,
                        () => _updateDate(month: _selectedDate.month + 1),
                        () => _updateDate(month: _selectedDate.month - 1),
                        isMonth: true),
                    _buildCompactPicker(
                        'السنة',
                        _selectedDate.year,
                        () => _updateDate(year: _selectedDate.year + 1),
                        () => _updateDate(year: _selectedDate.year - 1)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final formattedDate =
                          '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}';
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MainMenuScreen(
                            selectedDate: formattedDate,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 60, vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 24),
                    label: const Text('دخــول',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
