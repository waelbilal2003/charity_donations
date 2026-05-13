import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../services/customer_index_service.dart';
import '../services/sales_storage_service.dart';
import '../services/box_storage_service.dart';

class CustomerPreferencesScreen extends StatefulWidget {
  final CustomerData customer;
  final String selectedDate;

  const CustomerPreferencesScreen(
      {Key? key, required this.customer, required this.selectedDate})
      : super(key: key);

  @override
  _CustomerPreferencesScreenState createState() =>
      _CustomerPreferencesScreenState();
}

class _CustomerPreferencesScreenState extends State<CustomerPreferencesScreen> {
  final SalesStorageService _salesService = SalesStorageService();
  final BoxStorageService _boxService = BoxStorageService();

  bool _isLoading = true;

  /// جميع السجلات المحمّلة من قاعدة البيانات — لا تُمسّ أبداً
  List<Map<String, String>> _allTransactions = <Map<String, String>>[];

  /// السجلات المعروضة في الواجهة فعلياً
  List<Map<String, String>> _visibleTransactions = <Map<String, String>>[];

  /// نطاق الفلتر — null يعني لا فلتر مُطبَّق
  DateTime? _filterFrom;
  DateTime? _filterTo;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  // ─── تحميل البيانات ───────────────────────────────────────────────

  Future<void> _loadDetails() async {
    final selectedDate = _parseDate(widget.selectedDate);
    // نحمّل من بداية السنة لأن الفلتر سيتولى التحديد
    final firstDayOfYear = DateTime(selectedDate.year, 1, 1);

    final List<Map<String, String>> transactions = <Map<String, String>>[];

    for (int i = 0; i <= selectedDate.difference(firstDayOfYear).inDays; i++) {
      final currentDate = firstDayOfYear.add(Duration(days: i));
      final dateString =
          '${currentDate.year}/${currentDate.month}/${currentDate.day}';

      // ① مسحوبات من يومية المبيعات
      final doc = await _salesService.loadDocumentForDate(dateString);
      if (doc != null) {
        for (var t in doc.transactions) {
          if (t.workerName == widget.customer.name &&
              t.paymentValue.isNotEmpty) {
            transactions.add({
              'date': dateString,
              'value': t.paymentValue,
              'notes': t.notes,
              'source': 'sales',
            });
          }
        }
      }

      // ② مدفوع من يومية الصندوق (نوع الحساب = زبون واسمه مطابق)
      final boxDoc = await _boxService.loadBoxDocumentForDate(dateString);
      if (boxDoc != null) {
        for (var t in boxDoc.transactions) {
          if (t.accountType == 'زبون' &&
              t.accountName == widget.customer.name) {
            // المدفوع
            if (t.paid.isNotEmpty &&
                t.paid != '0' &&
                t.paid != '0.0' &&
                t.paid != '0.00') {
              transactions.add({
                'date': dateString,
                'value': t.paid,
                'notes': t.notes.isNotEmpty ? t.notes : 'مدفوع من الصندوق',
                'source': 'box_paid',
              });
            }
            // المقبوض
            if (t.received.isNotEmpty &&
                t.received != '0' &&
                t.received != '0.0' &&
                t.received != '0.00') {
              transactions.add({
                'date': dateString,
                'value': t.received,
                'notes': t.notes.isNotEmpty ? t.notes : 'مقبوض من الصندوق',
                'source': 'box_received',
              });
            }
          }
        }
      }
    }

    // ترتيب بالتاريخ
    transactions.sort((a, b) {
      final da = _parseDateFromString(a['date'] ?? '');
      final db = _parseDateFromString(b['date'] ?? '');
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });

    if (!mounted) return;

    setState(() {
      _allTransactions = transactions;
      _isLoading = false;
    });

    _applyFilter();
  }

  // ─── الفلتر ───────────────────────────────────────────────────────

  void _applyFilter() {
    if (!mounted) return;
    setState(() {
      if (_filterFrom == null && _filterTo == null) {
        _visibleTransactions = List<Map<String, String>>.from(_allTransactions);
      } else {
        _visibleTransactions = _allTransactions.where((t) {
          final d = _parseDateFromString(t['date'] ?? '');
          if (d == null) return false;
          final day = DateTime(d.year, d.month, d.day);
          if (_filterFrom != null && day.isBefore(_filterFrom!)) return false;
          if (_filterTo != null && day.isAfter(_filterTo!)) return false;
          return true;
        }).toList();
      }
    });
  }

  void _clearFilter() {
    setState(() {
      _filterFrom = null;
      _filterTo = null;
    });
    _applyFilter();
  }

  // ─── نافذة اختيار نطاق التاريخ (picker مصغّر) ───────────────────

  Future<void> _showDateRangeDialog() async {
    final now = DateTime.now();
    DateTime tempFrom = _filterFrom ?? now;
    DateTime tempTo = _filterTo ?? now;

    DateTime _clampDay(int y, int m, int d) {
      final max = DateUtils.getDaysInMonth(y, m);
      return DateTime(y, m, d > max ? max : d);
    }

    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];

    Widget miniPicker({
      required String label,
      required String display,
      required VoidCallback onUp,
      required VoidCallback onDown,
      required Color color,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 28,
                  width: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.arrow_drop_up,
                        size: 22, color: Colors.green[600]),
                    onPressed: onUp,
                  ),
                ),
                SizedBox(
                  height: 26,
                  child: Center(
                    child: Text(display,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(
                  height: 28,
                  width: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.arrow_drop_down,
                        size: 22, color: Colors.red[600]),
                    onPressed: onDown,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget datePicker({
      required String sectionLabel,
      required DateTime date,
      required Color color,
      required void Function(DateTime) onChanged,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 13, color: color),
              const SizedBox(width: 4),
              Text(sectionLabel,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 8),
              Text(
                '${date.year}/${date.month}/${date.day}',
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              miniPicker(
                label: 'اليوم',
                display: date.day.toString(),
                color: color,
                onUp: () =>
                    onChanged(_clampDay(date.year, date.month, date.day + 1)),
                onDown: () =>
                    onChanged(_clampDay(date.year, date.month, date.day - 1)),
              ),
              miniPicker(
                label: 'الشهر',
                display: months[date.month - 1],
                color: color,
                onUp: () {
                  final m = date.month < 12 ? date.month + 1 : 1;
                  onChanged(_clampDay(date.year, m, date.day));
                },
                onDown: () {
                  final m = date.month > 1 ? date.month - 1 : 12;
                  onChanged(_clampDay(date.year, m, date.day));
                },
              ),
              miniPicker(
                label: 'السنة',
                display: date.year.toString(),
                color: color,
                onUp: () =>
                    onChanged(_clampDay(date.year + 1, date.month, date.day)),
                onDown: () =>
                    onChanged(_clampDay(date.year - 1, date.month, date.day)),
              ),
            ],
          ),
        ],
      );
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              title: const Row(
                children: [
                  Icon(Icons.date_range, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('فلترة بالتاريخ',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  datePicker(
                    sectionLabel: 'من تاريخ',
                    date: tempFrom,
                    color: Colors.teal[700]!,
                    onChanged: (d) => setDialogState(() => tempFrom = d),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  datePicker(
                    sectionLabel: 'إلى تاريخ',
                    date: tempTo,
                    color: Colors.teal[800]!,
                    onChanged: (d) => setDialogState(() => tempTo = d),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterFrom = null;
                      _filterTo = null;
                    });
                    _applyFilter();
                    Navigator.pop(ctx);
                  },
                  child: const Text('مسح الفلتر',
                      style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700]),
                  onPressed: () {
                    if (tempFrom.isAfter(tempTo)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('تاريخ البداية يجب أن يكون قبل النهاية'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _filterFrom = tempFrom;
                      _filterTo = tempTo;
                    });
                    _applyFilter();
                    Navigator.pop(ctx);
                  },
                  child: const Text('تطبيق',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ─── PDF ──────────────────────────────────────────────────────────

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

      final PdfColor headerColor = PdfColor.fromInt(0xFF00796B);
      final PdfColor headerTextColor = PdfColors.white;
      final PdfColor rowEvenColor = PdfColors.white;
      final PdfColor rowOddColor = PdfColor.fromInt(0xFFB2DFDB);
      final PdfColor borderColor = PdfColor.fromInt(0xFFE0E0E0);

      final displayList = List<Map<String, String>>.from(_visibleTransactions);

      // الزبون: مبيعات + صندوق مدفوع = يُجمع | صندوق مقبوض = يُطرح
      final double totalTransactions = displayList.fold<double>(0.0, (sum, p) {
        final val = double.tryParse(p['value'] ?? '0') ?? 0;
        if (p['source'] == 'box_received') return sum - val;
        return sum + val;
      });

      final balanceStr = widget.customer.balance
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'\.00$'), '');
      final totalStr =
          totalTransactions.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');

      // وصف نطاق الفلتر للـ PDF
      String filterDesc = 'حتى تاريخ ${widget.selectedDate}';
      if (_filterFrom != null || _filterTo != null) {
        final from = _filterFrom != null
            ? '${_filterFrom!.year}/${_filterFrom!.month}/${_filterFrom!.day}'
            : '—';
        final to = _filterTo != null
            ? '${_filterTo!.year}/${_filterTo!.month}/${_filterTo!.day}'
            : '—';
        filterDesc = 'من $from إلى $to';
      }

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
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text(
                        'تفاصيل الزبون: ${widget.customer.name}',
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Center(
                      child: pw.Text(
                        filterDesc,
                        style: const pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey700),
                      ),
                    ),
                    pw.SizedBox(height: 14),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor, width: 0.8),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Column(
                        children: [
                          _buildPdfInfoRow(
                              'الموبايل',
                              widget.customer.mobile.isEmpty
                                  ? '—'
                                  : widget.customer.mobile),
                          pw.Divider(color: borderColor),
                          _buildPdfInfoRow('الرصيد النهائي', balanceStr),
                          pw.Divider(color: borderColor),
                          _buildPdfInfoRow(
                              'تاريخ البدء', widget.customer.startDate),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 14),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('السجلات',
                            style: pw.TextStyle(
                                fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: headerColor,
                            borderRadius: pw.BorderRadius.circular(20),
                          ),
                          child: pw.Text(
                            'المجموع: $totalStr',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    if (displayList.isEmpty)
                      pw.Center(
                        child: pw.Text('لا توجد معاملات مسجلة',
                            style: const pw.TextStyle(color: PdfColors.grey)),
                      )
                    else
                      pw.Table(
                        border:
                            pw.TableBorder.all(color: borderColor, width: 0.5),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(2),
                          1: pw.FlexColumnWidth(2),
                          2: pw.FlexColumnWidth(2),
                          3: pw.FlexColumnWidth(2),
                        },
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: headerColor),
                            children: [
                              _buildPdfHeaderCell('التاريخ', headerTextColor),
                              _buildPdfHeaderCell('المبلغ', headerTextColor),
                              _buildPdfHeaderCell('المصدر', headerTextColor),
                              _buildPdfHeaderCell('البيان', headerTextColor),
                            ],
                          ),
                          ...displayList.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final p = entry.value;
                            final color =
                                idx % 2 == 0 ? rowEvenColor : rowOddColor;
                            final sourceLabel = p['source'] == 'box_received'
                                ? 'مقبوض'
                                : p['source'] == 'box_paid'
                                    ? 'مدفوع'
                                    : 'مبيعات';
                            return pw.TableRow(
                              decoration: pw.BoxDecoration(color: color),
                              children: [
                                _buildPdfCell(p['date'] ?? ''),
                                _buildPdfCell(p['value'] ?? '', isBold: true),
                                _buildPdfCell(sourceLabel),
                                _buildPdfCell(p['notes'] ?? ''),
                              ],
                            );
                          }).toList(),
                          pw.TableRow(
                            decoration: pw.BoxDecoration(
                                color: PdfColor.fromInt(0xFF80CBC4)),
                            children: [
                              _buildPdfCell(''),
                              _buildPdfCell(totalStr, isBold: true),
                              _buildPdfCell(''),
                              _buildPdfCell('المجموع', isBold: true),
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
      final safeDate = widget.selectedDate.replaceAll('/', '-');
      final safeName = widget.customer.name.replaceAll(' ', '_');
      final file = File("${output.path}/تفاصيل_زبون_${safeName}_$safeDate.pdf");

      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)],
          text:
              'تفاصيل الزبون ${widget.customer.name} - ${widget.selectedDate}');
    } catch (e) {
      debugPrint("PDF Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('حدث خطأ أثناء تصدير PDF: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        children: [
          pw.Text('$label: ',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfHeaderCell(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              color: color, fontSize: 10, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildPdfCell(String text, {bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // الزبون: مبيعات + صندوق مدفوع = يُجمع | صندوق مقبوض = يُطرح
    final double totalVisible =
        _visibleTransactions.fold<double>(0.0, (sum, p) {
      final val = double.tryParse(p['value'] ?? '0') ?? 0;
      if (p['source'] == 'box_received') return sum - val;
      return sum + val;
    });

    final bool hasFilter = _filterFrom != null || _filterTo != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // زر الفلتر بالتاريخ
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.date_range),
                if (hasFilter)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'فلترة بالتاريخ',
            onPressed: _isLoading ? null : _showDateRangeDialog,
          ),
          // زر مسح الفلتر (يظهر فقط عند وجود فلتر)
          if (hasFilter)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'مسح الفلتر',
              onPressed: _clearFilter,
            ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير PDF',
            onPressed: _isLoading ? null : _generateAndSharePdf,
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── بطاقة المعلومات الأساسية ──────────────────
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                                Icons.phone,
                                'الموبايل',
                                widget.customer.mobile.isEmpty
                                    ? '—'
                                    : widget.customer.mobile),
                            const Divider(),
                            _buildInfoRow(
                                Icons.account_balance_wallet,
                                'الرصيد النهائي',
                                widget.customer.balance
                                    .toStringAsFixed(2)
                                    .replaceAll(RegExp(r'\.00$'), '')),
                            const Divider(),
                            _buildInfoRow(Icons.calendar_today, 'تاريخ البدء',
                                widget.customer.startDate),
                          ],
                        ),
                      ),
                    ),

                    // ── شريط الفلتر الفعّال ───────────────────────
                    if (hasFilter)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            border: Border.all(color: Colors.teal[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.filter_alt,
                                  color: Colors.teal[700], size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'الفلتر: '
                                  '${_filterFrom != null ? '${_filterFrom!.year}/${_filterFrom!.month}/${_filterFrom!.day}' : '—'}'
                                  ' ← '
                                  '${_filterTo != null ? '${_filterTo!.year}/${_filterTo!.month}/${_filterTo!.day}' : '—'}',
                                  style: TextStyle(
                                      color: Colors.teal[800], fontSize: 12),
                                ),
                              ),
                              GestureDetector(
                                onTap: _clearFilter,
                                child: Icon(Icons.close,
                                    color: Colors.teal[700], size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // ── بطاقة السجلات ─────────────────────────────
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('السجلات',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.teal[700],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'المجموع: ${totalVisible.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_visibleTransactions.isEmpty)
                              const Center(
                                  child: Text('لا توجد معاملات مسجلة',
                                      style: TextStyle(color: Colors.grey)))
                            else
                              Table(
                                border: TableBorder.all(
                                    color: Colors.grey.shade300),
                                columnWidths: const {
                                  0: FlexColumnWidth(2),
                                  1: FlexColumnWidth(2),
                                  2: FlexColumnWidth(2),
                                  3: FlexColumnWidth(2),
                                },
                                children: [
                                  TableRow(
                                    decoration:
                                        BoxDecoration(color: Colors.grey[200]),
                                    children: const [
                                      Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Text('التاريخ',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12),
                                              textAlign: TextAlign.center)),
                                      Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Text('المبلغ',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12),
                                              textAlign: TextAlign.center)),
                                      Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Text('المصدر',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12),
                                              textAlign: TextAlign.center)),
                                      Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Text('البيان',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12),
                                              textAlign: TextAlign.center)),
                                    ],
                                  ),
                                  ..._visibleTransactions.map((p) {
                                    final isBox = p['source'] == 'box_paid' ||
                                        p['source'] == 'box_received';
                                    final isBoxReceived =
                                        p['source'] == 'box_received';
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: isBox ? Colors.teal[50] : null,
                                      ),
                                      children: [
                                        Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Text(p['date'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 9),
                                                textAlign: TextAlign.center)),
                                        Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Text(p['value'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold),
                                                textAlign: TextAlign.center)),
                                        Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isBoxReceived
                                                  ? Colors.orange[100]
                                                  : isBox
                                                      ? Colors.teal[100]
                                                      : Colors.green[50],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isBoxReceived
                                                  ? 'مقبوض'
                                                  : isBox
                                                      ? 'مدفوع'
                                                      : 'مبيعات',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: isBoxReceived
                                                      ? Colors.orange[800]
                                                      : isBox
                                                          ? Colors.teal[800]
                                                          : Colors.green[700],
                                                  fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Text(p['notes'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 11),
                                                textAlign: TextAlign.center)),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal[700], size: 20),
          const SizedBox(width: 10),
          Text('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.left),
          ),
        ],
      ),
    );
  }

  DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('/');
    return DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  DateTime? _parseDateFromString(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      return DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }
}
