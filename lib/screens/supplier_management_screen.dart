import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supplier_index_service.dart';

class SupplierManagementScreen extends StatefulWidget {
  final String? selectedDate;
  const SupplierManagementScreen({super.key, this.selectedDate});
  @override
  State<SupplierManagementScreen> createState() =>
      _SupplierManagementScreenState();
}

class _SupplierManagementScreenState extends State<SupplierManagementScreen> {
  final SupplierIndexService _supplierIndexService = SupplierIndexService();
  Map<int, SupplierData> _suppliersData = {};

  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();

  Map<String, TextEditingController> _mobileControllers = {};
  Map<String, FocusNode> _mobileFocusNodes = {};
  Map<String, TextEditingController> _balanceControllers = {};
  Map<String, FocusNode> _balanceFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    _mobileControllers.values.forEach((c) => c.dispose());
    _mobileFocusNodes.values.forEach((n) => n.dispose());
    _balanceControllers.values.forEach((c) => c.dispose());
    _balanceFocusNodes.values.forEach((n) => n.dispose());
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await _supplierIndexService.getAllSuppliersWithData();
    if (mounted) {
      setState(() {
        _suppliersData = suppliers;
        _initializeControllersAndNodes();
      });
    }
  }

  void _initializeControllersAndNodes() {
    _mobileControllers.values.forEach((c) => c.dispose());
    _mobileFocusNodes.values.forEach((n) => n.dispose());
    _balanceControllers.values.forEach((c) => c.dispose());
    _balanceFocusNodes.values.forEach((n) => n.dispose());

    _mobileControllers.clear();
    _mobileFocusNodes.clear();
    _balanceControllers.clear();
    _balanceFocusNodes.clear();

    _suppliersData.forEach((key, supplier) {
      _mobileControllers[supplier.name] =
          TextEditingController(text: supplier.mobile);
      _mobileFocusNodes[supplier.name] = FocusNode();
      _mobileFocusNodes[supplier.name]!.addListener(() {
        if (!_mobileFocusNodes[supplier.name]!.hasFocus) {
          _saveMobileEdit(supplier.name);
        }
      });

      _balanceControllers[supplier.name] = TextEditingController(
          text: supplier.balance == 0.0
              ? ''
              : supplier.balance.toStringAsFixed(2));
      _balanceFocusNodes[supplier.name] = FocusNode();
      _balanceFocusNodes[supplier.name]!.addListener(() {
        if (!_balanceFocusNodes[supplier.name]!.hasFocus) {
          _saveBalanceEdit(supplier.name);
        }
      });
    });
  }

  Future<void> _addNewSupplier() async {
    final name = _addController.text.trim();
    if (name.isNotEmpty) {
      await _supplierIndexService.saveSupplier(name,
          startDate: widget.selectedDate);
      _addController.clear();
      _addFocusNode.unfocus();
      await _loadSuppliers();
    }
  }

  Future<void> _deleteSupplier(SupplierData supplier) async {
    if (supplier.balance != 0.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'لا يمكن حذف مورد رصيده غير صفر (${supplier.balance.toStringAsFixed(2)})'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المورد "${supplier.name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      await _supplierIndexService.removeSupplier(supplier.name);
      await _loadSuppliers();
    }
  }

  Future<void> _saveMobileEdit(String supplierName) async {
    final newMobile = _mobileControllers[supplierName]?.text.trim() ?? '';
    await _supplierIndexService.updateSupplierMobile(supplierName, newMobile);
  }

  Future<void> _saveBalanceEdit(String supplierName) async {
    final text = _balanceControllers[supplierName]?.text.trim() ?? '';
    final newBalance = double.tryParse(text) ?? 0.0;
    await _supplierIndexService.setInitialBalance(supplierName, newBalance);
  }

  @override
  Widget build(BuildContext context) {
    List<MapEntry<int, SupplierData>> sortedEntries =
        _suppliersData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('أسماء الموردين وأرصدتهم'),
        backgroundColor: Colors.brown[600],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.brown[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.brown.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('المجموع: ',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown)),
                          Text(
                            _suppliersData.values
                                .fold(0.0, (sum, s) => sum + s.balance)
                                .toStringAsFixed(2),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _addController,
                      focusNode: _addFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'إضافة مورد جديد',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addNewSupplier(),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.grey[300],
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: const [
                  Expanded(
                      flex: 2,
                      child: Text('الاسم',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(
                      flex: 3,
                      child: Text('الرصيد',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                          textAlign: TextAlign.center)),
                  Expanded(
                      flex: 3,
                      child: Text('الموبايل',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                          textAlign: TextAlign.center)),
                  Expanded(
                      flex: 2,
                      child: Text('تاريخ البدء',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                          textAlign: TextAlign.center)),
                  SizedBox(width: 30),
                ],
              ),
            ),
            Expanded(
              child: sortedEntries.isEmpty
                  ? const Center(child: Text('لا يوجد موردين مسجلين.'))
                  : ListView.builder(
                      itemCount: sortedEntries.length,
                      itemBuilder: (context, index) {
                        final supplier = sortedEntries[index].value;
                        final isEven = index % 2 == 0;

                        return Container(
                          color: isEven ? Colors.white : Colors.grey[50],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          child: Row(
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: Text(supplier.name,
                                      style: const TextStyle(fontSize: 13))),
                              Expanded(
                                  flex: 3,
                                  child: _buildEditableCell(
                                    controller:
                                        _balanceControllers[supplier.name],
                                    focusNode:
                                        _balanceFocusNodes[supplier.name],
                                    isNumeric: true,
                                    onSubmitted: (val) {
                                      FocusScope.of(context).requestFocus(
                                          _mobileFocusNodes[supplier.name]);
                                    },
                                  )),
                              Expanded(
                                  flex: 3,
                                  child: _buildEditableCell(
                                    controller:
                                        _mobileControllers[supplier.name],
                                    focusNode: _mobileFocusNodes[supplier.name],
                                    isNumeric: true,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    onSubmitted: (val) {
                                      if (index < sortedEntries.length - 1) {
                                        final nextSupplier =
                                            sortedEntries[index + 1].value;
                                        FocusScope.of(context).requestFocus(
                                            _balanceFocusNodes[
                                                nextSupplier.name]);
                                      } else {
                                        FocusScope.of(context)
                                            .requestFocus(_addFocusNode);
                                      }
                                    },
                                  )),
                              Expanded(
                                  flex: 2,
                                  child: Center(
                                      child: Text(supplier.startDate,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.black)))),
                              SizedBox(
                                width: 30,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  iconSize: 18,
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteSupplier(supplier),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableCell({
    required TextEditingController? controller,
    required FocusNode? focusNode,
    bool isNumeric = false,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onSubmitted,
  }) {
    if (controller == null || focusNode == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: inputFormatters,
        onSubmitted: onSubmitted,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 2),
          border: UnderlineInputBorder(),
        ),
      ),
    );
  }
}
