import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/box_model.dart';
import '../services/box_storage_service.dart';
import '../widgets/table_builder.dart' as TableBuilder;
import '../widgets/table_components.dart' as TableComponents;
import '../services/customer_index_service.dart';
import '../services/supplier_index_service.dart';
import '../services/enhanced_index_service.dart';
import '../widgets/suggestions_banner.dart';
import '../services/app_settings_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class BoxScreen extends StatefulWidget {
  final String sellerName;
  final String selectedDate;
  final String storeName;

  const BoxScreen({
    Key? key,
    required this.sellerName,
    required this.selectedDate,
    required this.storeName,
  }) : super(key: key);

  @override
  _BoxScreenState createState() => _BoxScreenState();
}

class _BoxScreenState extends State<BoxScreen> {
  // خدمة التخزين
  final BoxStorageService _storageService = BoxStorageService();

  //  خدمة فهرس الزبائن
  final CustomerIndexService _customerIndexService = CustomerIndexService();
  // خدمة فهرس الموردين
  final SupplierIndexService _supplierIndexService = SupplierIndexService();

  List<String> _customerSuggestions = [];
  int? _activeCustomerRowIndex;
  final ScrollController _customerSuggestionsScrollController =
      ScrollController();

  // بيانات الحقول
  String dayName = '';

  // قائمة لتخزين صفوف الجدول
  List<List<TextEditingController>> rowControllers = [];
  List<List<FocusNode>> rowFocusNodes = [];
  List<String> accountTypeValues = [];
  List<String> sellerNames = []; // <-- تخزين اسم البائع لكل صف

  // متحكمات المجموع
  late TextEditingController totalReceivedController;
  late TextEditingController totalPaidController;

  // قوائم الخيارات
  final List<String> accountTypeOptions = ['زبون', 'مورد', 'مصروف'];

  // متحكمات للتمرير
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final _scrollController = ScrollController();

  // حالة الحفظ
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  // التواريخ المتاحة
  List<Map<String, String>> _availableDates = [];
  bool _isLoadingDates = false;

  String serialNumber = '';
  // ignore: unused_field
  String? _currentJournalNumber;

  List<String> _supplierSuggestions = [];

  int? _activeSupplierRowIndex;

  bool _showFullScreenSuggestions = false;
  String _currentSuggestionType = '';
  late ScrollController
      _horizontalSuggestionsController; // في initState قم بتعريفه: _horizontalSuggestionsController = ScrollController();

  // ============ تحديث أرصدة الموردين والزبائن ============
  Map<String, double> customerBalanceChanges = {};
  Map<String, double> supplierBalanceChanges = {};

  // متغير لتأخير حساب المجاميع (debouncing)
  Timer? _calculateTotalsDebouncer;
  bool _isCalculating = false;
  bool _isAdmin = false;
  double? _lastFetchedBalance;
  double? _calculatedRemaining;
  String _lastAccountName = '';
  double _grandTotalReceived = 0.0;
  double _grandTotalPaid = 0.0;

  @override
  void initState() {
    super.initState();
    dayName = _extractDayName(widget.selectedDate);

    totalReceivedController = TextEditingController();
    totalPaidController = TextEditingController();
    _resetTotalValues();

    // تهيئة المتحكم
    _horizontalSuggestionsController = ScrollController();

    _verticalScrollController.addListener(() {
      _hideAllSuggestionsImmediately();
    });

    _horizontalScrollController.addListener(() {
      _hideAllSuggestionsImmediately();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminStatus().then((_) {
        _loadOrCreateJournal();
      });
      _loadAvailableDates();
      _loadJournalNumber();
    });
  }

  @override
  void dispose() {
    _saveCurrentRecord(silent: true);
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
    totalReceivedController.dispose();
    totalPaidController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _scrollController.dispose();
    _customerSuggestionsScrollController.dispose();

    // إغلاق المتحكم
    _horizontalSuggestionsController.dispose();

    _calculateTotalsDebouncer?.cancel();
    super.dispose();
  }

  String _extractDayName(String dateString) {
    final days = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت'
    ];
    final now = DateTime.now();
    return days[now.weekday % 7];
  }

  // تحميل التواريخ المتاحة
  Future<void> _loadAvailableDates() async {
    if (_isLoadingDates) return;

    setState(() {
      _isLoadingDates = true;
    });

    try {
      final dates = await _storageService.getAvailableDatesWithNumbers();
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
    double totalRec = 0.0, totalPaid = 0.0;
    for (var dateInfo in _availableDates) {
      final doc =
          await _storageService.loadBoxDocumentForDate(dateInfo['date']!);
      if (doc != null) {
        totalRec += double.tryParse(doc.totals['totalReceived'] ?? '0') ?? 0;
        totalPaid += double.tryParse(doc.totals['totalPaid'] ?? '0') ?? 0;
      }
    }
    if (mounted) {
      setState(() {
        _grandTotalReceived = totalRec;
        _grandTotalPaid = totalPaid;
      });
    }
  }

  // تحميل اليومية إذا كانت موجودة، أو إنشاء جديدة
  Future<void> _loadOrCreateJournal() async {
    final document =
        await _storageService.loadBoxDocumentForDate(widget.selectedDate);

    if (document != null && document.transactions.isNotEmpty) {
      // تحميل اليومية الموجودة
      _loadJournal(document);
    } else {
      // إنشاء يومية جديدة
      _createNewJournal();
    }
  }

  void _resetTotalValues() {
    totalReceivedController.text = '0.00';
    totalPaidController.text = '0.00';
  }

  void _createNewJournal() {
    setState(() {
      rowControllers.clear();
      rowFocusNodes.clear();
      accountTypeValues.clear();
      sellerNames.clear();
      _resetTotalValues();
      _hasUnsavedChanges = false;
      _addNewRow();
    });
  }

  void _addNewRow() {
    setState(() {
      final newSerialNumber = (rowControllers.length + 1).toString();

      List<TextEditingController> newControllers =
          List.generate(5, (index) => TextEditingController());

      List<FocusNode> newFocusNodes = List.generate(5, (index) => FocusNode());

      newControllers[0].text = newSerialNumber;

      // إضافة مستمع FocusNode لحقل اسم الحساب
      newFocusNodes[3].addListener(() {
        if (!newFocusNodes[3].hasFocus) {
          // إخفاء الاقتراحات عند فقدان التركيز
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                _supplierSuggestions = [];
                _activeSupplierRowIndex = null;
                _customerSuggestions = [];
                _activeCustomerRowIndex = null;
                _showFullScreenSuggestions = false;
                _currentSuggestionType = '';
              });
            }
          });
        }
      });

      // إضافة مستمعات للتغيير
      _addChangeListenersToControllers(newControllers, rowControllers.length);

      // تخزين اسم البائع للصف الجديد
      sellerNames.add(widget.sellerName);

      rowControllers.add(newControllers);
      rowFocusNodes.add(newFocusNodes);
      accountTypeValues.add('');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rowFocusNodes.isNotEmpty) {
        final newRowIndex = rowFocusNodes.length - 1;
        FocusScope.of(context).requestFocus(rowFocusNodes[newRowIndex][1]);
      }
    });
  }

  // دالة مساعدة لإخفاء جميع الاقتراحات فوراً
  void _hideAllSuggestionsImmediately() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _customerSuggestions = [];
          _supplierSuggestions = [];
          _activeCustomerRowIndex = null;
          _activeSupplierRowIndex = null;
        });
      }
    });
  }

  // دالة مساعدة لإضافة المستمعات
  void _addChangeListenersToControllers(
      List<TextEditingController> controllers, int rowIndex) {
    // حقل المقبوض (تعديل: إضافة حساب الرصيد الفوري)
    controllers[1].addListener(() {
      _hasUnsavedChanges = true;
      if (controllers[1].text.isNotEmpty) {
        controllers[2].text = '';
      }
      _calculateAllTotals();
      // استدعاء حساب الرصيد والباقي فورياً عند الكتابة
      _fetchAndCalculateBalance(rowIndex);
    });

    // حقل المدفوع (تعديل: إضافة حساب الرصيد الفوري)
    controllers[2].addListener(() {
      _hasUnsavedChanges = true;
      if (controllers[2].text.isNotEmpty) {
        controllers[1].text = '';
      }
      _calculateAllTotals();
      // استدعاء حساب الرصيد والباقي فورياً عند الكتابة
      _fetchAndCalculateBalance(rowIndex);
    });

    // حقل اسم الحساب (الحقل رقم 3)
    controllers[3].addListener(() {
      _hasUnsavedChanges = true;

      // فقط تحديث الاقتراحات بناءً على نوع الحساب
      if (accountTypeValues[rowIndex] == 'زبون') {
        _updateCustomerSuggestions(rowIndex);
      } else if (accountTypeValues[rowIndex] == 'مورد') {
        _updateSupplierSuggestions(rowIndex);
      }
    });

    // حقل الملاحظات
    controllers[4].addListener(() => _hasUnsavedChanges = true);

    // إضافة مستمع FocusNode لحقل اسم الحساب (الحقل 3) فقط لإخفاء الاقتراحات عند فقدان التركيز
    if (rowIndex < rowFocusNodes.length && rowFocusNodes[rowIndex].length > 3) {
      rowFocusNodes[rowIndex][3].addListener(() {
        if (!rowFocusNodes[rowIndex][3].hasFocus) {
          // إخفاء الاقتراحات بعد تأخير بسيط
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                // إخفاء الاقتراحات فقط
                _customerSuggestions = [];
                _supplierSuggestions = [];
                _activeCustomerRowIndex = null;
                _activeSupplierRowIndex = null;
                _showFullScreenSuggestions = false;
                _currentSuggestionType = '';
              });
            }
          });
        }
      });
    }
  }

  void _calculateAllTotals() {
    // إلغاء أي حساب سابق منتظر
    _calculateTotalsDebouncer?.cancel();

    // تأخير الحساب لتجنب التكرار المتعدد
    _calculateTotalsDebouncer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted || _isCalculating) return;

      _isCalculating = true;

      double totalReceived = 0;
      double totalPaid = 0;

      for (var controllers in rowControllers) {
        try {
          totalReceived += double.tryParse(controllers[1].text) ?? 0;
          totalPaid += double.tryParse(controllers[2].text) ?? 0;
        } catch (e) {}
      }

      if (mounted) {
        setState(() {
          totalReceivedController.text = totalReceived.toStringAsFixed(2);
          totalPaidController.text = totalPaid.toStringAsFixed(2);
        });
      }

      _isCalculating = false;
    });
  }

  // تعديل _loadJournal لاستخدام الدالة المساعدة
  void _loadJournal(BoxDocument document) {
    setState(() {
      // تنظيف المتحكمات القديمة
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

      // إعادة تهيئة القوائم
      rowControllers.clear();
      rowFocusNodes.clear();
      accountTypeValues.clear();
      sellerNames.clear();

      // تحميل السجلات من الوثيقة
      for (int i = 0; i < document.transactions.length; i++) {
        var transaction = document.transactions[i];

        List<TextEditingController> newControllers = [
          TextEditingController(text: transaction.serialNumber),
          TextEditingController(text: transaction.received),
          TextEditingController(text: transaction.paid),
          TextEditingController(text: transaction.accountName),
          TextEditingController(text: transaction.notes),
        ];

        List<FocusNode> newFocusNodes =
            List.generate(5, (index) => FocusNode());

        // تخزين اسم البائع لهذا الصف
        sellerNames.add(transaction.sellerName);

        // التحقق إذا كان السجل مملوكاً للبائع الحالي
        final bool isOwnedByCurrentSeller =
            transaction.sellerName == widget.sellerName;

        // إضافة مستمعات للتغيير فقط إذا كان السجل مملوكاً للبائع الحالي
        if (isOwnedByCurrentSeller) {
          _addChangeListenersToControllers(newControllers, i);
        }

        rowControllers.add(newControllers);
        rowFocusNodes.add(newFocusNodes);
        accountTypeValues.add(transaction.accountType);
      }

      // تحميل المجاميع
      if (document.totals.isNotEmpty) {
        totalReceivedController.text =
            document.totals['totalReceived'] ?? '0.00';
        totalPaidController.text = document.totals['totalPaid'] ?? '0.00';
      }

      _hasUnsavedChanges = false;
    });
  }

  void _scrollToField(int rowIndex, int colIndex) {
    const double headerHeight = 32.0;
    const double rowHeight = 25.0;
    final double verticalPosition = (rowIndex * rowHeight);
    const double columnWidth = 80.0;
    final double horizontalPosition = colIndex * columnWidth;

    _verticalScrollController.animateTo(
      verticalPosition + headerHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    _horizontalScrollController.animateTo(
      horizontalPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildTableHeader() {
    return Table(
      columnWidths: {
        0: FlexColumnWidth(0.09),
        1: FlexColumnWidth(0.18),
        2: FlexColumnWidth(0.18),
        3: FlexColumnWidth(0.37),
        4: FlexColumnWidth(0.18),
      },
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[200]),
          children: [
            TableComponents.buildTableHeaderCell('ت'),
            TableComponents.buildTableHeaderCell('مقبوض'),
            TableComponents.buildTableHeaderCell('مدفوع'),
            TableComponents.buildTableHeaderCell('الحساب'),
            TableComponents.buildTableHeaderCell('ملاحظات'),
          ],
        ),
      ],
    );
  }

  Widget _buildTableContent() {
    List<TableRow> contentRows = [];

    for (int i = 0; i < rowControllers.length; i++) {
      final bool isOwnedByCurrentSeller = sellerNames[i] == widget.sellerName;

      contentRows.add(
        TableRow(
          children: [
            _buildTableCell(rowControllers[i][0], rowFocusNodes[i][0], i, 0,
                isOwnedByCurrentSeller),
            _buildReceivedCell(rowControllers[i][1], rowFocusNodes[i][1], i, 1,
                isOwnedByCurrentSeller),
            _buildPaidCell(rowControllers[i][2], rowFocusNodes[i][2], i, 2,
                isOwnedByCurrentSeller),
            _buildAccountCell(i, 3, isOwnedByCurrentSeller),
            _buildNotesCell(rowControllers[i][4], rowFocusNodes[i][4], i, 4,
                isOwnedByCurrentSeller),
          ],
        ),
      );
    }

    if (rowControllers.length >= 1) {
      contentRows.add(
        TableRow(
          decoration: BoxDecoration(color: Colors.yellow[50]),
          children: [
            _buildEmptyCell(),
            TableComponents.buildTotalCell(totalReceivedController),
            TableComponents.buildTotalCell(totalPaidController),
            _buildEmptyCell(),
            _buildEmptyCell(),
          ],
        ),
      );
    }

    return Table(
      columnWidths: {
        0: FlexColumnWidth(0.09),
        1: FlexColumnWidth(0.18),
        2: FlexColumnWidth(0.18),
        3: FlexColumnWidth(0.37),
        4: FlexColumnWidth(0.18),
      },
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: contentRows,
    );
  }

  Widget _buildTableCell(TextEditingController controller, FocusNode focusNode,
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    bool isSerialField = colIndex == 0;

    Widget cell = TableBuilder.buildTableCell(
      controller: controller,
      focusNode: focusNode,
      isSerialField: isSerialField,
      isNumericField: false,
      rowIndex: rowIndex,
      colIndex: colIndex,
      scrollToField: _scrollToField,
      onFieldSubmitted: (value, rIndex, cIndex) =>
          _handleFieldSubmitted(value, rIndex, cIndex),
      onFieldChanged: (value, rIndex, cIndex) =>
          _handleFieldChanged(value, rIndex, cIndex),
      inputFormatters: null,
    );

    if (!isOwnedByCurrentSeller) {
      return IgnorePointer(
        child: Opacity(
          opacity: 0.7,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
            ),
            child: cell,
          ),
        ),
      );
    }

    return cell;
  }

  Widget _buildReceivedCell(
      TextEditingController controller,
      FocusNode focusNode,
      int rowIndex,
      int colIndex,
      bool isOwnedByCurrentSeller) {
    Widget cell = Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        enabled:
            isOwnedByCurrentSeller && rowControllers[rowIndex][2].text.isEmpty,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          border: InputBorder.none,
          hintText: '0.00',
        ),
        inputFormatters: [
          TableComponents.PositiveDecimalInputFormatter(),
          FilteringTextInputFormatter.deny(RegExp(r'\.\d{3,}')),
        ],
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            _showAccountTypeDialog(rowIndex);
          } else {
            FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
          }
        },
        onChanged: (value) {
          _hasUnsavedChanges = true;
          if (value.isNotEmpty && mounted) {
            setState(() {
              rowControllers[rowIndex][2].text = '';
            });
          }
          _calculateAllTotals();
        },
      ),
    );

    if (!isOwnedByCurrentSeller) {
      return IgnorePointer(
        child: Opacity(
          opacity: 0.7,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
            ),
            child: cell,
          ),
        ),
      );
    }

    return cell;
  }

  Widget _buildPaidCell(TextEditingController controller, FocusNode focusNode,
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    Widget cell = Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        enabled:
            isOwnedByCurrentSeller && rowControllers[rowIndex][1].text.isEmpty,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          border: InputBorder.none,
          hintText: '0.00',
        ),
        inputFormatters: [
          TableComponents.PositiveDecimalInputFormatter(),
          FilteringTextInputFormatter.deny(RegExp(r'\.\d{3,}')),
        ],
        onSubmitted: (value) {
          _showAccountTypeDialog(rowIndex);
        },
        onChanged: (value) {
          _hasUnsavedChanges = true;
          if (value.isNotEmpty && mounted) {
            setState(() {
              rowControllers[rowIndex][1].text = '';
            });
          }
          _calculateAllTotals();
        },
      ),
    );

    if (!isOwnedByCurrentSeller) {
      return IgnorePointer(
        child: Opacity(
          opacity: 0.7,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
            ),
            child: cell,
          ),
        ),
      );
    }

    return cell;
  }

  // تحديث خلية الحساب لدعم كلا النوعين
  Widget _buildAccountCell(
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    // 1. استخدام دالة التحقق المركزية
    final bool canEdit = _canEditRow(rowIndex);

    final String accountType = accountTypeValues[rowIndex];
    final TextEditingController accountNameController =
        rowControllers[rowIndex][3];
    final FocusNode accountNameFocusNode = rowFocusNodes[rowIndex][3];

    Widget cellContent;

    // إذا كان نوع الحساب تم اختياره (زبون، مورد)
    if (accountType.isNotEmpty) {
      cellContent = Container(
        padding: const EdgeInsets.all(1),
        constraints: const BoxConstraints(minHeight: 25),
        child: Row(
          children: [
            // جزء عرض نوع الحساب وقابلية تغييره
            Expanded(
              flex: 2,
              child: InkWell(
                // لا يسمح بفتح الديالوج إلا إذا كان يملك الصلاحية
                onTap: canEdit ? () => _showAccountTypeDialog(rowIndex) : null,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _getAccountTypeColor(accountType),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(2),
                    // تمييز خلفية النوع المختار
                    color: _getAccountTypeColor(accountType).withOpacity(0.1),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Center(
                    child: Text(
                      accountType,
                      style: TextStyle(
                        fontSize: 10,
                        color: _getAccountTypeColor(accountType),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // جزء إدخال اسم الحساب (مع دعم الاقتراحات)
            Expanded(
              flex: 5,
              child: TextField(
                controller: accountNameController,
                focusNode: accountNameFocusNode,
                textAlign: TextAlign.right,
                // قفل أو فتح الحقل بناءً على الصلاحية
                enabled: canEdit,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  border: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 0.5),
                  ),
                  hintText: _getAccountHintText(accountType),
                  hintStyle: const TextStyle(fontSize: 10, color: Colors.grey),
                  isDense: true,
                ),
                onSubmitted: (value) =>
                    _handleFieldSubmitted(value, rowIndex, colIndex),
                onChanged: (value) {
                  _hasUnsavedChanges = true;
                  // تفعيل الاقتراحات حسب النوع
                  if (accountType == 'زبون') {
                    _updateCustomerSuggestions(rowIndex);
                  } else if (accountType == 'مورد') {
                    _updateSupplierSuggestions(rowIndex);
                  }
                },
              ),
            ),
          ],
        ),
      );
    } else {
      // عرض زر "اختر" في حال كان السجل جديداً ولم يحدد نوعه بعد
      cellContent = InkWell(
        onTap: canEdit ? () => _showAccountTypeDialog(rowIndex) : null,
        child: Container(
          margin: const EdgeInsets.all(2),
          height: 25,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(3),
            color: Colors.grey[50],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('اختر النوع',
                  style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
              Icon(Icons.arrow_drop_down, size: 14, color: Colors.blueGrey),
            ],
          ),
        ),
      );
    }

    // 2. تطبيق الحماية البصرية والمنطقية النهائية (مثل شاشة الاستلام)
    if (!canEdit) {
      return IgnorePointer(
        child: Opacity(
          opacity: 0.6, // جعل السجل باهتاً للدلالة على أنه للقراءة فقط
          child: Container(
            color: Colors.grey[100], // خلفية رمادية خفيفة
            child: cellContent,
          ),
        ),
      );
    }

    return cellContent;
  }

  Widget _buildEmptyCell() {
    return Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: TextEditingController()..text = '',
        focusNode: FocusNode(),
        enabled: false,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildNotesCell(TextEditingController controller, FocusNode focusNode,
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    Widget cell = Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        enabled: isOwnedByCurrentSeller,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          border: InputBorder.none,
          hintText: '...',
        ),
        onSubmitted: (value) {
          if (isOwnedByCurrentSeller) {
            _addNewRow();
            if (rowControllers.isNotEmpty) {
              final newRowIndex = rowControllers.length - 1;
              FocusScope.of(context)
                  .requestFocus(rowFocusNodes[newRowIndex][1]);
            }
          }
        },
        onChanged: (value) {
          if (isOwnedByCurrentSeller) {
            _hasUnsavedChanges = true;
          }
        },
      ),
    );

    if (!isOwnedByCurrentSeller) {
      return IgnorePointer(
        child: Opacity(
          opacity: 0.7,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
            ),
            child: cell,
          ),
        ),
      );
    }

    return cell;
  }

  Color _getAccountTypeColor(String accountType) {
    switch (accountType) {
      case 'زبون':
        return Colors.green;
      case 'مورد':
        return Colors.blue;
      case 'مصروف':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getAccountHintText(String accountType) {
    switch (accountType) {
      case 'زبون':
        return 'اسم الزبون';
      case 'مورد':
        return 'اسم المورد';
      case 'مصروف':
        return 'نوع المصروف';
      default:
        return '...';
    }
  }

  void _handleFieldSubmitted(String value, int rowIndex, int colIndex) {
    if (!_canEditRow(rowIndex)) {
      return;
    }

    if (colIndex == 0) {
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][1]);
    } else if (colIndex == 1) {
      if (value.isNotEmpty) {
        _showAccountTypeDialog(rowIndex);
      } else {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
      }
    } else if (colIndex == 2) {
      _showAccountTypeDialog(rowIndex);
    } else if (colIndex == 3) {
      // 1. الأولوية القصوى: هل يوجد اقتراح زبون مطابق؟
      if (accountTypeValues[rowIndex] == 'زبون' &&
          _customerSuggestions.isNotEmpty) {
        _selectCustomerSuggestion(_customerSuggestions[0], rowIndex);
        // *** إضافة: الحفظ الفوري بعد اختيار الاقتراح ***
        _saveCurrentRecord(silent: true, reloadAfterSave: false);
        return;
      }

      // 2. الأولوية القصوى: هل يوجد اقتراح مورد مطابق؟
      if (accountTypeValues[rowIndex] == 'مورد' &&
          _supplierSuggestions.isNotEmpty) {
        _selectSupplierSuggestion(_supplierSuggestions[0], rowIndex);
        // *** إضافة: الحفظ الفوري بعد اختيار الاقتراح ***
        _saveCurrentRecord(silent: true, reloadAfterSave: false);
        return;
      }

      // *** تعديل: المنطق الرئيسي لتحديث الرصيد عند ضغط Enter ***
      // 3. إذا لم يتم اختيار أي اقتراح، نقوم بالحفظ ثم تحديث شريط الرصيد
      _saveCurrentRecord(silent: true, reloadAfterSave: false).then((_) {
        // نستدعي هذه الدالة بعد اكتمال الحفظ لضمان قراءة الرصيد المحدث
        if (mounted) {
          _fetchAndCalculateBalance(rowIndex);
        }
      });

      if (value.trim().isNotEmpty && value.trim().length > 1) {
        // لا يتم حفظ الأسماء الجديدة - فقط الزبائن والموردين المخزنين مسبقاً مقبولون
        // if (accountTypeValues[rowIndex] == 'زبون') {
        //   _saveCustomerToIndex(value);
        // } else if (accountTypeValues[rowIndex] == 'مورد') {
        //   _saveSupplierToIndex(value);
        // }
      }

      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][4]);
    } else if (colIndex == 4) {
      _addNewRow();
      if (rowControllers.isNotEmpty) {
        final newRowIndex = rowControllers.length - 1;
        FocusScope.of(context).requestFocus(rowFocusNodes[newRowIndex][1]);
      }
    }
  }

  void _handleFieldChanged(String value, int rowIndex, int colIndex) {
    if (!_canEditRow(rowIndex)) {
      return;
    }

    setState(() {
      _hasUnsavedChanges = true;

      if (colIndex == 0) {
        for (int i = 0; i < rowControllers.length; i++) {
          rowControllers[i][0].text = (i + 1).toString();
        }
      }

      if (colIndex == 1 && value.isNotEmpty) {
        rowControllers[rowIndex][2].text = '';
        _calculateAllTotals();
      } else if (colIndex == 2 && value.isNotEmpty) {
        rowControllers[rowIndex][1].text = '';
        _calculateAllTotals();
      }
    });
  }

  void _showAccountTypeDialog(int rowIndex) {
    if (!_canEditRow(rowIndex)) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'اختر نوع الحساب',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.0,
              runSpacing: 8.0,
              children: accountTypeOptions.map((option) {
                return ChoiceChip(
                  label: Text(option),
                  selected: option == accountTypeValues[rowIndex],
                  selectedColor: _getAccountTypeColor(option),
                  backgroundColor: Colors.grey[200],
                  onSelected: (bool selected) {
                    if (selected) {
                      Navigator.pop(context);
                      _onAccountTypeSelected(option, rowIndex);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _onAccountTypeCancelled(rowIndex);
              },
              child: const Text('إلغاء'),
            ),
          ],
        );
      },
    );
  }

  void _onAccountTypeSelected(String value, int rowIndex) {
    setState(() {
      accountTypeValues[rowIndex] = value;
      _hasUnsavedChanges = true;

      // إخفاء الاقتراحات عند تغيير نوع الحساب
      _customerSuggestions = [];
      _supplierSuggestions = [];
      _activeCustomerRowIndex = null;
      _activeSupplierRowIndex = null;

      if (value.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
            _scrollToField(rowIndex, 3);
          }
        });
      }
    });
  }

  void _onAccountTypeCancelled(int rowIndex) {
    if (rowControllers[rowIndex][1].text.isNotEmpty) {
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][1]);
    } else if (rowControllers[rowIndex][2].text.isNotEmpty) {
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 220, 145, 5),
        foregroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 0,

        // ── Leading: رجوع + PDF ──
        leadingWidth: 88,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.pop(context),
              tooltip: 'رجوع',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),

        // ── Title: عنوان + رصيد كلي أو شريط اقتراحات ──
        title: _showFullScreenSuggestions && _getSuggestionsByType().isNotEmpty
            ? SuggestionsBanner(
                suggestions: _getSuggestionsByType(),
                type: _currentSuggestionType,
                currentRowIndex: _getCurrentRowIndexByType(),
                scrollController: _horizontalSuggestionsController,
                onSelect: (val, idx) {
                  if (_currentSuggestionType == 'customer')
                    _selectCustomerSuggestion(val, idx);
                  if (_currentSuggestionType == 'supplier')
                    _selectSupplierSuggestion(val, idx);
                },
                onClose: () =>
                    _toggleFullScreenSuggestions(type: '', show: false),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'الصندوق - ${widget.selectedDate}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('الرصيد الكلي: ',
                            style:
                                TextStyle(fontSize: 11, color: Colors.white70)),
                        Text(
                          (_grandTotalReceived - _grandTotalPaid)
                              .toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: (_grandTotalReceived - _grandTotalPaid) >= 0
                                ? Colors.lightGreenAccent
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        // ── Actions: حفظ + تقويم ──
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, size: 22),
            tooltip: 'تصدير PDF',
            onPressed: () => _generateAndSharePdf(),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_month, size: 22),
            tooltip: 'فتح يومية سابقة',
            padding: const EdgeInsets.all(8),
            onSelected: (selectedDate) async {
              if (selectedDate != widget.selectedDate) {
                if (_hasUnsavedChanges) {
                  final shouldSave = await _showUnsavedChangesDialog();
                  if (shouldSave) {
                    await _saveCurrentRecord(silent: true);
                  }
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BoxScreen(
                      sellerName: widget.sellerName,
                      selectedDate: selectedDate,
                      storeName: widget.storeName,
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
          const SizedBox(width: 4),
        ],
      ),
      body: _buildMainContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewRow,
        backgroundColor: const Color.fromARGB(255, 220, 145, 5),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
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
            floating: false,
            delegate: _StickyTableHeaderDelegate(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                ),
                child: _buildTableHeader(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizontalScrollController,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width,
                  ),
                  child: _buildTableContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCurrentRecord(
      {bool silent = false, bool reloadAfterSave = true}) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    // 1. تجميع السجلات الحالية من الواجهة
    final List<BoxTransaction> allTransFromUI = [];
    for (int i = 0; i < rowControllers.length; i++) {
      final controllers = rowControllers[i];
      if (controllers[1].text.isNotEmpty ||
          controllers[2].text.isNotEmpty ||
          controllers[3].text.isNotEmpty) {
        final t = BoxTransaction(
          serialNumber: (allTransFromUI.length + 1).toString(),
          received: controllers[1].text,
          paid: controllers[2].text,
          accountType: accountTypeValues[i],
          accountName: controllers[3].text.trim(),
          notes: controllers[4].text,
          sellerName: sellerNames[i],
        );
        allTransFromUI.add(t);
      }
    }

    // 2. منطق تحديث الأرصدة الجديد (الإلغاء ثم التطبيق)
    Map<String, double> customerBalanceChanges = {};
    Map<String, double> supplierBalanceChanges = {};
    final existingDoc =
        await _storageService.loadBoxDocumentForDate(widget.selectedDate);

    // الخطوة أ: إلغاء أثر جميع معاملات الصندوق القديمة لهذا البائع
    if (existingDoc != null) {
      for (var oldTrans in existingDoc.transactions) {
        if (oldTrans.sellerName == widget.sellerName &&
            oldTrans.accountName.isNotEmpty) {
          double oldReceived = double.tryParse(oldTrans.received) ?? 0;
          double oldPaid = double.tryParse(oldTrans.paid) ?? 0;

          if (oldTrans.accountType == 'زبون') {
            // معادلة الزبون: الرصيد يتأثر بـ (المدفوع له - المقبوض منه)
            // للإلغاء، نطرح هذا التأثير
            double effect = oldPaid - oldReceived;
            customerBalanceChanges[oldTrans.accountName] =
                (customerBalanceChanges[oldTrans.accountName] ?? 0) - effect;
          } else if (oldTrans.accountType == 'مورد') {
            // معادلة المورد: الرصيد يتأثر بـ (المقبوض منه - المدفوع له)
            // للإلغاء، نطرح هذا التأثير
            double effect = oldReceived - oldPaid;
            supplierBalanceChanges[oldTrans.accountName] =
                (supplierBalanceChanges[oldTrans.accountName] ?? 0) - effect;
          }
        }
      }
    }

    // الخطوة ب: تطبيق أثر جميع معاملات الصندوق الجديدة من الواجهة
    for (var newTrans in allTransFromUI) {
      if (newTrans.sellerName == widget.sellerName &&
          newTrans.accountName.isNotEmpty) {
        double newReceived = double.tryParse(newTrans.received) ?? 0;
        double newPaid = double.tryParse(newTrans.paid) ?? 0;

        if (newTrans.accountType == 'زبون') {
          double effect = newPaid - newReceived;
          customerBalanceChanges[newTrans.accountName] =
              (customerBalanceChanges[newTrans.accountName] ?? 0) + effect;
        } else if (newTrans.accountType == 'مورد') {
          double effect = newReceived - newPaid;
          supplierBalanceChanges[newTrans.accountName] =
              (supplierBalanceChanges[newTrans.accountName] ?? 0) + effect;
        }
      }
    }

    // 3. بناء الوثيقة النهائية للحفظ
    double tReceived = allTransFromUI.fold(
        0, (sum, t) => sum + (double.tryParse(t.received) ?? 0));
    double tPaid = allTransFromUI.fold(
        0, (sum, t) => sum + (double.tryParse(t.paid) ?? 0));

    final documentToSave = BoxDocument(
      recordNumber: serialNumber,
      date: widget.selectedDate,
      sellerName: "Multiple Sellers", // الاسم العام للملف
      storeName: widget.storeName,
      dayName: dayName,
      transactions: allTransFromUI,
      totals: {
        'totalReceived': tReceived.toStringAsFixed(2),
        'totalPaid': tPaid.toStringAsFixed(2),
      },
    );

    // 4. الحفظ في الملف وتحديث الأرصدة
    final success = await _storageService.saveBoxDocument(documentToSave);

    if (success) {
      // تطبيق التغييرات الصافية على أرصدة الزبائن والموردين
      for (var entry in customerBalanceChanges.entries) {
        if (entry.value != 0) {
          await _customerIndexService.updateCustomerBalance(
              entry.key, entry.value);
        }
      }
      for (var entry in supplierBalanceChanges.entries) {
        if (entry.value != 0) {
          await _supplierIndexService.updateSupplierBalance(
              entry.key, entry.value);
        }
      }

      setState(() => _hasUnsavedChanges = false);
      if (reloadAfterSave) {
        await _loadOrCreateJournal();
      }
    }

    setState(() => _isSaving = false);
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'تم الحفظ بنجاح' : 'فشل الحفظ'),
          backgroundColor: success ? Colors.green : Colors.red));
    }
  }

  Future<bool> _showUnsavedChangesDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('تغييرات غير محفوظة'),
            content: const Text(
              'هناك تغييرات غير محفوظة. هل تريد حفظها قبل الانتقال؟',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('تجاهل'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _loadJournalNumber() async {
    try {
      final journalNumber =
          await _storageService.getJournalNumberForDate(widget.selectedDate);
      setState(() {
        serialNumber = journalNumber;
        _currentJournalNumber = journalNumber;
      });
    } catch (e) {
      setState(() {
        serialNumber = '1';
        _currentJournalNumber = '1';
      });
    }
  }

  // تحديث اقتراحات الزبائن
  void _updateCustomerSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][3].text;
    if (query.length >= 1 && accountTypeValues[rowIndex] == 'زبون') {
      final suggestions =
          await getEnhancedSuggestions(_customerIndexService, query);
      setState(() {
        _customerSuggestions = suggestions;
        _activeCustomerRowIndex = rowIndex;
        _toggleFullScreenSuggestions(
            type: 'customer', show: suggestions.isNotEmpty);
      });
    } else {
      setState(() {
        _customerSuggestions = [];
        _activeCustomerRowIndex = null;
      });
    }
  }

// تحديث اقتراحات الموردين
  void _updateSupplierSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][3].text;
    if (query.length >= 1 && accountTypeValues[rowIndex] == 'مورد') {
      final suggestions =
          await getEnhancedSuggestions(_supplierIndexService, query);
      setState(() {
        _supplierSuggestions = suggestions;
        _activeSupplierRowIndex = rowIndex;
        _toggleFullScreenSuggestions(
            type: 'supplier', show: suggestions.isNotEmpty);
      });
    } else {
      // إخفاء الاقتراحات إذا كان الحقل فارغاً أو نوع الحساب ليس مورد
      setState(() {
        _supplierSuggestions = [];
        _activeSupplierRowIndex = null;
      });
    }
  }

  // اختيار اقتراح للزبون
  void _selectCustomerSuggestion(String suggestion, int rowIndex) {
    setState(() {
      _customerSuggestions = [];
      _activeCustomerRowIndex = null;
      _showFullScreenSuggestions = false;
      _currentSuggestionType = '';
    });

    // 1. وضع الاسم الكامل في الحقل
    rowControllers[rowIndex][3].text = suggestion;
    _hasUnsavedChanges = true;

    // لا يتم حفظ الاسم في الفهرس - فقط استقبال الاقتراحات المخزنة مسبقاً
    // if (suggestion.trim().length > 1) {
    //   _saveCustomerToIndex(suggestion);
    // }

    // 2. تحديث شريط الرصيد فوراً بناءً على الاسم الكامل الجديد
    _fetchAndCalculateBalance(rowIndex);

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][4]);
      }
    });
  }

  // اختيار اقتراح للمورد
  void _selectSupplierSuggestion(String suggestion, int rowIndex) {
    setState(() {
      _supplierSuggestions = [];
      _activeSupplierRowIndex = null;
      _showFullScreenSuggestions = false;
      _currentSuggestionType = '';
    });

    // 1. وضع الاسم الكامل في الحقل
    rowControllers[rowIndex][3].text = suggestion;
    _hasUnsavedChanges = true;

    // لا يتم حفظ الاسم في الفهرس - فقط استقبال الاقتراحات المخزنة مسبقاً
    // if (suggestion.trim().length > 1) {
    //   _saveSupplierToIndex(suggestion);
    // }

    // 2. تحديث شريط الرصيد فوراً بناءً على الاسم الكامل الجديد
    _fetchAndCalculateBalance(rowIndex);

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][4]);
      }
    });
  }

/*
  // حفظ الزبون في الفهرس - معطل: لا يُسمح بإضافة أسماء جديدة، فقط استقبال المخزن
  void _saveCustomerToIndex(String customer) {
    // final trimmedCustomer = customer.trim();
    // if (trimmedCustomer.length > 1) {
    //   _customerIndexService.saveCustomer(trimmedCustomer);
    // }
  }

  */
  // حفظ المورد في الفهرس - معطل: لا يُسمح بإضافة أسماء جديدة، فقط استقبال المخزن
  /*
  void _saveSupplierToIndex(String supplier) {
    // final trimmedSupplier = supplier.trim();
    // if (trimmedSupplier.length > 1) {
    //   _supplierIndexService.saveSupplier(trimmedSupplier);
    // }
  }
    */
  void _toggleFullScreenSuggestions(
      {required String type, required bool show}) {
    if (mounted) {
      setState(() {
        _showFullScreenSuggestions = show;
        _currentSuggestionType = show ? type : '';
      });
    }
  }

  List<String> _getSuggestionsByType() {
    switch (_currentSuggestionType) {
      case 'supplier':
        return _supplierSuggestions;
      case 'customer':
        return _customerSuggestions;
      default:
        return [];
    }
  }

  int _getCurrentRowIndexByType() {
    switch (_currentSuggestionType) {
      case 'supplier':
        return _activeSupplierRowIndex ?? -1;
      case 'customer':
        return _activeCustomerRowIndex ?? -1;
      default:
        return -1;
    }
  }

// 1. دالة التحقق من حالة الأدمن (تُستدعى في initState)
  Future<void> _checkAdminStatus() async {
    final settings = AppSettingsService();
    final adminSeller = await settings.getString('admin_seller');
    if (mounted) {
      setState(() {
        _isAdmin = (widget.sellerName == adminSeller);
      });
    }
  }

  bool _canEditRow(int rowIndex) {
    if (rowIndex >= sellerNames.length) {
      return true; // صف جديد لم يحفظ بعد
    }
    if (_isAdmin) {
      return true; // الأدمن يمكنه تعديل أي شيء
    }
    // البائع العادي يعدل سجلاته فقط
    return sellerNames[rowIndex] == widget.sellerName;
  }

  Future<void> _fetchAndCalculateBalance(int rowIndex) async {
    final String type = accountTypeValues[rowIndex];
    final String name = rowControllers[rowIndex][3].text.trim();

    // القيم الحالية للصف الذي نعمل عليه (آخر عملية إدخال)
    final double currentReceived =
        double.tryParse(rowControllers[rowIndex][1].text) ?? 0;
    final double currentPaid =
        double.tryParse(rowControllers[rowIndex][2].text) ?? 0;

    if (name.isEmpty) {
      return;
    }

    try {
      // جلب الرصيد الحقيقي مباشرة من الفهرس - بدون أي حسابات تراكمية
      double realBalance = 0;

      if (type == 'زبون') {
        final customers = await _customerIndexService.getAllCustomersWithData();
        final customerData = customers.values.firstWhere(
          (c) => c.name.toLowerCase() == name.toLowerCase(),
          orElse: () => CustomerData(name: name, balance: 0.0, startDate: ''),
        );
        realBalance = customerData.balance;
      } else if (type == 'مورد') {
        final supplierData = await _supplierIndexService.getSupplierData(name);
        realBalance = supplierData?.balance ?? 0.0;
      } else {
        return;
      }

      // حساب الباقي بناءً على آخر عملية إدخال فقط + الرصيد الحقيقي
      double remaining = 0;

      if (type == 'زبون') {
        // معادلة الزبون: الرصيد الحقيقي - مقبوض (سدد) + مدفوع (دين جديد)
        remaining = realBalance - currentReceived + currentPaid;
      } else if (type == 'مورد') {
        // معادلة المورد: الرصيد الحقيقي + مقبوض (دين علينا) - مدفوع (سداد منا)
        remaining = realBalance + currentReceived - currentPaid;
      }

      if (mounted) {
        setState(() {
          _lastFetchedBalance = realBalance; // الرصيد الحقيقي من الفهرس
          _calculatedRemaining =
              remaining; // الباقي = آخر عملية + الرصيد الحقيقي
          _lastAccountName = name;
        });
      }
    } catch (e) {
      debugPrint("Error calculating balance: $e");
    }
  }

  Widget _buildBalanceBar() {
    if (_lastFetchedBalance == null || _lastAccountName.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // اسم الحساب
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'الحساب',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
                Text(
                  _lastAccountName.length > 14
                      ? '${_lastAccountName.substring(0, 14)}...'
                      : _lastAccountName,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
            Container(width: 1, height: 30, color: Colors.white24),
            // الرصيد الحالي
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('الرصيد',
                    style: TextStyle(fontSize: 10, color: Colors.white70)),
                Text(
                  _lastFetchedBalance?.toStringAsFixed(2) ?? '0.00',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
            Container(width: 1, height: 30, color: Colors.white24),
            // الباقي المتوقع
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('الباقي',
                    style: TextStyle(fontSize: 10, color: Colors.white70)),
                Text(
                  _calculatedRemaining?.toStringAsFixed(2) ?? '0.00',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: (_calculatedRemaining ?? 0) >= 0
                        ? Colors.lightGreenAccent
                        : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // مستطيل الرصيد مباشرةً تحت الـ AppBar
        _buildBalanceBar(),
        // الجدول الرئيسي
        Expanded(
          child: _buildTableWithStickyHeader(),
        ),
      ],
    );
  }

  // --- دالة توليد PDF والمشاركة (BoxScreen) ---
  Future<void> _generateAndSharePdf() async {
    try {
      final pdf = pw.Document();

      var arabicFont;
      try {
        final fontData =
            await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
        arabicFont = pw.Font.ttf(fontData);
      } catch (e) {
        arabicFont = pw.Font.courier();
      }

      final PdfColor headerColor =
          PdfColor.fromInt(0xFFF3A30D); // برتقالي AppBar
      final PdfColor headerTextColor = PdfColors.white;
      final PdfColor rowEvenColor = PdfColors.white;
      final PdfColor rowOddColor =
          PdfColor.fromInt(0xFFFFF3E0); // برتقالي فاتح جداً
      final PdfColor borderColor = PdfColor.fromInt(0xFFE0E0E0);
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
          build: (pw.Context context) {
            return [
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  children: [
                    pw.Center(
                        child: pw.Text('يومية صندوق رقم /$serialNumber/',
                            style: pw.TextStyle(
                                fontSize: 16, fontWeight: pw.FontWeight.bold))),
                    pw.Center(
                        child: pw.Text(
                            'تاريخ ${widget.selectedDate} - البائع ${widget.sellerName}',
                            style: const pw.TextStyle(
                                fontSize: 12, color: PdfColors.grey700))),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border:
                          pw.TableBorder.all(color: borderColor, width: 0.5),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(4),
                        2: const pw.FlexColumnWidth(2),
                        3: const pw.FlexColumnWidth(2),
                        4: const pw.FlexColumnWidth(1),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: headerColor),
                          children: [
                            _buildPdfHeaderCell('ملاحظات', headerTextColor),
                            _buildPdfHeaderCell('الحساب', headerTextColor),
                            _buildPdfHeaderCell('مدفوع', headerTextColor),
                            _buildPdfHeaderCell('مقبوض', headerTextColor),
                            _buildPdfHeaderCell('ت', headerTextColor),
                          ],
                        ),
                        ...rowControllers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final controllers = entry.value;
                          if (controllers[1].text.isEmpty &&
                              controllers[2].text.isEmpty &&
                              controllers[3].text.isEmpty) {
                            return pw.TableRow(
                                children: List.filled(5, pw.SizedBox()));
                          }
                          final color =
                              index % 2 == 0 ? rowEvenColor : rowOddColor;
                          String accountInfo = controllers[3].text;
                          if (accountTypeValues[index].isNotEmpty) {
                            accountInfo =
                                "(${accountTypeValues[index]}) " + accountInfo;
                          }
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(color: color),
                            children: [
                              _buildPdfCell(controllers[4].text),
                              _buildPdfCell(accountInfo),
                              _buildPdfCell(controllers[2].text),
                              _buildPdfCell(controllers[1].text),
                              _buildPdfCell(controllers[0].text),
                            ],
                          );
                        }).toList(),
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFF90CAF9)),
                          children: [
                            _buildPdfCell(''),
                            _buildPdfCell('المجموع', isBold: true),
                            _buildPdfCell(totalPaidController.text,
                                isBold: true),
                            _buildPdfCell(totalReceivedController.text,
                                isBold: true),
                            _buildPdfCell(''),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      // *** التعديل الهام هنا: استبدال / بـ - لضمان صحة اسم الملف ***
      final safeDate = widget.selectedDate.replaceAll('/', '-');
      final file = File("${output.path}/يومية_صندوق_$safeDate.pdf");

      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)],
          text: 'يومية صندوق ${widget.selectedDate}');
    } catch (e) {
      debugPrint("PDF Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('حدث خطأ أثناء تصدير PDF: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  pw.Widget _buildPdfHeaderCell(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              color: color, fontSize: 10, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildPdfCell(String text, {bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}

class _StickyTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTableHeaderDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => 32.0;

  @override
  double get minExtent => 32.0;

  @override
  bool shouldRebuild(_StickyTableHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
