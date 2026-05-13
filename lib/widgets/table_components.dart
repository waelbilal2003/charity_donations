// widgets/table_components.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// كلاس فلترة الأرقام العشرية الموجبة
class PositiveDecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // التحقق من أن النص يحتوي فقط على أرقام ونقطة عشرية
    final regex = RegExp(r'^[0-9]*\.?[0-9]*$');
    if (!regex.hasMatch(newValue.text)) {
      return oldValue;
    }

    // التحقق من وجود نقطة عشرية واحدة فقط
    final decimalCount = '.'.allMatches(newValue.text).length;
    if (decimalCount > 1) {
      return oldValue;
    }

    // منع الأرقام السالبة
    if (newValue.text.contains('-')) {
      return oldValue;
    }

    return newValue;
  }
}

// كلاس فلترة رقمين بدون فاصلة عشرية
class TwoDigitInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // التحقق من أن النص يحتوي فقط على أرقام
    final regex = RegExp(r'^[0-9]*$');
    if (!regex.hasMatch(newValue.text)) {
      return oldValue;
    }

    // منع الأرقام السالبة
    if (newValue.text.contains('-')) {
      return oldValue;
    }

    // منع أكثر من خانتين (رقمين)
    if (newValue.text.length > 2) {
      return oldValue;
    }

    return newValue;
  }
}

// كلاس لتثبيت رأس الجدول
class StickyTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  StickyTableHeaderDelegate({required this.child, this.height = 32.0});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(StickyTableHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

// خلية رأس الجدول
Widget buildTableHeaderCell(String text) {
  return Container(
    padding: const EdgeInsets.all(2),
    constraints: const BoxConstraints(minHeight: 30),
    child: Center(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
      ),
    ),
  );
}

// خلية المجموع
Widget buildTotalCell(TextEditingController controller) {
  return Container(
    padding: const EdgeInsets.all(1),
    constraints: const BoxConstraints(minHeight: 25),
    decoration: BoxDecoration(
      color: Colors.yellow[100],
    ),
    child: TextField(
      controller: controller,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        border: InputBorder.none,
        hintStyle: TextStyle(fontSize: 13),
      ),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.red[700],
      ),
      maxLines: 1,
      keyboardType: TextInputType.number,
      enabled: false,
      readOnly: true,
    ),
  );
}

// خلية الإجمالي غير القابلة للتعديل
Widget buildTotalValueCell(TextEditingController controller) {
  return Container(
    padding: const EdgeInsets.all(1),
    constraints: const BoxConstraints(minHeight: 25),
    child: TextField(
      controller: controller,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        border: InputBorder.none,
        hintText: '0.00',
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
      ),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
      maxLines: 1,
      keyboardType: TextInputType.number,
      enabled: false,
      readOnly: true,
    ),
  );
}

// خلية الفوارغ
Widget buildEmptiesCell({
  required String value,
  required VoidCallback onTap,
  required int rowIndex,
  required int colIndex,
  required Function(int, int) scrollToField,
}) {
  return Container(
    padding: const EdgeInsets.all(1),
    constraints: const BoxConstraints(minHeight: 25),
    child: InkWell(
      onTap: () {
        onTap();
        scrollToField(rowIndex, colIndex);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? 'اختر' : value,
                style: TextStyle(
                  fontSize: 11,
                  color: value.isEmpty ? Colors.grey : Colors.black,
                  fontWeight:
                      value.isEmpty ? FontWeight.normal : FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    ),
  );
}
