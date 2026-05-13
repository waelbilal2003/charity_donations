import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../models/payment_model.dart';
import '../services/purchases_storage_service.dart';
import '../services/supplier_index_service.dart';
import '../widgets/table_components.dart' as TableComponents;
import '../widgets/suggestions_banner.dart';
import 'supplier_management_screen.dart';
import 'package:path_provider/path_provider.dart';

class PurchasesScreen extends StatefulWidget {
  final String selectedDate;

  const PurchasesScreen({
    Key? key,
    required this.selectedDate,
  }) : super(key: key);

  @override
  _PurchasesScreenState createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final PurchasesStorageService _storageService = PurchasesStorageService();
  final SupplierIndexService _supplierIndexService = SupplierIndexService();

  List<List<TextEditingController>> rowControllers = [];
  List<List<FocusNode>> rowFocusNodes = [];

  late TextEditingController totalPaymentsController;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  List<String> _supplierSuggestions = [];
  int? _activeSupplierRowIndex;
  bool _showFullScreenSuggestions = false;
  late ScrollController _suggestionsScrollController;

  List<Map<String, String>> _availableDates = [];
  bool _isLoadingDates = false;

  Timer? _calculateTotalsDebouncer;
  double _grandTotal = 0.0;

  @override
  void initState() {
    super.initState();
    totalPaymentsController = TextEditingController(text: '0.00');
    _suggestionsScrollController = ScrollController();

    _verticalScrollController.addListener(_hideSuggestions);
    _horizontalScrollController.addListener(_hideSuggestions);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrCreate();
      _loadAvailableDates();
    });
  }

  @override
  void dispose() {
    if (_hasUnsavedChanges && !_isSaving) {
      _saveCurrentRecord(silent: true);
    }
    for (var row in rowControllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    for (var row in rowFocusNodes) {
      for (var node in row) {
        node.dispose();
      }
    }
    totalPaymentsController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _suggestionsScrollController.dispose();
    _calculateTotalsDebouncer?.cancel();
    super.dispose();
  }

  Future<void> _loadAvailableDates() async {
    if (_isLoadingDates) return;
    setState(() => _isLoadingDates = true);
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      final folderPath = '${directory!.path}/PurchasesJournals';
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        setState(() {
          _availableDates = [];
          _isLoadingDates = false;
        });
        return;
      }
      final files = await folder.list().toList();
      final dates = <Map<String, String>>[];
      for (var file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final jsonString = await file.readAsString();
            final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
            final date = jsonMap['date']?.toString() ?? '';
            if (date.isNotEmpty) {
              dates.add({'date': date});
            }
          } catch (_) {}
        }
      }
      dates.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));
      setState(() {
        _availableDates = dates;
        _isLoadingDates = false;
      });
      _loadGrandTotal();
    } catch (e) {
      setState(() {
        _availableDates = [];
        _isLoadingDates = false;
      });
    }
  }

  Future<void> _loadGrandTotal() async {
    double total = 0.0;
    for (var dateInfo in _availableDates) {
      final doc = await _storageService.loadDocumentForDate(dateInfo['date']!);
      if (doc != null) {
        total += double.tryParse(doc.totals['totalPayments'] ?? '0') ?? 0;
      }
    }
    if (mounted) setState(() => _grandTotal = total);
  }

  void _hideSuggestions() {
    if (mounted) {
      setState(() {
        _supplierSuggestions = [];
        _activeSupplierRowIndex = null;
        _showFullScreenSuggestions = false;
      });
    }
  }

  Future<void> _loadOrCreate() async {
    final document =
        await _storageService.loadDocumentForDate(widget.selectedDate);
    if (document != null && document.transactions.isNotEmpty) {
      _loadData(document);
    } else {
      _createNew();
    }
  }

  void _createNew() {
    setState(() {
      rowControllers.clear();
      rowFocusNodes.clear();
      totalPaymentsController.text = '0.00';
      _hasUnsavedChanges = false;
      _addNewRow();
    });
  }

  void _loadData(PaymentDocument document) {
    setState(() {
      for (var row in rowControllers) {
        for (var c in row) c.dispose();
      }
      for (var row in rowFocusNodes) {
        for (var n in row) n.dispose();
      }

      rowControllers.clear();
      rowFocusNodes.clear();

      for (var transaction in document.transactions) {
        final newControllers = [
          TextEditingController(text: transaction.serialNumber),
          TextEditingController(text: transaction.paymentValue),
          TextEditingController(text: transaction.workerName),
          TextEditingController(text: transaction.notes),
        ];
        _addChangeListeners(newControllers, rowControllers.length);
        rowControllers.add(newControllers);
        rowFocusNodes.add(List.generate(4, (_) => FocusNode()));
      }
      totalPaymentsController.text = document.totals['totalPayments'] ?? '0.00';
      _hasUnsavedChanges = false;
    });
  }

  void _addNewRow() {
    setState(() {
      final newControllers = List.generate(4, (_) => TextEditingController());
      newControllers[0].text = (rowControllers.length + 1).toString();

      final newFocusNodes = List.generate(4, (_) => FocusNode());

      _addChangeListeners(newControllers, rowControllers.length);

      rowControllers.add(newControllers);
      rowFocusNodes.add(newFocusNodes);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rowFocusNodes.isNotEmpty) {
        FocusScope.of(context).requestFocus(rowFocusNodes.last[1]);
      }
    });
  }

  void _addChangeListeners(
      List<TextEditingController> controllers, int rowIndex) {
    controllers[1].addListener(() {
      _hasUnsavedChanges = true;
      _calculateAllTotals();
    });
    controllers[2].addListener(() {
      _hasUnsavedChanges = true;
      _updateSupplierSuggestions(rowIndex);
    });
    controllers[3].addListener(() => _hasUnsavedChanges = true);
  }

  void _calculateAllTotals() {
    _calculateTotalsDebouncer?.cancel();
    _calculateTotalsDebouncer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      double total = 0;
      for (var controllers in rowControllers) {
        total += double.tryParse(controllers[1].text) ?? 0;
      }
      setState(() {
        totalPaymentsController.text = total.toStringAsFixed(2);
      });
    });
  }

  Future<void> _updateSupplierSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][2].text;
    if (query.isEmpty) {
      _hideSuggestions();
      return;
    }
    final suggestions = await _supplierIndexService.getSuggestions(query);
    if (mounted) {
      setState(() {
        _supplierSuggestions = suggestions;
        _activeSupplierRowIndex = rowIndex;
        _showFullScreenSuggestions = suggestions.isNotEmpty;
      });
    }
  }

  void _selectSupplierSuggestion(String name, int rowIndex) {
    rowControllers[rowIndex][2].text = name;
    _hideSuggestions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rowIndex < rowFocusNodes.length) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
      }
    });
  }

  Future<void> _saveCurrentRecord({bool silent = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final List<PaymentTransaction> newTransactions = [];
    for (int i = 0; i < rowControllers.length; i++) {
      final controllers = rowControllers[i];
      if (controllers[1].text.isNotEmpty || controllers[2].text.isNotEmpty) {
        newTransactions.add(PaymentTransaction(
          serialNumber: (newTransactions.length + 1).toString(),
          paymentValue: controllers[1].text,
          workerName: controllers[2].text.trim(),
          notes: controllers[3].text,
        ));
      }
    }

    Map<String, double> balanceChanges = {};
    final existingDoc =
        await _storageService.loadDocumentForDate(widget.selectedDate);

    if (existingDoc != null) {
      for (var oldTrans in existingDoc.transactions) {
        if (oldTrans.workerName.isNotEmpty) {
          double oldVal = double.tryParse(oldTrans.paymentValue) ?? 0;
          balanceChanges[oldTrans.workerName] =
              (balanceChanges[oldTrans.workerName] ?? 0) - oldVal;
        }
      }
    }

    for (var newTrans in newTransactions) {
      if (newTrans.workerName.isNotEmpty) {
        double newVal = double.tryParse(newTrans.paymentValue) ?? 0;
        balanceChanges[newTrans.workerName] =
            (balanceChanges[newTrans.workerName] ?? 0) + newVal;
      }
    }

    for (var entry in balanceChanges.entries) {
      if (entry.value != 0) {
        await _supplierIndexService.updateSupplierBalance(
            entry.key, entry.value);
      }
    }

    final newTotal = newTransactions.fold(
        0.0, (sum, t) => sum + (double.tryParse(t.paymentValue) ?? 0));
    final documentToSave = PaymentDocument(
      date: widget.selectedDate,
      transactions: newTransactions,
      totals: {'totalPayments': newTotal.toStringAsFixed(2)},
    );

    await _storageService.saveDocument(documentToSave);

    if (mounted) {
      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم الحفظ بنجاح ✓'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1)),
        );
      }
    }
  }

  void _handleFieldSubmitted(String value, int rowIndex, int colIndex) {
    if (colIndex == 1) {
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
    } else if (colIndex == 2) {
      if (_supplierSuggestions.isNotEmpty) {
        _selectSupplierSuggestion(_supplierSuggestions.first, rowIndex);
      } else {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
      }
    } else if (colIndex == 3) {
      if (rowIndex == rowControllers.length - 1) {
        _addNewRow();
      } else {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex + 1][1]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges && !_isSaving) {
          await _saveCurrentRecord(silent: true);
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showFullScreenSuggestions
                ? SuggestionsBanner(
                    suggestions: _supplierSuggestions,
                    type: 'supplier',
                    currentRowIndex: _activeSupplierRowIndex ?? 0,
                    scrollController: _suggestionsScrollController,
                    onSelect: _selectSupplierSuggestion,
                    onClose: _hideSuggestions,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'المشتريات - ${widget.selectedDate}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1.5),
                      ),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('الإجمالي الكلي: ',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white70)),
                            Text(
                              _grandTotal.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.lightBlueAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          centerTitle: true,
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.people),
              tooltip: 'فهرس الموردين',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => SupplierManagementScreen(
                          selectedDate: widget.selectedDate)),
                );
                _loadOrCreate();
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.calendar_month, size: 22),
              tooltip: 'فتح يومية سابقة',
              onSelected: (selectedDate) async {
                if (selectedDate != widget.selectedDate) {
                  if (_hasUnsavedChanges) {
                    await _saveCurrentRecord(silent: true);
                  }
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PurchasesScreen(
                        selectedDate: selectedDate,
                      ),
                    ),
                  );
                }
              },
              itemBuilder: (BuildContext context) {
                List<PopupMenuEntry<String>> items = [];
                if (_isLoadingDates) {
                  items.add(const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Text('جاري التحميل...'),
                  ));
                } else if (_availableDates.isEmpty) {
                  items.add(const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Text('لا توجد يوميات سابقة'),
                  ));
                } else {
                  items.add(const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Text(
                      'اليوميات المتاحة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ));
                  items.add(const PopupMenuDivider());
                  for (var dateInfo in _availableDates) {
                    final date = dateInfo['date']!;
                    items.add(PopupMenuItem<String>(
                      value: date,
                      child: Text(
                        'يومية تاريخ $date',
                        style: TextStyle(
                          fontWeight: date == widget.selectedDate
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: date == widget.selectedDate
                              ? Colors.blue
                              : Colors.black,
                        ),
                      ),
                    ));
                  }
                }
                return items;
              },
            ),
          ],
        ),
        body: _buildTableWithStickyHeader(),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewRow,
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildTableWithStickyHeader() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: CustomScrollView(
        controller: _verticalScrollController,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: TableComponents.StickyTableHeaderDelegate(
              child: Container(
                color: Colors.grey[200],
                child: _buildTableHeader(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                child: _buildTableContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.1),
        1: FlexColumnWidth(0.25),
        2: FlexColumnWidth(0.4),
        3: FlexColumnWidth(0.25),
      },
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[200]),
          children: [
            TableComponents.buildTableHeaderCell('ت'),
            TableComponents.buildTableHeaderCell('قيمة الدين'),
            TableComponents.buildTableHeaderCell('اسم المورد'),
            TableComponents.buildTableHeaderCell('البيان'),
          ],
        ),
      ],
    );
  }

  Widget _buildTableContent() {
    List<TableRow> rows = [];
    for (int i = 0; i < rowControllers.length; i++) {
      rows.add(TableRow(children: [
        _buildCell(i, 0),
        _buildCell(i, 1,
            isNumeric: true,
            inputFormatters: [TableComponents.PositiveDecimalInputFormatter()]),
        _buildCell(i, 2),
        _buildCell(i, 3),
      ]));
    }
    rows.add(TableRow(
      decoration: BoxDecoration(color: Colors.yellow[50]),
      children: [
        Container(),
        TableComponents.buildTotalCell(totalPaymentsController),
        Container(),
        Container(),
      ],
    ));
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.1),
        1: FlexColumnWidth(0.25),
        2: FlexColumnWidth(0.4),
        3: FlexColumnWidth(0.25),
      },
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: rows,
    );
  }

  Widget _buildCell(int rowIndex, int colIndex,
      {bool isNumeric = false, List<TextInputFormatter>? inputFormatters}) {
    return Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: rowControllers[rowIndex][colIndex],
        focusNode: rowFocusNodes[rowIndex][colIndex],
        readOnly: colIndex == 0,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          border: InputBorder.none,
          isDense: true,
        ),
        style: TextStyle(
            fontSize: 13,
            color: Colors.black,
            fontWeight: colIndex == 1 ? FontWeight.bold : FontWeight.normal),
        textAlign: isNumeric ? TextAlign.center : TextAlign.right,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: inputFormatters,
        onSubmitted: (value) =>
            _handleFieldSubmitted(value, rowIndex, colIndex),
      ),
    );
  }
}
