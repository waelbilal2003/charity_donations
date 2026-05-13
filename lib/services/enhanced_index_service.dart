import 'package:flutter/foundation.dart';

// 1. إضافة تعريف واجهة EnhancedIndexService هنا في أعلى الملف
abstract class EnhancedIndexService {
  Future<List<String>> getEnhancedSuggestions(String query);
  // يمكنك إضافة دالات أخرى مشتركة إذا احتجت
}

// 2. التأكد أن جميع الخدمات تطبق هذه الواجهة
// (سوف تحتاج لتعديل كل خدمة لتطبيق هذه الواجهة)

// دالة مساعدة واحدة للبحث المتقدم في جميع أنواع الفهارس
Future<List<String>> getEnhancedSuggestions(
    dynamic indexService, String query) async {
  if (query.isEmpty) return [];

  final normalizedQuery = query.trim();

  // محاولة البحث كرقم أولاً
  if (RegExp(r'^\d+$').hasMatch(normalizedQuery)) {
    try {
      // التحقق إذا كان indexService يطبق EnhancedIndexService
      if (indexService is EnhancedIndexService) {
        return await indexService.getEnhancedSuggestions(normalizedQuery);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في البحث الرقمي المتقدم: $e');
      }
    }
  }

  // البحث كنص باستخدام الدالة الأصلية
  return await indexService.getSuggestions(normalizedQuery);
}
