import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../services/stock_service.dart';
import '../../services/excel_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

import '../production/edit_production_entry.dart'; // FROM NEW FILE YOU MADE WITH AI.

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});
  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  List<Map<String, dynamic>> _workers = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    final w = await db.query('workers', orderBy: 'name');
    if (mounted) setState(() { _workers = w; _loading = false; });
  }
  Future<void> _delete(Map<String, dynamic> w) async {
    final confirm = await showConfirmDialog(context);
    if (!confirm) return;
    final db = await DatabaseHelper.instance.database;
    final hasProd = await db.query('production', where: 'worker_id=?', whereArgs: [w['id']], limit: 1);
    if (hasProd.isNotEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete — worker has production history')));
      return;
    }
    await db.delete('workers', where: 'id=?', whereArgs: [w['id']]);
    _load();
  }
  Future<void> _addEditDialog({Map<String, dynamic>? existing}) async {
    final nc = TextEditingController(text: existing?['name'] ?? '');
    final pc = TextEditingController(text: existing?['phone'] ?? '');
    final ac = TextEditingController(text: existing?['address'] ?? '');
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(existing != null ? AppStrings.get('edit') : AppStrings.get('add_worker')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nc, decoration: InputDecoration(labelText: AppStrings.get('name'))),
        const SizedBox(height: 10),
        TextField(controller: pc, decoration: InputDecoration(labelText: AppStrings.get('phone')), keyboardType: TextInputType.phone),
        const SizedBox(height: 10),
        TextField(controller: ac, decoration: InputDecoration(labelText: AppStrings.get('address'))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel'))),
        ElevatedButton(onPressed: () async {
          if (nc.text.trim().isEmpty) return;
          final db = await DatabaseHelper.instance.database;
          if (existing != null) {
            await db.update('workers', {'name': nc.text.trim(), 'phone': pc.text.trim(), 'address': ac.text.trim()}, where: 'id=?', whereArgs: [existing['id']]);
          } else {
            await db.insert('workers', {'name': nc.text.trim(), 'phone': pc.text.trim(), 'address': ac.text.trim(), 'created_at': DateTime.now().toIso8601String()});
          }
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: Text(AppStrings.get('save'))),
      ],
    ));
    _load();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _workers.isEmpty
              ? EmptyState(message: AppStrings.get('no_data'))
              : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), itemCount: _workers.length,
                  itemBuilder: (ctx, i) => _WorkerCard(
                    worker: _workers[i],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkerDetailScreen(worker: _workers[i], items: []))),
                    onEdit: () => _addEditDialog(existing: _workers[i]),
                    onDelete: () => _delete(_workers[i]),
                  )),
      floatingActionButton: FloatingActionButton(onPressed: () => _addEditDialog(), backgroundColor: AppColors.primary, child: const Icon(Icons.add),),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final Map<String, dynamic> worker; final VoidCallback onTap, onEdit, onDelete;
  const _WorkerCard({required this.worker, required this.onTap, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      onTap: onTap,
      leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_rounded, color: AppColors.accent, size: 22)),
      title: Text(worker['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(worker['phone'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.info), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
        IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.danger), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
        const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ]),
    ));
  }
}







// ── WORKER DETAIL SCREEEENNNNNNNNNNNN — Filter by date range, full history, edit any entry ────────



class WorkerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> worker;
   final List items; // ✅ ADD THIS
  const WorkerDetailScreen({super.key, required this.worker, required this.items});
  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  List<Map<String, dynamic>> _all = [], _filtered = [];
  Map<int, List<Map<String, dynamic>>> _itemsMap = {};
  bool _loading = true;
  DateTime? _fs, _fe;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    final prods = await db.query('production', where: 'worker_id=?', whereArgs: [widget.worker['id']], orderBy: 'date DESC');
    final Map<int, List<Map<String, dynamic>>> itemsMap = {};
    for (var p in prods) {
      itemsMap[p['id'] as int] = await db.query('production_items', where: 'production_id=?', whereArgs: [p['id']]);
    }
    if (mounted) setState(() { _all = prods; _itemsMap = itemsMap; _applyFilter(); _loading = false; });
  }

  void _applyFilter() {
    _filtered = _all.where((p) {
      if (_fs == null && _fe == null) return true;
      try { final d = DateTime.parse(p['date'].toString()); if (_fs != null && d.isBefore(_fs!)) return false; if (_fe != null && d.isAfter(_fe!.add(const Duration(days: 1)))) return false; return true; } catch (_) { return true; }
    }).toList();
  }

  Future<void> _editEntry(Map<String, dynamic> prod) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProductionEntry(prod: prod, items: [])));
    _load();
  }

 @override
Widget build(BuildContext context) {
  double totalEarnings = 0, totalItems = 0;

  for (var p in _filtered) {
    totalEarnings += (p['total_amount'] as num).toDouble();

    for (var i in (_itemsMap[p['id']] ?? [])) {
      totalItems += (i['quantity'] as num).toDouble();
    }
  }

  return Scaffold(
    appBar: AppBar(
      title: Text(widget.worker['name'] ?? ''),
    ),
    body: _loading
        ? const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          )
        : Column(
            children: [
              // 📅 Date Filter
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: DateRangeFilter(
                  onChanged: (s, e) {
                    setState(() {
                      _fs = s;
                      _fe = e;
                      _applyFilter();
                    });
                  },
                ),
              ),

              // 📊 Stats Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        StatRow(
                          label: AppStrings.get('total_earnings'),
                          value: '₹${totalEarnings.toStringAsFixed(0)}',
                          valueColor: AppColors.success,
                        ),
                        StatRow(
                          label: AppStrings.get('total_items'),
                          value: '${totalItems.toStringAsFixed(0)} pcs',
                        ),
                        StatRow(
                          label: AppStrings.get('history'),
                          value: '${_filtered.length} entries',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 📋 List
              Expanded(
                child: _filtered.isEmpty
                    ? EmptyState(
                        message: AppStrings.get('no_data'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final p = _filtered[i];
                          final items = _itemsMap[p['id']] ?? [];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 🔹 Header Row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        fmtDate(p['date']),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '₹${(p['total_amount'] as num).toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.success,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _editEntry(p),
                                            icon: const Icon(
                                              Icons.edit_rounded,
                                              size: 16,
                                              color: AppColors.info,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // 🔹 Items List
                                  ...items.map(
                                    (it) => Text(
                                      '• ${it['product_name']}${it['size'] != null ? ' (${it['size']})' : ''}: ${(it['quantity'] as num).toStringAsFixed(0)} pcs × ₹${(it['rate'] as num).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
  );
 }
}  

//class EditProductionEntry extends StatefulWidget { 
//  final Map<String, dynamic> prod; final List<Map<String, dynamic>> items;
//  const EditProductionEntry({required this.prod, required this.items});
//  @override
// State<EditProductionEntry> createState() => EditProductionEntryState();
//}

