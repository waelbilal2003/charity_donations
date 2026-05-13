import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class CustomerData {
  String name;
  double balance;
  String mobile;
  String startDate;

  CustomerData({
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

  factory CustomerData.fromJson(dynamic json) {
    final now = DateTime.now();
    final defaultDate = '${now.year}/${now.month}/${now.day}';

    if (json is String) {
      return CustomerData(name: json, startDate: defaultDate);
    }
    return CustomerData(
      name: json['name'] ?? '',
      balance: (json['balance'] ?? 0.0).toDouble(),
      mobile: json['mobile'] ?? '',
      startDate: json['startDate'] ?? defaultDate,
    );
  }
}

class CustomerIndexService {
  static final CustomerIndexService _instance =
      CustomerIndexService._internal();
  factory CustomerIndexService() => _instance;
  CustomerIndexService._internal();

  static const String _fileName = 'customer_index.json';
  Map<int, CustomerData> _customerMap = {};
  bool _isInitialized = false;
  int _nextId = 1;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _loadCustomers();
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

  Future<void> _loadCustomers() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        if (jsonString.isEmpty) {
          _customerMap.clear();
          _nextId = 1;
          return;
        }
        final Map<String, dynamic> jsonData = jsonDecode(jsonString);

        if (jsonData.containsKey('customers') &&
            jsonData.containsKey('nextId')) {
          final Map<String, dynamic> customersJson = jsonData['customers'];
          _customerMap.clear();
          customersJson.forEach((key, value) {
            _customerMap[int.parse(key)] = CustomerData.fromJson(value);
          });
          _nextId = jsonData['nextId'] ?? 1;
        }
      } else {
        _customerMap.clear();
        _nextId = 1;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في تحميل فهرس الزبائن: $e');
      _customerMap.clear();
      _nextId = 1;
    }
  }

  Future<void> _saveToFile() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      final Map<String, dynamic> customersJson = {};
      _customerMap.forEach((key, value) {
        customersJson[key.toString()] = value.toJson();
      });
      final Map<String, dynamic> jsonData = {
        'customers': customersJson,
        'nextId': _nextId,
      };
      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في حفظ فهرس الزبائن: $e');
    }
  }

  Future<void> saveCustomer(String customerName, {String? startDate}) async {
    await _ensureInitialized();
    if (customerName.trim().isEmpty) return;

    if (!_customerMap.values.any(
        (c) => c.name.toLowerCase() == customerName.trim().toLowerCase())) {
      String dateToSave;
      if (startDate != null && startDate.isNotEmpty) {
        dateToSave = startDate;
      } else {
        final now = DateTime.now();
        dateToSave = '${now.year}/${now.month}/${now.day}';
      }

      _customerMap[_nextId] = CustomerData(
        name: customerName.trim(),
        startDate: dateToSave,
      );
      _nextId++;
      await _saveToFile();
    }
  }

  Future<void> updateCustomerBalance(
      String customerName, double amountChange) async {
    await _ensureInitialized();
    final normalized = customerName.trim().toLowerCase();
    for (var entry in _customerMap.entries) {
      if (entry.value.name.toLowerCase() == normalized) {
        entry.value.balance += amountChange;
        await _saveToFile();
        return;
      }
    }
  }

  Future<void> updateCustomerMobile(String customerName, String mobile) async {
    await _ensureInitialized();
    final normalized = customerName.trim().toLowerCase();
    for (var entry in _customerMap.entries) {
      if (entry.value.name.toLowerCase() == normalized) {
        entry.value.mobile = mobile;
        await _saveToFile();
        return;
      }
    }
  }

  Future<void> setInitialBalance(String customerName, double balance) async {
    await _ensureInitialized();
    final normalized = customerName.trim().toLowerCase();
    for (var entry in _customerMap.entries) {
      if (entry.value.name.toLowerCase() == normalized) {
        entry.value.balance = balance;
        await _saveToFile();
        return;
      }
    }
  }

  Future<List<String>> getSuggestions(String query) async {
    await _ensureInitialized();
    if (query.isEmpty) return [];
    return _customerMap.values
        .where((c) => c.name.toLowerCase().contains(query.toLowerCase().trim()))
        .map((c) => c.name)
        .toList();
  }

  Future<Map<int, CustomerData>> getAllCustomersWithData() async {
    await _ensureInitialized();
    return Map.from(_customerMap);
  }

  Future<void> removeCustomer(String customerName) async {
    await _ensureInitialized();
    int? keyToRemove;
    for (var entry in _customerMap.entries) {
      if (entry.value.name.toLowerCase() == customerName.trim().toLowerCase()) {
        keyToRemove = entry.key;
        break;
      }
    }
    if (keyToRemove != null) {
      if (_customerMap[keyToRemove]?.balance == 0.0) {
        _customerMap.remove(keyToRemove);
        await _saveToFile();
      }
    }
  }
}
