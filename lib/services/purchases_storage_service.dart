import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/payment_model.dart';
import 'package:flutter/foundation.dart';

class PurchasesStorageService {
  Future<String> _getBasePath() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    return directory!.path;
  }

  String _createFileName(String date) {
    final formattedDate = date.replaceAll('/', '-');
    return 'purchases-$formattedDate.json';
  }

  Future<bool> saveDocument(PaymentDocument document) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/PurchasesJournals';
      final folder = Directory(folderPath);
      if (!await folder.exists()) await folder.create(recursive: true);

      final fileName = _createFileName(document.date);
      final filePath = '$folderPath/$fileName';
      final file = File(filePath);
      final jsonString = jsonEncode(document.toJson());
      await file.writeAsString(jsonString);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في حفظ يومية المشتريات: $e');
      return false;
    }
  }

  Future<PaymentDocument?> loadDocumentForDate(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/PurchasesJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      final file = File(filePath);
      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return PaymentDocument.fromJson(jsonMap);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في قراءة يومية المشتريات: $e');
      return null;
    }
  }

  Future<List<String>> getAllAvailableDates() async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/PurchasesJournals';
      final folder = Directory(folderPath);
      if (!await folder.exists()) return [];
      final files = await folder.list().toList();
      final dates = <String>[];
      for (var f in files) {
        if (f is File && f.path.endsWith('.json')) {
          try {
            final j =
                jsonDecode(await f.readAsString()) as Map<String, dynamic>;
            final date = j['date']?.toString() ?? '';
            if (date.isNotEmpty) dates.add(date);
          } catch (_) {}
        }
      }
      return dates;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في جلب تواريخ المشتريات: $e');
      return [];
    }
  }
}
