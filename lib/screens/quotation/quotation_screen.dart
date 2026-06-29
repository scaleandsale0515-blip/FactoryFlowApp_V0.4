import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../services/excel_service.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';
import '../billing/billing_screen.dart' show kServiceUnits;

class QuotationScreen extends StatefulWidget {
  const QuotationScreen({super.key});
  @override
  State<QuotationScreen> createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen> {
  List<Map<String, dynamic>> _quotes = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    final q = await db.query('quotations', orderBy: 'date DESC, created_at DESC');
    if (mounted) setState(() { _quotes = q; _loading = false; });
  }

  Future<void> _delete(Map<String, dynamic> q) async {
    final confirm = await showConfirmDialog(context);
    if (!confirm) return;
    final db = await DatabaseHelper.instance.database;
    await db.delete('quotation_items', where: 'quotation_id=?', whereArgs: [q['id']]);
    await db.delete('quotations', where: 'id=?', whereArgs: [q['id']]);
    _load();
  }

  Future<void> _advanceStatus(Map<String, dynamic> q) async {
    final db = await DatabaseHelper.instance.database;
    final cur = q['status'] as String? ?? 'Draft';
    final next = cur == 'Draft' ? 'Sent' : 'Approved';
    await db.update('quotations', {'status': next}, where: 'id=?', whereArgs: [q['id']]);
    _load();
  }

  Future<void> _convertToInvoice(Map<String, dynamic> q) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Convert to Invoice'),
      content: const Text('This will create a new invoice with same details. Continue?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.get('cancel'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Convert')),
      ],
    ));
    if (confirm != true) return;

    final db = await DatabaseHelper.instance.database;
    final items = await db.query('quotation_items', where: 'quotation_id=?', whereArgs: [q['id']]);
    final now = DateTime.now().toIso8601String();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM invoices')) ?? 0;
    final invNum = 'INV-${DateFormat('yyyyMM').format(DateTime.now())}-${(count + 1).toString().padLeft(3, '0')}';

    final invId = await db.insert('invoices', {
      'invoice_number': invNum, 'customer_id': q['customer_id'],
      'customer_name': q['customer_name'], 'customer_phone': q['customer_phone'],
      'date': dateStr, 'subtotal': q['subtotal'], 'gst_percent': q['gst_percent'],
      'gst_amount': q['gst_amount'], 'total': q['total'], 'affect_stock': 1,
      'notes': q['notes'], 'created_at': now,
    });
    final newItems = <Map<String, dynamic>>[];
    for (var item in items) {
      await db.insert('invoice_items', {
        'invoice_id': invId, 'service_name': item['service_name'],
        'quantity': item['quantity'], 'unit': item['unit'],
        'rate': item['rate'], 'amount': item['amount'],
      });
      newItems.add(item);
    }
    final inv = (await db.query('invoices', where: 'id=?', whereArgs: [invId])).first;
    await ExcelService.instance.appendInvoice(inv, newItems);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice $invNum created!')));
    }
  }

  Color _statusColor(String s) => s == 'Approved' ? AppColors.success : s == 'Sent' ? AppColors.info : Colors.grey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get('quotations'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _quotes.isEmpty
              ? EmptyState(message: AppStrings.get('no_data'))
              : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), itemCount: _quotes.length,
                  itemBuilder: (ctx, i) {
                    final q = _quotes[i];
                    final status = q['status'] as String? ?? 'Draft';
                    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(q['quote_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status)))),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(q['customer_name'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.grey)), const Spacer(), Text(fmtDate(q['date']), style: const TextStyle(fontSize: 12, color: Colors.grey))]),
                      const Divider(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('₹${(q['total'] as num).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.success)),
                        Wrap(spacing: 2, children: [
                          if (status != 'Approved') IconButton(onPressed: () => _advanceStatus(q), icon: const Icon(Icons.upgrade_rounded, size: 18, color: AppColors.accent), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30), tooltip: status == 'Draft' ? 'Mark Sent' : 'Mark Approved'),
                          IconButton(onPressed: () => _convertToInvoice(q), icon: const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.warning), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30), tooltip: AppStrings.get('convert_invoice')),
                          IconButton(onPressed: () async {
                            final items = await DatabaseHelper.instance.database.then((db) => db.query('quotation_items', where: 'quotation_id=?', whereArgs: [q['id']]));
                            await PdfService.instance.generateAndShare(doc: q, items: items, isQuotation: true, context: context);
                          }, icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.primary), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
                          IconButton(onPressed: () => _delete(q), icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.danger), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
                        ]),
                      ]),
                    ])));
                  }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddQuotationScreen())); _load(); },
        backgroundColor: AppColors.primary, icon: const Icon(Icons.add),
        label: Text(AppStrings.get('new_quote'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class AddQuotationScreen extends StatefulWidget {
  const AddQuotationScreen({super.key});
  @override
  State<AddQuotationScreen> createState() => _AddQuotationScreenState();
}

class _AddQuotationScreenState extends State<AddQuotationScreen> {
  DateTime _date = DateTime.now();
  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _customers = [], _items = [];
  bool _gstEnabled = false;
  double _gstPercent = 18;
  bool _saving = false;
  final _custPhoneCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _loadCustomers(); _addItem(); }

  Future<void> _loadCustomers() async {
    final db = await DatabaseHelper.instance.database;
    setState(() {});
    _customers = await db.query('customers', orderBy: 'name');
    setState(() {});
  }

  void _addItem() => setState(() => _items.add({
    'service_ctrl': TextEditingController(text: AppStrings.get('default_service')),
    'unit': 'Sq Ft', 'qty_ctrl': TextEditingController(), 'rate_ctrl': TextEditingController(),
  }));

  double get _subtotal => _items.fold(0.0, (s, i) => s + (double.tryParse(i['qty_ctrl'].text) ?? 0) * (double.tryParse(i['rate_ctrl'].text) ?? 0));
  double get _gstAmount => _gstEnabled ? _subtotal * _gstPercent / 100 : 0;
  double get _total => _subtotal + _gstAmount;

  Future<void> _save() async {
    if (_customer == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer'))); return; }
    setState(() => _saving = true);
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM quotations')) ?? 0;
    final qNum = 'QT-${DateFormat('yyyyMM').format(_date)}-${(count + 1).toString().padLeft(3, '0')}';

    final qId = await db.insert('quotations', {
      'quote_number': qNum, 'customer_id': _customer!['id'], 'customer_name': _customer!['name'],
      'customer_phone': _custPhoneCtrl.text, 'date': dateStr, 'subtotal': _subtotal,
      'gst_percent': _gstEnabled ? _gstPercent : 0, 'gst_amount': _gstAmount, 'total': _total,
      'status': 'Draft', 'created_at': now,
    });

    final savedItems = <Map<String, dynamic>>[];
    for (var item in _items) {
      final qty = double.tryParse(item['qty_ctrl'].text) ?? 0;
      final rate = double.tryParse(item['rate_ctrl'].text) ?? 0;
      final svc = item['service_ctrl'].text.trim();
      if (qty <= 0 || svc.isEmpty) continue;
      final data = {'quotation_id': qId, 'service_name': svc, 'quantity': qty, 'unit': item['unit'], 'rate': rate, 'amount': qty * rate};
      await db.insert('quotation_items', data);
      savedItems.add(data);
    }
    final q = (await db.query('quotations', where: 'id=?', whereArgs: [qId])).first;
    await ExcelService.instance.appendQuotation(q, savedItems);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get('new_quote'))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppDatePicker(date: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 14),
        AppDropdown<Map<String, dynamic>>(label: AppStrings.get('customer'), value: _customer, items: _customers, itemLabel: (c) => c['name'] as String, onChanged: (c) => setState(() => _customer = c)),
        const SizedBox(height: 14),
        TextField(controller: _custPhoneCtrl, decoration: const InputDecoration(labelText: 'Customer Phone (Optional)'), keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(AppStrings.get('service'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 16), label: Text(AppStrings.get('add')), style: TextButton.styleFrom(foregroundColor: AppColors.primary)),
        ]),
        ..._items.asMap().entries.map((e) {
          final item = e.value;
          final amount = (double.tryParse(item['qty_ctrl'].text) ?? 0) * (double.tryParse(item['rate_ctrl'].text) ?? 0);
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: AppColors.darkBorder), borderRadius: BorderRadius.circular(10)), child: Column(children: [
            Row(children: [
              Expanded(child: TextField(controller: item['service_ctrl'], decoration: InputDecoration(labelText: AppStrings.get('service_name'), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
              IconButton(onPressed: () => setState(() => _items.removeAt(e.key)), icon: const Icon(Icons.close, size: 18, color: AppColors.danger), padding: EdgeInsets.zero),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: item['qty_ctrl'], decoration: const InputDecoration(labelText: 'Qty', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 6),
              Expanded(child: DropdownButtonFormField<String>(value: item['unit'], decoration: const InputDecoration(labelText: 'Unit', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: kServiceUnits.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => item['unit'] = v))),
              const SizedBox(width: 6),
              Expanded(child: TextField(controller: item['rate_ctrl'], decoration: const InputDecoration(labelText: 'Rate ₹', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 6),
              SizedBox(width: 60, child: Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success, fontSize: 12), textAlign: TextAlign.right)),
            ]),
          ]));
        }),
        const SizedBox(height: 10),
        SwitchListTile(value: _gstEnabled, onChanged: (v) => setState(() => _gstEnabled = v), title: Text(AppStrings.get('gst')), activeColor: AppColors.primary, contentPadding: EdgeInsets.zero),
        if (_gstEnabled) Wrap(spacing: 8, children: [5,12,18,28].map((p) => GestureDetector(onTap: () => setState(() => _gstPercent = p.toDouble()), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: _gstPercent == p ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _gstPercent == p ? AppColors.primary : AppColors.darkBorder)), child: Text('$p%', style: TextStyle(color: _gstPercent == p ? Colors.white : Colors.grey, fontWeight: FontWeight.w600))))).toList()),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          StatRow(label: AppStrings.get('subtotal'), value: '₹${_subtotal.toStringAsFixed(0)}'),
          if (_gstEnabled) StatRow(label: 'GST ${_gstPercent.toInt()}%', value: '₹${_gstAmount.toStringAsFixed(0)}', valueColor: AppColors.warning),
          const Divider(),
          StatRow(label: AppStrings.get('total'), value: '₹${_total.toStringAsFixed(0)}', valueColor: AppColors.success),
        ]))),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(AppStrings.get('save')))),
        const SizedBox(height: 30),
      ])),
    );
  }
}
