import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// خدمة الإعدادات العامة للتطبيق — تحل محل SharedPreferences بالكامل
/// تحفظ البيانات في: AppData/settings/app_settings.json
class AppSettingsService {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  static const String _fileName = 'app_settings.json';
  Map<String, dynamic> _settings = {};
  bool _isInitialized = false;

  Future<String> _getFilePath() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    final folderPath = '${directory!.path}/AppData/settings';
    final folder = Directory(folderPath);
    if (!await folder.exists()) await folder.create(recursive: true);
    return '$folderPath/$_fileName';
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _load();
      _isInitialized = true;
    }
  }

  Future<void> _load() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        if (jsonString.isNotEmpty) {
          _settings = jsonDecode(jsonString) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في تحميل إعدادات التطبيق: $e');
      _settings = {};
    }
  }

  Future<void> _save() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      await file.writeAsString(jsonEncode(_settings));
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في حفظ إعدادات التطبيق: $e');
    }
  }

  Future<String?> getString(String key) async {
    await _ensureInitialized();
    return _settings[key]?.toString();
  }

  Future<void> setString(String key, String value) async {
    await _ensureInitialized();
    _settings[key] = value;
    await _save();
  }

  /// إعادة تحميل الإعدادات من الملف (للتزامن بين الجلسات)
  Future<void> reload() async {
    _isInitialized = false;
    await _ensureInitialized();
  }
}
