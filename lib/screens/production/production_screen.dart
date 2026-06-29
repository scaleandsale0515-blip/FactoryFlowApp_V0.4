import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../database/database_helper.dart';
import '../../services/stock_service.dart';
import '../../services/excel_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});
  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  List<Map<String, dynamic>> _all = [], _filtered = [];
  bool _loading = true;
  DateTime? _fs, _fe;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    final r = await db.query('production', orderBy: 'date DESC, created_at DESC');
    if (mounted) setState(() { _all = r; _applyFilter(); _loading = false; });
  }

  void _applyFilter() {
    _filtered = _all.where((p) {
      if (_fs == null && _fe == null) return true;
      try {
        final d = DateTime.parse(p['date'].toString());
        if (_fs != null && d.isBefore(_fs!)) return false;
        if (_fe != null && d.isAfter(_fe!.add(const Duration(days: 1)))) return false;
        return true;
      } catch (_) { return true; }
    }).toList();
  }

  Future<void> _delete(Map<String, dynamic> prod) async {
    final confirm = await showConfirmDialog(context);
    if (!confirm) return;
    final db = await DatabaseHelper.instance.database;
    final items = await db.query('production_items', where: 'production_id=?', whereArgs: [prod['id']]);
    await StockService.instance.applyProduction(items, reverse: true);
    await db.delete('production_items', where: 'production_id=?', whereArgs: [prod['id']]);
    await db.delete('production', where: 'id=?', whereArgs: [prod['id']]);
    await ExcelService.instance.updateStockSheet();
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
              : _filtered.isEmpty
                  ? EmptyState(message: AppStrings.get('no_data'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) => _ProdCard(
                        prod: _filtered[i],
                        onEdit: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditProductionScreen(existing: _filtered[i]))); _load(); },
                        onDelete: () => _delete(_filtered[i]),
                      ),
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditProductionScreen())); _load(); },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: Text(AppStrings.get('add_production'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ProdCard extends StatelessWidget {
  final Map<String, dynamic> prod; final VoidCallback onEdit, onDelete;
  const _ProdCard({required this.prod, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.database.then((db) => db.query('production_items', where: 'production_id=?', whereArgs: [prod['id']])),
      builder: (ctx, snap) {
        final items = snap.data ?? [];
        return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [const Icon(Icons.person_rounded, size: 16, color: AppColors.primary), const SizedBox(width: 6), Text(prod['worker_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))]),
            Text(fmtDate(prod['date']), style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
          ]),
          const SizedBox(height: 10),
          ...items.map((item) {
            final name = item['product_name'] as String;
            final size = item['size'] as String?;
            return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(size != null ? '$name ($size)' : name, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87))),
              Text('${(item['quantity'] as num).toStringAsFixed(0)} × ₹${(item['rate'] as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]));
          }),
          const Divider(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('₹${(prod['total_amount'] as num).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.success)),
            Row(children: [
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.info), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.danger), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
            ]),
          ]),
        ])));
      },
    );
  }
}

class AddEditProductionScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const AddEditProductionScreen({super.key, this.existing});
  @override
  State<AddEditProductionScreen> createState() => _AddEditProductionScreenState();
}

class _AddEditProductionScreenState extends State<AddEditProductionScreen> {
  DateTime _date = DateTime.now();
  Map<String, dynamic>? _worker;
  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _items = [];
  final _notesCtrl = TextEditingController();
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() { super.initState(); _loadWorkers(); if (widget.existing != null) _loadExisting(); else _addItem(); }

  Future<void> _loadWorkers() async {
    final db = await DatabaseHelper.instance.database;
    setState(() async => _workers = await db.query('workers', orderBy: 'name'));
    _workers = await DatabaseHelper.instance.database.then((db) => db.query('workers', orderBy: 'name'));
    setState(() {});
  }

  Future<void> _loadExisting() async {
    final e = widget.existing!;
    final db = await DatabaseHelper.instance.database;
    _date = DateTime.parse(e['date']);
    _notesCtrl.text = e['notes'] ?? '';
    _photoPath = e['photo_path'];
    final w = await db.query('workers', where: 'id=?', whereArgs: [e['worker_id']]);
    if (w.isNotEmpty) setState(() => _worker = w.first);
    final its = await db.query('production_items', where: 'production_id=?', whereArgs: [e['id']]);
    setState(() => _items = its.map((i) => {'product': i['product_name'], 'size': i['size'], 'qty_ctrl': TextEditingController(text: i['quantity'].toString()), 'rate_ctrl': TextEditingController(text: i['rate'].toString())}).toList());
  }

  void _addItem() => setState(() => _items.add({'product': 'Panel', 'size': null, 'qty_ctrl': TextEditingController(), 'rate_ctrl': TextEditingController()}));

  double get _total => _items.fold(0.0, (s, i) => s + (double.tryParse(i['qty_ctrl'].text) ?? 0) * (double.tryParse(i['rate_ctrl'].text) ?? 0));

  Future<void> _save() async {
    if (_worker == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('select_worker')))); return; }
    setState(() => _saving = true);
    final db = await DatabaseHelper.instance.database;
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    final now = DateTime.now().toIso8601String();
    final isEdit = widget.existing != null;

    if (isEdit) {
      final oldItems = await db.query('production_items', where: 'production_id=?', whereArgs: [widget.existing!['id']]);
      await StockService.instance.applyProduction(oldItems, reverse: true);
      await db.delete('production_items', where: 'production_id=?', whereArgs: [widget.existing!['id']]);
      await db.update('production', {'date': dateStr, 'worker_id': _worker!['id'], 'worker_name': _worker!['name'], 'total_amount': _total, 'notes': _notesCtrl.text, 'photo_path': _photoPath}, where: 'id=?', whereArgs: [widget.existing!['id']]);
      final pid = widget.existing!['id'] as int;
      for (var item in _items) {
        final q = double.tryParse(item['qty_ctrl'].text) ?? 0; final r = double.tryParse(item['rate_ctrl'].text) ?? 0;
        if (q <= 0) continue;
        await db.insert('production_items', {'production_id': pid, 'product_name': item['product'], 'size': item['size'], 'quantity': q, 'rate': r, 'amount': q * r});
      }
      final newItems = await db.query('production_items', where: 'production_id=?', whereArgs: [pid]);
      await StockService.instance.applyProduction(newItems);
    } else {
      final pid = await db.insert('production', {'date': dateStr, 'worker_id': _worker!['id'], 'worker_name': _worker!['name'], 'total_amount': _total, 'notes': _notesCtrl.text, 'photo_path': _photoPath, 'created_at': now});
      for (var item in _items) {
        final q = double.tryParse(item['qty_ctrl'].text) ?? 0; final r = double.tryParse(item['rate_ctrl'].text) ?? 0;
        if (q <= 0) continue;
        await db.insert('production_items', {'production_id': pid, 'product_name': item['product'], 'size': item['size'], 'quantity': q, 'rate': r, 'amount': q * r});
      }
      final prod = (await db.query('production', where: 'id=?', whereArgs: [pid])).first;
      final items = await db.query('production_items', where: 'production_id=?', whereArgs: [pid]);
      await StockService.instance.applyProduction(items);
      await ExcelService.instance.appendProduction(prod, items);
    }
    //await ExcelService.instance.updateStockSheet();
    //if (mounted) Navigator.pop(context);
  await ExcelService.instance.updateStockSheet();
  if (!mounted) return;

  // ✅ STOP LOADING
  setState(() => _saving = false);

  // ✅ SHOW SUCCESS MESSAGE
  ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text("Saved Successfully"),
    backgroundColor: Colors.green,
    duration: Duration(seconds: 2),
   ),
  );

  // ✅ GO BACK AFTER SMALL DELAY (important!)
  Future.delayed(const Duration(milliseconds: 100), () {
  if (mounted) Navigator.pop(context, true);
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing != null ? AppStrings.get('edit_production') : AppStrings.get('add_production'))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppDatePicker(date: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AppDropdown<Map<String, dynamic>>(label: AppStrings.get('worker'), value: _worker, items: _workers, itemLabel: (w) => w['name'] as String, onChanged: (w) => setState(() => _worker = w))),
          const SizedBox(width: 10),
          IconButton.filled(onPressed: () async { await _addWorkerDialog(); _loadWorkers(); }, icon: const Icon(Icons.add, size: 20), style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(AppStrings.get('product'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 16), label: Text(AppStrings.get('add')), style: TextButton.styleFrom(foregroundColor: AppColors.primary)),
        ]),
        ..._items.asMap().entries.map((e) => _ItemRow(item: e.value, onRemove: () => setState(() => _items.removeAt(e.key)), onChanged: () => setState(() {}))),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.3))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(AppStrings.get('total_amount'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          Text('₹${_total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary)),
        ])),
        const SizedBox(height: 14),
        TextField(controller: _notesCtrl, decoration: InputDecoration(labelText: AppStrings.get('notes')), maxLines: 2),
        const SizedBox(height: 14),
        _PhotoPickerWidget(path: _photoPath, onPicked: (p) => setState(() => _photoPath = p)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(AppStrings.get('save')))),
        const SizedBox(height: 30),
      ])),
    );
  }

  Future<void> _addWorkerDialog() async {
    final nc = TextEditingController(), pc = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(AppStrings.get('add_worker')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nc, decoration: InputDecoration(labelText: AppStrings.get('name'))),
        const SizedBox(height: 10),
        TextField(controller: pc, decoration: InputDecoration(labelText: AppStrings.get('phone')), keyboardType: TextInputType.phone),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel'))),
        ElevatedButton(onPressed: () async { if (nc.text.trim().isEmpty) return; final db = await DatabaseHelper.instance.database; await db.insert('workers', {'name': nc.text.trim(), 'phone': pc.text.trim(), 'created_at': DateTime.now().toIso8601String()}); if (ctx.mounted) Navigator.pop(ctx); }, child: Text(AppStrings.get('save')))],
    ));
  }
}

class _ItemRow extends StatefulWidget {
  final Map<String, dynamic> item; final VoidCallback onRemove, onChanged;
  const _ItemRow({required this.item, required this.onRemove, required this.onChanged});
  @override State<_ItemRow> createState() => _ItemRowState();
}
class _ItemRowState extends State<_ItemRow> {
  @override
  Widget build(BuildContext context) {
    final isCol = widget.item['product'] == 'Column';
    final amt = (double.tryParse(widget.item['qty_ctrl'].text) ?? 0) * (double.tryParse(widget.item['rate_ctrl'].text) ?? 0);
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: AppColors.darkBorder), borderRadius: BorderRadius.circular(10)), child: Column(children: [
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(value: widget.item['product'], decoration: const InputDecoration(labelText: 'Product', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: ['Panel','Column'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) { setState(() { widget.item['product'] = v; widget.item['size'] = v == 'Column' ? '8 ft' : null; }); widget.onChanged(); })),
        if (isCol) ...[const SizedBox(width: 8), Expanded(child: DropdownButtonFormField<String>(value: widget.item['size'] ?? '8 ft', decoration: const InputDecoration(labelText: 'Size', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: ['6 ft','7 ft','8 ft','10 ft','12 ft'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) { setState(() => widget.item['size'] = v); widget.onChanged(); }))],
        IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.close, size: 18, color: AppColors.danger), padding: EdgeInsets.zero),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: widget.item['qty_ctrl'], decoration: const InputDecoration(labelText: 'Qty', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), keyboardType: TextInputType.number, onChanged: (_) { setState(() {}); widget.onChanged(); })),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: widget.item['rate_ctrl'], decoration: const InputDecoration(labelText: 'Rate ₹', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), keyboardType: TextInputType.number, onChanged: (_) { setState(() {}); widget.onChanged(); })),
        const SizedBox(width: 8),
        SizedBox(width: 65, child: Text('₹${amt.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success, fontSize: 13), textAlign: TextAlign.right)),
      ]),
    ]));
  }
}

class _PhotoPickerWidget extends StatelessWidget {
  final String? path; final Function(String?) onPicked;
  const _PhotoPickerWidget({required this.path, required this.onPicked});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async { final p = ImagePicker(); final picked = await p.pickImage(source: ImageSource.camera, imageQuality: 40); if (picked != null) onPicked(picked.path); },
      child: Container(height: 80, decoration: BoxDecoration(border: Border.all(color: AppColors.darkBorder), borderRadius: BorderRadius.circular(10)),
        child: path != null ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(path!), fit: BoxFit.cover, width: double.infinity))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt_rounded, color: Colors.grey, size: 22), const SizedBox(width: 8), Text(AppStrings.get('photo'), style: const TextStyle(color: Colors.grey))])),
    );
  }
}
