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

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});
  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  List<Map<String, dynamic>> _all = [], _filtered = [];
  bool _loading = true;
  DateTime? _fs, _fe;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    final r = await db.query('transport', orderBy: 'date DESC, created_at DESC');
    if (mounted) setState(() { _all = r; _applyFilter(); _loading = false; });
  }

  void _applyFilter() {
    _filtered = _all.where((t) {
      if (_fs == null && _fe == null) return true;
      try { final d = DateTime.parse(t['date'].toString()); if (_fs != null && d.isBefore(_fs!)) return false; if (_fe != null && d.isAfter(_fe!.add(const Duration(days: 1)))) return false; return true; } catch (_) { return true; }
    }).toList();
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    final confirm = await showConfirmDialog(context);
    if (!confirm) return;
    final db = await DatabaseHelper.instance.database;
    final items = await db.query('transport_items', where: 'transport_id=?', whereArgs: [t['id']]);
    await StockService.instance.applyTransport(items, reverse: true);
    await db.delete('transport_items', where: 'transport_id=?', whereArgs: [t['id']]);
    await db.delete('transport', where: 'id=?', whereArgs: [t['id']]);
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
              : _filtered.isEmpty ? EmptyState(message: AppStrings.get('no_data'))
              : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 4, 16, 80), itemCount: _filtered.length,
                  itemBuilder: (ctx, i) => _TransCard(t: _filtered[i],
                    onEdit: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditTransportScreen(existing: _filtered[i]))); _load(); },
                    onDelete: () => _delete(_filtered[i]))),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditTransportScreen())); _load(); },
        backgroundColor: AppColors.primary, icon: const Icon(Icons.add),
        label: Text(AppStrings.get('add_transport'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _TransCard extends StatelessWidget {
  final Map<String, dynamic> t; final VoidCallback onEdit, onDelete;
  const _TransCard({required this.t, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.database.then((db) => db.query('transport_items', where: 'transport_id=?', whereArgs: [t['id']])),
      builder: (ctx, snap) {
        final items = snap.data ?? [];
        return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [const Icon(Icons.local_shipping_rounded, size: 16, color: AppColors.warning), const SizedBox(width: 6), Text(t['transporter_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))]),
            Text(fmtDate(t['date']), style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
          ]),
          const SizedBox(height: 6),
          // Location & Client with headings
          Row(children: [
            if ((t['location'] ?? '').toString().isNotEmpty) Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('📍 ${AppStrings.get('delivery_location')}', style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(t['location'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))])),
            if ((t['client_name'] ?? '').toString().isNotEmpty) Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('👤 ${AppStrings.get('client')}', style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(t['client_name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))])),
          ]),
          if ((t['vehicle'] ?? '').toString().isNotEmpty || (t['vehicle_number'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('🚛 ${t['vehicle'] ?? ''}${(t['vehicle_number'] ?? '').toString().isNotEmpty ? ' · ${t['vehicle_number']}' : ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          const SizedBox(height: 8),
          ...items.map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(item['size'] != null ? '${item['product_name']} (${item['size']})' : item['product_name'] as String, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87))),
            Text('${(item['quantity'] as num).toStringAsFixed(0)} pcs', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]))),
          if ((t['cement_bags'] as int? ?? 0) > 0) Text('🧱 Cement: ${t['cement_bags']} bags', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if ((t['sand_qty'] as double? ?? 0) > 0) Text('🏖 Sand: ${(t['sand_qty'] as num).toStringAsFixed(1)} ${t['sand_unit']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if ((t['grit_qty'] as double? ?? 0) > 0) Text('⛏ Grit: ${(t['grit_qty'] as num).toStringAsFixed(1)} ${t['grit_unit']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Divider(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('₹${(t['rent'] as num).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.success)),
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

class AddEditTransportScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const AddEditTransportScreen({super.key, this.existing});
  @override State<AddEditTransportScreen> createState() => _AddEditTransportScreenState();
}

class _AddEditTransportScreenState extends State<AddEditTransportScreen> {
  DateTime _date = DateTime.now();
  Map<String, dynamic>? _trans;
  List<Map<String, dynamic>> _transporters = [], _items = [];
  final _vehNumCtrl = TextEditingController(), _locCtrl = TextEditingController(),
        _clientCtrl = TextEditingController(), _cementCtrl = TextEditingController(text: '0'),
        _sandQtyCtrl = TextEditingController(text: '0'), _gritQtyCtrl = TextEditingController(text: '0'),
        _rentCtrl = TextEditingController(), _notesCtrl = TextEditingController();
  String _vehicle = 'Tractor', _sandUnit = 'Bags', _gritUnit = 'Bags';
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() { super.initState(); _loadTransporters(); if (widget.existing != null) _loadExisting(); else _addItem(); }

  Future<void> _loadTransporters() async {
    final db = await DatabaseHelper.instance.database;
    _transporters = await db.query('transporters', orderBy: 'name');
    setState(() {});
  }

  Future<void> _loadExisting() async {
    final e = widget.existing!;
    final db = await DatabaseHelper.instance.database;
    _date = DateTime.parse(e['date']);
    _vehicle = e['vehicle'] ?? 'Tractor';
    _vehNumCtrl.text = e['vehicle_number'] ?? '';
    _locCtrl.text = e['location'] ?? '';
    _clientCtrl.text = e['client_name'] ?? '';
    _cementCtrl.text = (e['cement_bags'] ?? 0).toString();
    _sandQtyCtrl.text = (e['sand_qty'] ?? 0).toString();
    _sandUnit = e['sand_unit'] ?? 'Bags';
    _gritQtyCtrl.text = (e['grit_qty'] ?? 0).toString();
    _gritUnit = e['grit_unit'] ?? 'Bags';
    _rentCtrl.text = (e['rent'] ?? 0).toString();
    _notesCtrl.text = e['notes'] ?? '';
    _photoPath = e['photo_path'];
    final tr = await db.query('transporters', where: 'id=?', whereArgs: [e['transporter_id']]);
    if (tr.isNotEmpty) setState(() => _trans = tr.first);
    final its = await db.query('transport_items', where: 'transport_id=?', whereArgs: [e['id']]);
    setState(() => _items = its.map((i) => {'product': i['product_name'], 'size': i['size'], 'qty_ctrl': TextEditingController(text: i['quantity'].toString())}).toList());
  }

  void _addItem() => setState(() => _items.add({'product': 'Panel', 'size': null, 'qty_ctrl': TextEditingController()}));

  Future<void> _save() async {
    if (_trans == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a transporter'))); return; }
    setState(() => _saving = true);
    final db = await DatabaseHelper.instance.database;
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    final now = DateTime.now().toIso8601String();
    final data = {
      'date': dateStr, 'transporter_id': _trans!['id'], 'transporter_name': _trans!['name'],
      'vehicle': _vehicle, 'vehicle_number': _vehNumCtrl.text,
      'location': _locCtrl.text, 'client_name': _clientCtrl.text,
      'cement_bags': int.tryParse(_cementCtrl.text) ?? 0,
      'sand_qty': double.tryParse(_sandQtyCtrl.text) ?? 0, 'sand_unit': _sandUnit,
      'grit_qty': double.tryParse(_gritQtyCtrl.text) ?? 0, 'grit_unit': _gritUnit,
      'rent': double.tryParse(_rentCtrl.text) ?? 0, 'notes': _notesCtrl.text, 'photo_path': _photoPath,
    };
    if (widget.existing != null) {
      final oldItems = await db.query('transport_items', where: 'transport_id=?', whereArgs: [widget.existing!['id']]);
      await StockService.instance.applyTransport(oldItems, reverse: true);
      await db.delete('transport_items', where: 'transport_id=?', whereArgs: [widget.existing!['id']]);
      await db.update('transport', data, where: 'id=?', whereArgs: [widget.existing!['id']]);
      final tid = widget.existing!['id'] as int;
      for (var item in _items) { final q = double.tryParse(item['qty_ctrl'].text) ?? 0; if (q <= 0) continue; await db.insert('transport_items', {'transport_id': tid, 'product_name': item['product'], 'size': item['size'], 'quantity': q}); }
      final newItems = await db.query('transport_items', where: 'transport_id=?', whereArgs: [tid]);
      await StockService.instance.applyTransport(newItems);
    } else {
      final tid = await db.insert('transport', {...data, 'created_at': now});
      for (var item in _items) { final q = double.tryParse(item['qty_ctrl'].text) ?? 0; if (q <= 0) continue; await db.insert('transport_items', {'transport_id': tid, 'product_name': item['product'], 'size': item['size'], 'quantity': q}); }
      final tr = (await db.query('transport', where: 'id=?', whereArgs: [tid])).first;
      final items = await db.query('transport_items', where: 'transport_id=?', whereArgs: [tid]);
      await StockService.instance.applyTransport(items);
      await ExcelService.instance.appendTransport(tr, items);
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
      appBar: AppBar(title: Text(widget.existing != null ? 'Edit Transport' : AppStrings.get('add_transport'))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppDatePicker(date: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AppDropdown<Map<String, dynamic>>(label: AppStrings.get('transporter'), value: _trans, items: _transporters, itemLabel: (t) => t['name'] as String, onChanged: (t) => setState(() => _trans = t))),
          const SizedBox(width: 10),
          IconButton.filled(onPressed: () async { await _addTransDialog(); _loadTransporters(); }, icon: const Icon(Icons.add, size: 20), style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: _vehicle, decoration: InputDecoration(labelText: AppStrings.get('vehicle')), items: ['Tractor','Truck','Mini Truck','Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _vehicle = v!))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _vehNumCtrl, decoration: InputDecoration(labelText: AppStrings.get('vehicle_number')))),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppStrings.get('delivery_location'), style: const TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(height: 4), TextField(controller: _locCtrl, decoration: const InputDecoration(isDense: true))])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppStrings.get('client'), style: const TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(height: 4), TextField(controller: _clientCtrl, decoration: const InputDecoration(isDense: true))])),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Load Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 16), label: Text(AppStrings.get('add')), style: TextButton.styleFrom(foregroundColor: AppColors.primary)),
        ]),
        ..._items.asMap().entries.map((e) {
          final item = e.value; final isCol = item['product'] == 'Column';
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: AppColors.darkBorder), borderRadius: BorderRadius.circular(10)), child: Row(children: [
            Expanded(child: DropdownButtonFormField<String>(value: item['product'], decoration: const InputDecoration(labelText: 'Product', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: ['Panel','Column'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setState(() { item['product'] = v; item['size'] = v == 'Column' ? '8 ft' : null; }))),
            if (isCol) ...[const SizedBox(width: 8), Expanded(child: DropdownButtonFormField<String>(value: item['size'] ?? '8 ft', decoration: const InputDecoration(labelText: 'Size', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), items: ['6 ft','7 ft','8 ft','10 ft','12 ft'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => item['size'] = v)))],
            const SizedBox(width: 8),
            SizedBox(width: 60, child: TextField(controller: item['qty_ctrl'], decoration: const InputDecoration(labelText: 'Qty', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), keyboardType: TextInputType.number)),
            IconButton(onPressed: () => setState(() => _items.removeAt(e.key)), icon: const Icon(Icons.close, size: 18, color: AppColors.danger), padding: EdgeInsets.zero),
          ]));
        }),
        const SizedBox(height: 14),
        TextField(controller: _cementCtrl, decoration: InputDecoration(labelText: AppStrings.get('cement_bags')), keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _sandQtyCtrl, decoration: InputDecoration(labelText: AppStrings.get('sand')), keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(value: _sandUnit, decoration: const InputDecoration(labelText: 'Sand Unit'), items: ['Bags','Kg'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setState(() => _sandUnit = v!))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _gritQtyCtrl, decoration: InputDecoration(labelText: AppStrings.get('grit')), keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(value: _gritUnit, decoration: const InputDecoration(labelText: 'Grit Unit'), items: ['Bags','Kg'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setState(() => _gritUnit = v!))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _rentCtrl, decoration: InputDecoration(labelText: AppStrings.get('rent')), keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        TextField(controller: _notesCtrl, decoration: InputDecoration(labelText: AppStrings.get('notes')), maxLines: 2),
        const SizedBox(height: 14),
        GestureDetector(onTap: () async { final p = ImagePicker(); final picked = await p.pickImage(source: ImageSource.camera, imageQuality: 40); if (picked != null) setState(() => _photoPath = picked.path); }, child: Container(height: 70, decoration: BoxDecoration(border: Border.all(color: AppColors.darkBorder), borderRadius: BorderRadius.circular(10)), child: _photoPath != null ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(_photoPath!), fit: BoxFit.cover, width: double.infinity)) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt_rounded, color: Colors.grey, size: 20), const SizedBox(width: 8), Text(AppStrings.get('photo'), style: const TextStyle(color: Colors.grey))]))),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(AppStrings.get('save')))),
        const SizedBox(height: 30),
      ])),
    );
  }

  Future<void> _addTransDialog() async {
    final nc = TextEditingController(), pc = TextEditingController(), rc = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Transporter'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nc, decoration: InputDecoration(labelText: AppStrings.get('name'))),
        const SizedBox(height: 10), TextField(controller: pc, decoration: InputDecoration(labelText: AppStrings.get('phone')), keyboardType: TextInputType.phone),
        const SizedBox(height: 10), TextField(controller: rc, decoration: const InputDecoration(labelText: 'Default Rent ₹'), keyboardType: TextInputType.number),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel'))),
        ElevatedButton(onPressed: () async { if (nc.text.trim().isEmpty) return; final db = await DatabaseHelper.instance.database; await db.insert('transporters', {'name': nc.text.trim(), 'phone': pc.text.trim(), 'default_rent': double.tryParse(rc.text) ?? 0, 'created_at': DateTime.now().toIso8601String()}); if (ctx.mounted) Navigator.pop(ctx); }, child: Text(AppStrings.get('save')))],
    ));
  }
}
