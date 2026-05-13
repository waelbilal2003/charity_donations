import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/payment_model.dart'; // تم التعديل: استيراد النموذج الجديد
import 'package:flutter/foundation.dart';

class PaymentStorageService {
  Future<String> _getBasePath() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    return directory!.path;
  }

  // تم التعديل: اسم المجلد والملف
  String _createFileName(String date) {
    final formattedDate = date.replaceAll('/', '-');
    return 'payments-$formattedDate.json';
  }

  Future<bool> savePaymentDocument(PaymentDocument document) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/PaymentJournals';
      final folder = Directory(folderPath);
      if (!await folder.exists()) await folder.create(recursive: true);

      final fileName = _createFileName(document.date);
      final filePath = '$folderPath/$fileName';
      final file = File(filePath);
      final jsonString = jsonEncode(document.toJson());
      await file.writeAsString(jsonString);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في حفظ يومية الدفعات: $e');
      return false;
    }
  }

  Future<PaymentDocument?> loadPaymentDocumentForDate(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/PaymentJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return PaymentDocument.fromJson(jsonMap);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في قراءة يومية الدفعات: $e');
      return null;
    }
  }
}
