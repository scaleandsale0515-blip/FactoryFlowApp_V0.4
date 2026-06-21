import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../services/stock_service.dart';
import '../../services/excel_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

class EditProductionEntry extends StatefulWidget {
  final Map<String, dynamic> prod; 
  final List<Map<String, dynamic>> items;
  
  const EditProductionEntry({
    Key? key,
    required this.prod, 
    required this.items})
    : super(key: key);
  @override
  State<EditProductionEntry> createState() => _EditProductionEntryState();
}

class _EditProductionEntryState extends State<EditProductionEntry> {
  late DateTime _date;
  late List<Map<String, dynamic>> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.parse(widget.prod['date']);
    _items = widget.items.map((i) => {'product': i['product_name'], 'size': i['size'], 'qty_ctrl': TextEditingController(text: i['quantity'].toString()), 'rate_ctrl': TextEditingController(text: i['rate'].toString())}).toList();
  }

  double get _total => _items.fold(0.0, (s, i) => s + (double.tryParse(i['qty_ctrl'].text) ?? 0) * (double.tryParse(i['rate_ctrl'].text) ?? 0));

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = await DatabaseHelper.instance.database;
    final oldItems = await db.query('production_items', where: 'production_id=?', whereArgs: [widget.prod['id']]);
    await StockService.instance.applyProduction(oldItems, reverse: true);
    await db.delete('production_items', where: 'production_id=?', whereArgs: [widget.prod['id']]);
    await db.update('production', {'date': DateFormat('yyyy-MM-dd').format(_date), 'total_amount': _total}, where: 'id=?', whereArgs: [widget.prod['id']]);
    for (var item in _items) {
      final q = double.tryParse(item['qty_ctrl'].text) ?? 0; final r = double.tryParse(item['rate_ctrl'].text) ?? 0;
      if (q <= 0) continue;
      await db.insert('production_items', {'production_id': widget.prod['id'], 'product_name': item['product'], 'size': item['size'], 'quantity': q, 'rate': r, 'amount': q * r});
    }
    final newItems = await db.query('production_items', where: 'production_id=?', whereArgs: [widget.prod['id']]);
    await StockService.instance.applyProduction(newItems);
    await ExcelService.instance.updateStockSheet();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Entry')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppDatePicker(date: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 14),
        ..._items.map((item) {
          final amt = (double.tryParse(item['qty_ctrl'].text) ?? 0) * (double.tryParse(item['rate_ctrl'].text) ?? 0);
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: AppColors.darkBorder), borderRadius: BorderRadius.circular(10)), child: Column(children: [
            Text('${item['product']}${item['size'] != null ? ' (${item['size']})' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: item['qty_ctrl'], decoration: const InputDecoration(labelText: 'Qty', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: item['rate_ctrl'], decoration: const InputDecoration(labelText: 'Rate', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Text('₹${amt.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
            ]),
          ]));
        }),
        const SizedBox(height: 10),
        Text('Total: ₹${_total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(AppStrings.get('save')))),
      ])),
    );
  }
}




  
