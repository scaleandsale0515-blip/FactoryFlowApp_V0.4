import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../services/excel_service.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

const List<String> kServiceUnits = ['Sq Ft', 'Running Ft', 'RMT'];

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  List<Map<String, dynamic>> _all = [], _filtered = [];
  bool _loading = true;
  DateTime? _fs, _fe;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    final r = await db.query('invoices', orderBy: 'date DESC, created_at DESC');
    if (mounted) setState(() { _all = r; _applyFilter(); _loading = false; });
  }

  void _applyFilter() {
    _filtered = _all.where((inv) {
      if (_fs == null && _fe == null) return true;
      try { final d = DateTime.parse(inv['date'].toString()); if (_fs != null && d.isBefore(_fs!)) return false; if (_fe != null && d.isAfter(_fe!.add(const Duration(days: 1)))) return false; return true; } catch (_) { return true; }
    }).toList();
  }

  Future<void> _delete(Map<String, dynamic> inv) async {
    final confirm = await showConfirmDialog(context);
    if (!confirm) return;
    final db = await DatabaseHelper.instance.database;
    await db.delete('invoice_items', where: 'invoice_id=?', whereArgs: [inv['id']]);
    await db.delete('invoices', where: 'id=?', whereArgs: [inv['id']]);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: DateRangeFilter(onChanged: (s, e) { setState(() { _fs = s; _fe = e; _applyFilter(); }); })),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _filtered.isEmpty ? EmptyState(message: AppStrings.get('no_data'))
              : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 4, 16, 80), itemCount: _filtered.length,
                  itemBuilder: (ctx, i) => _InvCard(inv: _filtered[i],
                    onView: () async {
                      final db = await DatabaseHelper.instance.database;
                      final items = await db.query('invoice_items', where: 'invoice_id=?', whereArgs: [_filtered[i]['id']]);
                      if (context.mounted) await PdfService.instance.generateAndShare(doc: _filtered[i], items: items, isQuotation: false, context: context);
                    },
                    onDelete: () => _delete(_filtered[i]))),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddInvoiceScreen())); _load(); },
        backgroundColor: AppColors.primary, icon: const Icon(Icons.add),
        label: Text(AppStrings.get('create_invoice'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _InvCard extends StatelessWidget {
  final Map<String, dynamic> inv; final VoidCallback onView, onDelete;
  const _InvCard({required this.inv, required this.onView, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final affectStock = inv['affect_stock'] == 1;
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Text(inv['invoice_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
          const SizedBox(width: 8),
          InfoChip(label: affectStock ? 'STOCK↓' : 'NO STOCK', color: affectStock ? AppColors.danger : AppColors.accent),
        ]),
        Text(fmtDate(inv['date']), style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
      ]),
      const SizedBox(height: 6),
      Row(children: [const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(inv['customer_name'] ?? '', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87))]),
      const Divider(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((inv['gst_percent'] as num) > 0) Text('GST ${inv['gst_percent']}%: ₹${(inv['gst_amount'] as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text('₹${(inv['total'] as num).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.success)),
        ]),
        Row(children: [
          IconButton(onPressed: onView, icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: AppColors.primary), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.danger), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
        ]),
      ]),
    ])));
  }
}

class AddInvoiceScreen extends StatefulWidget {
  final Map<String, dynamic>? fromQuotation;
  const AddInvoiceScreen({super.key, this.fromQuotation});
  @override State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  DateTime _date = DateTime.now();
  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _customers = [], _items = [];
  bool _gstOn = false, _affectStock = true, _saving = false;
  double _gstPct = 18;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    if (widget.fromQuotation != null) _loadFromQuote();
    else _addItem();
  }

  Future<void> _loadCustomers() async {
    final db = await DatabaseHelper.instance.database;
    _customers = await db.query('customers', orderBy: 'name');
    setState(() {});
  }

  Future<void> _loadFromQuote() async {
    final q = widget.fromQuotation!;
    final db = await DatabaseHelper.instance.database;
    _notesCtrl.text = q['notes'] ?? '';
    _gstOn = (q['gst_percent'] as num) > 0;
    _gstPct = (q['gst_percent'] as num).toDouble();
    final cust = await db.query('customers', where: 'id=?', whereArgs: [q['customer_id']]);
    if (cust.isNotEmpty) setState(() => _customer = cust.first);
    final its = await db.query('quotation_items', where: 'quotation_id=?', whereArgs: [q['id']]);
    setState(() => _items = its.map((i) => {'service_ctrl': TextEditingController(text: i['service_name']?.toString() ?? ''), 'unit': i['unit']?.toString() ?? '', 'qty_ctrl': TextEditingController(text: i['quantity']?.toString() ?? ''), 'rate_ctrl': TextEditingController(text: i['rate']?.toString() ?? ''), }).toList());
  }

  void _addItem() => setState(() => _items.add({'service_ctrl': TextEditingController(text: AppStrings.get('default_service')), 'unit': 'Sq Ft', 'qty_ctrl': TextEditingController(), 'rate_ctrl': TextEditingController()}));

  double get _subtotal => _items.fold(0.0, (s, i) => s + (double.tryParse(i['qty_ctrl'].text) ?? 0) * (double.tryParse(i['rate_ctrl'].text) ?? 0));
  double get _gstAmt => _gstOn ? _subtotal * _gstPct / 100 : 0;
  double get _total => _subtotal + _gstAmt;

  Future<void> _save() async {
    if (_customer == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer'))); return; }
    setState(() => _saving = true);
    final db = await DatabaseHelper.instance.database;
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    final now = DateTime.now().toIso8601String();
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM invoices')) ?? 0;
    final invNum = 'INV-${DateFormat('yyyyMM').format(_date)}-${(count + 1).toString().padLeft(3, '0')}';

    final invId = await db.insert('invoices', {
      'invoice_number': invNum, 'customer_id': _customer!['id'],
      'customer_name': _customer!['name'], 'customer_phone': _customer!['phone'] ?? '',
      'date': dateStr, 'subtotal': _subtotal,
      'gst_percent': _gstOn ? _gstPct : 0, 'gst_amount': _gstAmt,
      'total': _total, 'affect_stock': _affectStock ? 1 : 0,
      'notes': _notesCtrl.text, 'created_at': now,
    });

    for (var item in _items) {
      final qty = double.tryParse(item['qty_ctrl'].text) ?? 0;
      final rate = double.tryParse(item['rate_ctrl'].text) ?? 0;
      if (qty <= 0) continue;
      await db.insert('invoice_items', {'invoice_id': invId, 'service_name': item['service_ctrl'].text.trim(), 'quantity': qty, 'unit': item['unit'], 'rate': rate, 'amount': qty * rate});
    }

    final inv = (await db.query('invoices', where: 'id=?', whereArgs: [invId])).first;
    final items = await db.query('invoice_items', where: 'invoice_id=?', whereArgs: [invId]);
    await ExcelService.instance.appendInvoice(inv, items);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get('create_invoice'))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppDatePicker(date: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AppDropdown<Map<String, dynamic>>(label: AppStrings.get('customer'), value: _customer, items: _customers, itemLabel: (c) => c['name'] as String, onChanged: (c) => setState(() => _customer = c))),
          const SizedBox(width: 10),
          IconButton.filled(onPressed: () async { await _addCustDialog(); _loadCustomers(); }, icon: const Icon(Icons.add, size: 20), style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(AppStrings.get('service'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 16), label: const Text('Add Row'), style: TextButton.styleFrom(foregroundColor: AppColors.primary)),
        ]),
        ..._items.asMap().entries.map((e) => _ServiceRow(item: e.value, onRemove: () => setState(() => _items.removeAt(e.key)), onChanged: () => setState(() {}))),
        const SizedBox(height: 16),
        // GST
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppStrings.get('gst'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)), Switch(value: _gstOn, onChanged: (v) => setState(() => _gstOn = v), activeColor: AppColors.primary)]),
          if (_gstOn) ...[const SizedBox(height: 10), Row(children: [5.0, 12.0, 18.0, 28.0].map((pct) => Expanded(child: GestureDetector(onTap: () => setState(() => _gstPct = pct), child: Container(margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: _gstPct == pct ? AppColors.primary.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _gstPct == pct ? AppColors.primary : AppColors.darkBorder)), child: Center(child: Text('${pct.toInt()}%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _gstPct == pct ? AppColors.primary : Colors.grey))))))).toList())],
        ]))),
        const SizedBox(height: 14),
        // Affect Stock
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppStrings.get('affect_stock'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4), const Text('Turn OFF for outsourced/borrowed material', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: GestureDetector(onTap: () => setState(() => _affectStock = true), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: _affectStock ? AppColors.danger.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _affectStock ? AppColors.danger : AppColors.darkBorder)), child: Center(child: Text(AppStrings.get('yes'), style: TextStyle(fontWeight: FontWeight.w700, color: _affectStock ? AppColors.danger : Colors.grey)))))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(onTap: () => setState(() => _affectStock = false), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: !_affectStock ? AppColors.accent.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: !_affectStock ? AppColors.accent : AppColors.darkBorder)), child: Center(child: Text(AppStrings.get('no'), style: TextStyle(fontWeight: FontWeight.w700, color: !_affectStock ? AppColors.accent : Colors.grey)))))),
          ]),
        ]))),
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          StatRow(label: AppStrings.get('subtotal'), value: '₹${_subtotal.toStringAsFixed(0)}'),
          if (_gstOn) StatRow(label: 'GST ${_gstPct.toInt()}%', value: '₹${_gstAmt.toStringAsFixed(0)}', valueColor: AppColors.warning),
          const Divider(),
          StatRow(label: AppStrings.get('total'), value: '₹${_total.toStringAsFixed(0)}', valueColor: AppColors.success),
        ]))),
        const SizedBox(height: 14),
        TextField(controller: _notesCtrl, decoration: InputDecoration(labelText: AppStrings.get('notes')), maxLines: 2),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(AppStrings.get('generate_invoice')))),
        const SizedBox(height: 30),
      ])),
    );
  }

  Future<void> _addCustDialog() async {
    final nc = TextEditingController(), pc = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Customer'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nc, decoration: InputDecoration(labelText: AppStrings.get('name'))), const SizedBox(height: 10), TextField(controller: pc, decoration: InputDecoration(labelText: AppStrings.get('phone')), keyboardType: TextInputType.phone)]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel'))), ElevatedButton(onPressed: () async { if (nc.text.trim().isEmpty) return; final db = await DatabaseHelper.instance.database; await db.insert('customers', {'name': nc.text.trim(), 'phone': pc.text.trim(), 'created_at': DateTime.now().toIso8601String()}); if (ctx.mounted) Navigator.pop(ctx); }, child: Text(AppStrings.get('save')))],
    ));
  }
}

class _ServiceRow extends StatefulWidget {
  final Map<String, dynamic> item; final VoidCallback onRemove, onChanged;
  const _ServiceRow({required this.item, required this.onRemove, required this.onChanged});
  @override State<_ServiceRow> createState() => _ServiceRowState();
}
class _ServiceRowState extends State<_ServiceRow> {
  @override
  Widget build(BuildContext context) {
    final amt = (double.tryParse(widget.item['qty_ctrl'].text) ?? 0) * (double.tryParse(widget.item['rate_ctrl'].text) ?? 0);
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: AppColors.darkBorder), borderRadius: BorderRadius.circular(10)), child: Column(children: [
      Row(children: [
        Expanded(child: TextField(controller: widget.item['service_ctrl'], decoration: const InputDecoration(labelText: 'Service Name', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
        IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.close, size: 18, color: AppColors.danger), padding: EdgeInsets.zero),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: widget.item['qty_ctrl'], decoration: const InputDecoration(labelText: 'Qty', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) { setState(() {}); widget.onChanged(); })),
        const SizedBox(width: 6),
        Expanded(child: DropdownButtonFormField<String>(value: widget.item['unit'], decoration: const InputDecoration(labelText: 'Unit', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: kServiceUnits.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) { setState(() => widget.item['unit'] = v); widget.onChanged(); })),
        const SizedBox(width: 6),
        Expanded(child: TextField(controller: widget.item['rate_ctrl'], decoration: const InputDecoration(labelText: 'Rate ₹', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), keyboardType: TextInputType.number, onChanged: (_) { setState(() {}); widget.onChanged(); })),
        const SizedBox(width: 6),
        SizedBox(width: 65, child: Text('₹${amt.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success, fontSize: 13), textAlign: TextAlign.right)),
      ]),
    ]));
  }
}
