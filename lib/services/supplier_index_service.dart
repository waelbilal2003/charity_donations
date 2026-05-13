import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class SupplierData {
  String name;
  double balance;
  String mobile;
  String startDate;

  SupplierData({
    required this.name,
    this.balance = 0.0,
    this.mobile = '',
    required this.startDate,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'balance': balance,
        'mobile': mobile,
        'startDate': startDate,
      };

  factory SupplierData.fromJson(dynamic json) {
    final now = DateTime.now();
    final defaultDate = '${now.year}/${now.month}/${now.day}';

    if (json is String) {
      return SupplierData(name: json, startDate: defaultDate);
    }
    return SupplierData(
      name: json['name'] ?? '',
      balance: (json['balance'] ?? 0.0).toDouble(),
      mobile: json['mobile'] ?? '',
      startDate: json['startDate'] ?? defaultDate,
    );
  }
}

class SupplierIndexService {
  static final SupplierIndexService _instance =
      SupplierIndexService._internal();
  factory SupplierIndexService() => _instance;
  SupplierIndexService._internal();

  static const String _fileName = 'supplier_index.json';
  Map<int, SupplierData> _supplierMap = {};
  bool _isInitialized = false;
  int _nextId = 1;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _loadSuppliers();
      _isInitialized = true;
    }
  }

  Future<String> _getFilePath() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    final folderPath = '${directory!.path}/AppData/indexes';
    final folder = Directory(folderPath);
    if (!await folder.exists()) await folder.create(recursive: true);
    return '$folderPath/$_fileName';
  }

  Future<void> _loadSuppliers() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        if (jsonString.isEmpty) {
          _supplierMap.clear();
          _nextId = 1;
          return;
        }
        final Map<String, dynamic> jsonData = jsonDecode(jsonString);

        if (jsonData.containsKey('suppliers') &&
            jsonData.containsKey('nextId')) {
          final Map<String, dynamic> suppliersJson = jsonData['suppliers'];
          _supplierMap.clear();
          suppliersJson.forEach((key, value) {
            _supplierMap[int.parse(key)] = SupplierData.fromJson(value);
          });
          _nextId = jsonData['nextId'] ?? 1;
        }
      } else {
        _supplierMap.clear();
        _nextId = 1;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في تحميل فهرس الموردين: $e');
      _supplierMap.clear();
      _nextId = 1;
    }
  }

  Future<void> _saveToFile() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      final Map<String, dynamic> suppliersJson = {};
      _supplierMap.forEach((key, value) {
        suppliersJson[key.toString()] = value.toJson();
      });
      final Map<String, dynamic> jsonData = {
        'suppliers': suppliersJson,
        'nextId': _nextId,
      };
      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في حفظ فهرس الموردين: $e');
    }
  }

  Future<void> saveSupplier(String supplierName, {String? startDate}) async {
    await _ensureInitialized();
    if (supplierName.trim().isEmpty) return;

    if (!_supplierMap.values.any(
        (s) => s.name.toLowerCase() == supplierName.trim().toLowerCase())) {
      String dateToSave;
      if (startDate != null && startDate.isNotEmpty) {
        dateToSave = startDate;
      } else {
        final now = DateTime.now();
        dateToSave = '${now.year}/${now.month}/${now.day}';
      }

      _supplierMap[_nextId] = SupplierData(
        name: supplierName.trim(),
        startDate: dateToSave,
      );
      _nextId++;
      await _saveToFile();
    }
  }

  Future<void> updateSupplierBalance(
      String supplierName, double amountChange) async {
    await _ensureInitialized();
    final normalized = supplierName.trim().toLowerCase();
    for (var entry in _supplierMap.entries) {
      if (entry.value.name.toLowerCase() == normalized) {
        entry.value.balance += amountChange;
        await _saveToFile();
        return;
      }
    }
  }

  Future<void> updateSupplierMobile(String supplierName, String mobile) async {
    await _ensureInitialized();
    final normalized = supplierName.trim().toLowerCase();
    for (var entry in _supplierMap.entries) {
      if (entry.value.name.toLowerCase() == normalized) {
        entry.value.mobile = mobile;
        await _saveToFile();
        return;
      }
    }
  }

  Future<void> setInitialBalance(String supplierName, double balance) async {
    await _ensureInitialized();
    final normalized = supplierName.trim().toLowerCase();
    for (var entry in _supplierMap.entries) {
      if (entry.value.name.toLowerCase() == normalized) {
        entry.value.balance = balance;
        await _saveToFile();
        return;
      }
    }
  }

  Future<SupplierData?> getSupplierData(String supplierName) async {
    await _ensureInitialized();
    final normalized = supplierName.trim().toLowerCase();
    for (var entry in _supplierMap.entries) {
      if (entry.value.name.toLowerCase() == normalized) {
        return entry.value;
      }
    }
    return null;
  }

  Future<List<String>> getSuggestions(String query) async {
    await _ensureInitialized();
    if (query.isEmpty) return [];
    return _supplierMap.values
        .where((s) => s.name.toLowerCase().contains(query.toLowerCase().trim()))
        .map((s) => s.name)
        .toList();
  }

  Future<Map<int, SupplierData>> getAllSuppliersWithData() async {
    await _ensureInitialized();
    return Map.from(_supplierMap);
  }

  Future<void> removeSupplier(String supplierName) async {
    await _ensureInitialized();
    int? keyToRemove;
    for (var entry in _supplierMap.entries) {
      if (entry.value.name.toLowerCase() == supplierName.trim().toLowerCase()) {
        keyToRemove = entry.key;
        break;
      }
    }
    if (keyToRemove != null) {
      if (_supplierMap[keyToRemove]?.balance == 0.0) {
        _supplierMap.remove(keyToRemove);
        await _saveToFile();
      }
    }
  }
}
