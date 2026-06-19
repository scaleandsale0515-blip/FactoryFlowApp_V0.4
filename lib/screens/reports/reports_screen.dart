import 'dart:io';
import 'package:excel/excel.dart' as ex;
//import 'package:flutter/material.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/database_helper.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

num _num(double v) => v;

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _gf = 'Month';

  List<String> _labels = [];
  List<double> _salesD = [],
      _purchD = [],
      _panelD = [],
      _colD = [],
      _transD = [];

  bool _loading = true, _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final db = await DatabaseHelper.instance.database;

    final labels = <String>[],
        sales = <double>[],
        purch = <double>[],
        panel = <double>[],
        col = <double>[],
        trans = <double>[];

    final count = _gf == 'Week'
        ? 7
        : _gf == 'Year'
            ? 5
            : 6;

    for (int i = 0; i < count; i++) {
      String label, like;

      if (_gf == 'Week') {
        final d =
            DateTime.now().subtract(Duration(days: count - 1 - i));
        label = DateFormat('E').format(d);
        like = DateFormat('yyyy-MM-dd').format(d);
      } else if (_gf == 'Year') {
        final y = DateTime.now().year - (count - 1 - i);
        label = '$y';
        like = '$y%';
      } else {
        final m = DateTime(
            DateTime.now().year,
            DateTime.now().month - (count - 1 - i));
        label = DateFormat('MMM').format(m);
        like = '${DateFormat('yyyy-MM').format(m)}%';
      }

      labels.add(label);

      sales.add(((await db.rawQuery(
                  'SELECT COALESCE(SUM(total),0) as t FROM invoices WHERE date LIKE ?',
                  [like]))
              .first['t'] as num)
          .toDouble());

      purch.add(((await db.rawQuery(
                  'SELECT COALESCE(SUM(total_amount),0) as t FROM purchases WHERE date LIKE ?',
                  [like]))
              .first['t'] as num)
          .toDouble());

      panel.add(((await db.rawQuery(
                  'SELECT COALESCE(SUM(pi.quantity),0) as t FROM production p JOIN production_items pi ON p.id=pi.production_id WHERE pi.product_name="Panel" AND p.date LIKE ?',
                  [like]))
              .first['t'] as num)
          .toDouble());

      col.add(((await db.rawQuery(
                  'SELECT COALESCE(SUM(pi.quantity),0) as t FROM production p JOIN production_items pi ON p.id=pi.production_id WHERE pi.product_name="Column" AND p.date LIKE ?',
                  [like]))
              .first['t'] as num)
          .toDouble());

      trans.add(((await db.rawQuery(
                  'SELECT COALESCE(SUM(rent),0) as t FROM transport WHERE date LIKE ?',
                  [like]))
              .first['t'] as num)
          .toDouble());
    }

    if (mounted) {
      setState(() {
        _labels = labels;
        _salesD = sales;
        _purchD = purch;
        _panelD = panel;
        _colD = col;
        _transD = trans;
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);

    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['Report'];

      sheet.appendRow([
         'Period',
         'Sales ₹',
         'Purchase ₹',
         'Panel Production',
         'Column Production',
         'Transport Cost ₹',
      ]);

      for (int i = 0; i < _labels.length; i++) {
        sheet.appendRow([
           _labels[i],
          _num(_salesD[i]),
          _num(_purchD[i]),
          _num(_panelD[i]),
          _num(_colD[i]),
          _num(_transD[i]),
        ]);
      }

      excel.delete('Sheet1');

      final dir = await getTemporaryDirectory();
      final fileName =
          'FactoryFlow_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';

      final file = File('${dir.path}/$fileName');
      final encoded = excel.encode();

      if (encoded != null) {
        await file.writeAsBytes(encoded);
        await Share.shareXFiles([XFile(file.path)],
            text: 'FactoryFlow Report');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }

    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child:
              CircularProgressIndicator(
                   color: AppColors.primary,
                  );
                 }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2))
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(_exporting
                  ? 'Exporting...'
                  : AppStrings.get('export_excel')),
            ),
          ),
        ]),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: ['Week', 'Month', 'Year']
              .map((f) => GestureDetector(
                    onTap: () {
                      setState(() => _gf = f);
                      _load();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _gf == f
                            ? AppColors.primary.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                          color: _gf == f
                              ? AppColors.primary
                              : AppColors.darkBorder,
                        ),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _gf == f
                              ? AppColors.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ]),
    );
  }
}
