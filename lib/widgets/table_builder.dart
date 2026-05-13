import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// بناء خلية جدول مشتركة (النسخة المدمجة)
Widget buildTableCell({
  required TextEditingController controller,
  required FocusNode focusNode,
  required bool isSerialField,
  required bool isNumericField,
  required int rowIndex,
  required int colIndex,
  required Function(int, int) scrollToField,
  required Function(String, int, int) onFieldSubmitted,
  required Function(String, int, int) onFieldChanged,
  List<TextInputFormatter>? inputFormatters,
  bool isSField = false,
  double fontSize = 13,
  TextAlign textAlign = TextAlign.right,
  TextDirection textDirection = TextDirection.rtl,
  bool enabled = true, // <-- المنطق الجديد الذي يتحكم بالصلاحيات
}) {
  return Container(
    padding: const EdgeInsets.all(1),
    constraints: const BoxConstraints(minHeight: 25),
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      // *** الدمج الرئيسي هنا ***
      // الخاصية 'enabled' الآن تتحكم بشكل كامل في إمكانية التفاعل
      enabled: enabled,
      readOnly: isSerialField,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        border: InputBorder.none,
        // لا نحتاج لـ hintText الآن لأن حجم الحقل ثابت
      ),
      // *** تطبيق الألوان مع مراعاة حالة الحقل ***
      style: TextStyle(
        fontSize: fontSize,
        // إذا كان الحقل معطلاً، يظهر بلون رمادي. وإلا، يظهر باللون الأسود.
        color: enabled ? Colors.black : Colors.grey[700],
      ),
      // maxLines: 1, // TextField يتعامل مع هذا بشكل جيد افتراضياً
      keyboardType: isSField
          ? TextInputType.number
          : (isNumericField
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text),
      textInputAction: TextInputAction.next,
      textAlign: textAlign,
      textDirection: textDirection,
      inputFormatters: inputFormatters,
      onTap: () {
        // نسمح بالتمرير حتى لو كان الحقل للقراءة فقط (مثل حقل المسلسل)
        scrollToField(rowIndex, colIndex);
      },
      onSubmitted: (value) => onFieldSubmitted(value, rowIndex, colIndex),
      onChanged: (value) => onFieldChanged(value, rowIndex, colIndex),
    ),
  );
}

// بناء خلية نقدي أو دين مع وظيفة خاصة بالمبيعات
Widget buildCashOrDebtCell({
  required int rowIndex,
  required int colIndex,
  required String cashOrDebtValue,
  required String customerName,
  required TextEditingController customerController,
  required FocusNode focusNode,
  required bool hasUnsavedChanges,
  required ValueChanged<bool> setHasUnsavedChanges,
  required VoidCallback onTap,
  required Function(int, int) scrollToField,
  required ValueChanged<String> onCustomerNameChanged,
  required Function(String, int, int) onCustomerSubmitted,
  bool isSalesScreen = false,
  bool enabled = true, // <-- إضافة خاصية الصلاحيات هنا أيضاً
}) {
  // إذا كانت الخلية غير مفعلة، نعرض نصاً بسيطاً للقراءة فقط
  if (!enabled) {
    String displayText = cashOrDebtValue;
    if (isSalesScreen && cashOrDebtValue == 'دين' && customerName.isNotEmpty) {
      displayText = customerName;
    } else if (cashOrDebtValue.isEmpty) {
      displayText = '-';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      constraints: const BoxConstraints(minHeight: 25),
      alignment: Alignment.center,
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[700],
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // إذا كانت شاشة المبيعات والقيمة "دين" (والخلية مفعلة)
  if (isSalesScreen && cashOrDebtValue == 'دين') {
    return Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: customerController,
        focusNode: focusNode,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 0.5),
          ),
          hintText: 'اسم الزبون',
          hintStyle: TextStyle(fontSize: 9, color: Colors.grey),
        ),
        style: TextStyle(
          fontSize: 11,
          color: Colors.red[700],
          fontWeight: FontWeight.bold,
        ),
        maxLines: 2,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        textInputAction: TextInputAction.next,
        onTap: () {
          scrollToField(rowIndex, colIndex);
        },
        onChanged: (value) {
          onCustomerNameChanged(value);
          setHasUnsavedChanges(true);
        },
        onSubmitted: (value) => onCustomerSubmitted(value, rowIndex, colIndex),
      ),
    );
  }

  // بقية الحالات (نقدي، دين للمشتريات، فارغ) تستخدم InkWell
  // لأنها تفتح نافذة منبثقة ولا تتطلب إدخال نص مباشر
  return Container(
    padding: const EdgeInsets.all(1),
    constraints: const BoxConstraints(minHeight: 25),
    child: InkWell(
      onTap: () {
        onTap();
        scrollToField(rowIndex, colIndex);
      },
      child: _buildCashOrDebtDisplay(cashOrDebtValue, isSalesScreen),
    ),
  );
}

// دالة مساعدة لتقليل التكرار في بناء واجهة خلية نقدي/دين
Widget _buildCashOrDebtDisplay(String cashOrDebtValue, bool isSalesScreen) {
  switch (cashOrDebtValue) {
    case 'دين':
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red, width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: const Center(
          child: Text('دين',
              style: TextStyle(
                  fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
        ),
      );
    case 'نقدي':
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Center(
          child: Text('نقدي',
              style: TextStyle(
                  fontSize: isSalesScreen ? 9 : 11,
                  color: Colors.green,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
        ),
      );
    default: // فارغ
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Text('اختر',
                  style: TextStyle(
                      fontSize: isSalesScreen ? 9 : 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.arrow_drop_down,
                size: isSalesScreen ? 12 : 16, color: Colors.grey[600]),
          ],
        ),
      );
  }
}
