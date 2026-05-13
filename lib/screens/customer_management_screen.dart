import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/customer_index_service.dart';

class CustomerManagementScreen extends StatefulWidget {
  final String? selectedDate;
  const CustomerManagementScreen({super.key, this.selectedDate});
  @override
  State<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  final CustomerIndexService _customerIndexService = CustomerIndexService();
  Map<int, CustomerData> _customersData = {};

  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();

  Map<String, TextEditingController> _mobileControllers = {};
  Map<String, FocusNode> _mobileFocusNodes = {};
  Map<String, TextEditingController> _balanceControllers = {};
  Map<String, FocusNode> _balanceFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _loadCustomers();
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

  Future<void> _loadCustomers() async {
    final customers = await _customerIndexService.getAllCustomersWithData();
    if (mounted) {
      setState(() {
        _customersData = customers;
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

    _customersData.forEach((key, customer) {
      _mobileControllers[customer.name] =
          TextEditingController(text: customer.mobile);
      _mobileFocusNodes[customer.name] = FocusNode();
      _mobileFocusNodes[customer.name]!.addListener(() {
        if (!_mobileFocusNodes[customer.name]!.hasFocus) {
          _saveMobileEdit(customer.name);
        }
      });

      _balanceControllers[customer.name] = TextEditingController(
          text: customer.balance == 0.0
              ? ''
              : customer.balance.toStringAsFixed(2));
      _balanceFocusNodes[customer.name] = FocusNode();
      _balanceFocusNodes[customer.name]!.addListener(() {
        if (!_balanceFocusNodes[customer.name]!.hasFocus) {
          _saveBalanceEdit(customer.name);
        }
      });
    });
  }

  Future<void> _addNewCustomer() async {
    final name = _addController.text.trim();
    if (name.isNotEmpty) {
      await _customerIndexService.saveCustomer(name,
          startDate: widget.selectedDate);
      _addController.clear();
      _addFocusNode.unfocus();
      await _loadCustomers();
    }
  }

  Future<void> _deleteCustomer(CustomerData customer) async {
    if (customer.balance != 0.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'لا يمكن حذف زبون رصيده غير صفر (${customer.balance.toStringAsFixed(2)})'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الزبون "${customer.name}"؟'),
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
      await _customerIndexService.removeCustomer(customer.name);
      await _loadCustomers();
    }
  }

  Future<void> _saveMobileEdit(String customerName) async {
    final newMobile = _mobileControllers[customerName]?.text.trim() ?? '';
    await _customerIndexService.updateCustomerMobile(customerName, newMobile);
  }

  Future<void> _saveBalanceEdit(String customerName) async {
    final text = _balanceControllers[customerName]?.text.trim() ?? '';
    final newBalance = double.tryParse(text) ?? 0.0;
    await _customerIndexService.setInitialBalance(customerName, newBalance);
  }

  @override
  Widget build(BuildContext context) {
    List<MapEntry<int, CustomerData>> sortedEntries =
        _customersData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('أسماء الزبائن وأرصدتهم'),
        backgroundColor: Colors.teal[600],
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
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('المجموع: ',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal)),
                          Text(
                            _customersData.values
                                .fold(0.0, (sum, c) => sum + c.balance)
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
                        labelText: 'إضافة زبون جديد',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addNewCustomer(),
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
                  ? const Center(child: Text('لا يوجد زبائن مسجلين.'))
                  : ListView.builder(
                      itemCount: sortedEntries.length,
                      itemBuilder: (context, index) {
                        final customer = sortedEntries[index].value;
                        final isEven = index % 2 == 0;

                        return Container(
                          color: isEven ? Colors.white : Colors.grey[50],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          child: Row(
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: Text(customer.name,
                                      style: const TextStyle(fontSize: 13))),
                              Expanded(
                                  flex: 3,
                                  child: _buildEditableCell(
                                    controller:
                                        _balanceControllers[customer.name],
                                    focusNode:
                                        _balanceFocusNodes[customer.name],
                                    isNumeric: true,
                                    onSubmitted: (val) {
                                      FocusScope.of(context).requestFocus(
                                          _mobileFocusNodes[customer.name]);
                                    },
                                  )),
                              Expanded(
                                  flex: 3,
                                  child: _buildEditableCell(
                                    controller:
                                        _mobileControllers[customer.name],
                                    focusNode: _mobileFocusNodes[customer.name],
                                    isNumeric: true,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    onSubmitted: (val) {
                                      if (index < sortedEntries.length - 1) {
                                        final nextCustomer =
                                            sortedEntries[index + 1].value;
                                        FocusScope.of(context).requestFocus(
                                            _balanceFocusNodes[
                                                nextCustomer.name]);
                                      } else {
                                        FocusScope.of(context)
                                            .requestFocus(_addFocusNode);
                                      }
                                    },
                                  )),
                              Expanded(
                                  flex: 2,
                                  child: Center(
                                      child: Text(customer.startDate,
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
                                  onPressed: () => _deleteCustomer(customer),
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
