import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../services/stock_service.dart';
import '../../services/excel_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

class TransportersScreen extends StatefulWidget {
  const TransportersScreen({super.key});
  @override
  State<TransportersScreen> createState() => _TransportersScreenState();
}

class _TransportersScreenState extends State<TransportersScreen> {
  List<Map<String, dynamic>> _transporters = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    final t = await db.query('transporters', orderBy: 'name');
    if (mounted) setState(() { _transporters = t; _loading = false; });
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    final confirm = await showConfirmDialog(context);
    if (!confirm) return;
    final db = await DatabaseHelper.instance.database;
    final hasTrips = await db.query('transport', where: 'transporter_id=?', whereArgs: [t['id']], limit: 1);
    if (hasTrips.isNotEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete — transporter has trip history')));
      return;
    }
    await db.delete('transporters', where: 'id=?', whereArgs: [t['id']]);
    _load();
  }

  Future<void> _addEditDialog({Map<String, dynamic>? existing}) async {
    final nc = TextEditingController(text: existing?['name'] ?? '');
    final pc = TextEditingController(text: existing?['phone'] ?? '');
    final rc = TextEditingController(text: (existing?['default_rent'] ?? '').toString());
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(existing != null ? AppStrings.get('edit') : 'Add Transporter'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nc, decoration: InputDecoration(labelText: AppStrings.get('name'))),
        const SizedBox(height: 10),
        TextField(controller: pc, decoration: InputDecoration(labelText: AppStrings.get('phone')), keyboardType: TextInputType.phone),
        const SizedBox(height: 10),
        TextField(controller: rc, decoration: const InputDecoration(labelText: 'Default Rent ₹'), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel'))),
        ElevatedButton(onPressed: () async {
          if (nc.text.trim().isEmpty) return;
          final db = await DatabaseHelper.instance.database;
          final data = {'name': nc.text.trim(), 'phone': pc.text.trim(), 'default_rent': double.tryParse(rc.text) ?? 0};
          if (existing != null) {
            await db.update('transporters', data, where: 'id=?', whereArgs: [existing['id']]);
          } else {
            await db.insert('transporters', {...data, 'created_at': DateTime.now().toIso8601String()});
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
          : _transporters.isEmpty
              ? EmptyState(message: AppStrings.get('no_data'))
              : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), itemCount: _transporters.length,
                  itemBuilder: (ctx, i) => _TransporterCard(
                    t: _transporters[i],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransporterDetailScreen(transporter: _transporters[i]))),
                    onEdit: () => _addEditDialog(existing: _transporters[i]),
                    onDelete: () => _delete(_transporters[i]),
                  )),
      floatingActionButton: FloatingActionButton(onPressed: () => _addEditDialog(), backgroundColor: AppColors.primary, child: const Icon(Icons.add)),
    );
  }
}

class _TransporterCard extends StatelessWidget {
  final Map<String, dynamic> t; final VoidCallback onTap, onEdit, onDelete;
  const _TransporterCard({required this.t, required this.onTap, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      onTap: onTap,
      leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.local_shipping_rounded, color: AppColors.warning, size: 22)),
      title: Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('Default Rent: ₹${(t['default_rent'] as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.info), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
        IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.danger), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
        const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ]),
    ));
  }
}

class TransporterDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip; // ✅ ADD THIS

  const TransporterDetailScreen({
    Key? key,
    required this.trip, // ✅ ADD THIS
  }) : super(key: key);

  @override
  State<TransporterDetailScreen> createState() =>
      _TransporterDetailScreenState();
}

class _TransporterDetailScreenState extends State<TransporterDetailScreen> {
  List<Map<String, dynamic>> _all = [], _filtered = [];
  Map<int, List<Map<String, dynamic>>> _itemsMap = {};
  bool _loading = true;
  String _filterMode = 'All'; // All / Date / Week / Month
  DateTime? _selectedDate;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;
    final trips = await db.query('transport', where: 'transporter_id=?', whereArgs: [widget.transporter['id']], orderBy: 'date DESC');
    final Map<int, List<Map<String, dynamic>>> itemsMap = {};
    for (var t in trips) { itemsMap[t['id'] as int] = await db.query('transport_items', where: 'transport_id=?', whereArgs: [t['id']]); }
    if (mounted) setState(() { _all = trips; _itemsMap = itemsMap; _applyFilter(); _loading = false; });
  }

  void _applyFilter() {
    if (_filterMode == 'All' || _selectedDate == null) { _filtered = _all; return; }
    _filtered = _all.where((t) {
      try {
        final d = DateTime.parse(t['date'].toString());
        if (_filterMode == 'Date') return DateFormat('yyyy-MM-dd').format(d) == DateFormat('yyyy-MM-dd').format(_selectedDate!);
        if (_filterMode == 'Week') {
          final startOfWeek = _selectedDate!.subtract(Duration(days: _selectedDate!.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          return d.isAfter(startOfWeek.subtract(const Duration(days: 1))) && d.isBefore(endOfWeek.add(const Duration(days: 1)));
        }
        if (_filterMode == 'Month') return d.year == _selectedDate!.year && d.month == _selectedDate!.month;
        return true;
      } catch (_) { return true; }
    }).toList();
  }

  Future<void> _editTrip(Map<String, dynamic> trip) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _EditTransportEntry(trip: trip, items: _itemsMap[trip['id']] ?? [])));
    _load();
  }

@override
Widget build(BuildContext context) {
  double totalRent = 0;

  for (var t in _filtered) {
    totalRent += (t['rent'] as num).toDouble();
  }

  return Scaffold(
    appBar: AppBar(
      title: Text(widget.transporter['name'] ?? ''),
    ),
    body: _loading
        ? const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          )
        : Column(
            children: [
              // 🔹 Filter Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: ['All', 'Date', 'Week', 'Month']
                      .map(
                        (m) => Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              if (m == 'All') {
                                setState(() {
                                  _filterMode = 'All';
                                  _selectedDate = null;
                                  _applyFilter();
                                });
                                return;
                              }

                              final d = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );

                              if (d != null) {
                                setState(() {
                                  _filterMode = m;
                                  _selectedDate = d;
                                  _applyFilter();
                                });
                              }
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _filterMode == m
                                    ? AppColors.primary.withOpacity(0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _filterMode == m
                                      ? AppColors.primary
                                      : AppColors.darkBorder,
                                ),
                              ),
                              child: Text(
                                m,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _filterMode == m
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              // 🔹 Stats Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        StatRow(
                          label: AppStrings.get('total_trips'),
                          value: '${_filtered.length}',
                        ),
                        StatRow(
                          label: AppStrings.get('total_rent'),
                          value: '₹${totalRent.toStringAsFixed(0)}',
                          valueColor: AppColors.success,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 🔹 List
              Expanded(
                child: _filtered.isEmpty
                    ? EmptyState(
                        message: AppStrings.get('no_data'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final t = _filtered[i];
                          final items = _itemsMap[t['id']] ?? [];

                          return Card(
                            margin:
                                const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // 🔹 Header Row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        fmtDate(t['date']),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '₹${(t['rent'] as num).toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.success,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () =>
                                                _editTrip(t),
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

                                  const SizedBox(height: 4),

                                  // 🔹 Location + Client
                                  Row(
                                    children: [
                                      if ((t['location'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              Text(
                                                '📍 ${AppStrings.get('delivery_location')}',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey),
                                              ),
                                              Text(
                                                t['location'],
                                                style:
                                                    const TextStyle(
                                                        fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if ((t['client_name'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              Text(
                                                '👤 ${AppStrings.get('client')}',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey),
                                              ),
                                              Text(
                                                t['client_name'],
                                                style:
                                                    const TextStyle(
                                                        fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),

                                  // 🔹 Vehicle
                                  if ((t['vehicle'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '🚛 ${t['vehicle']}${(t['vehicle_number'] ?? '').toString().isNotEmpty ? ' · ${t['vehicle_number']}' : ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),

                                  // 🔹 Items
                                  ...items.map(
                                    (it) => Text(
                                      '• ${it['product_name']}${it['size'] != null ? ' (${it['size']})' : ''}: ${(it['quantity'] as num).toStringAsFixed(0)} pcs',
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

class _EditTransportEntry extends StatefulWidget {
  final Map<String, dynamic> trip;        // ✅ ADD
  final List<dynamic> items;              // ✅ ADD

  const _EditTransportEntry({
    Key? key,
    required this.trip,                  // ✅ ADD
    required this.items,                 // ✅ ADD
  }) : super(key: key);

  @override
  State<_EditTransportEntry> createState() =>
      _EditTransportEntryState();
}  

  //class _EditTransportEntry extends StatefulWidget {
  //final Map<String, dynamic> trip; final List<Map<String, dynamic>> items;
  //const _EditTransportEntry({required this.trip, required this.items});
  //@override
  //State<_EditTransportEntry> createState() => _EditTransportEntryState();
//}

class _EditTransportEntryState extends State<_EditTransportEntry> {
  late DateTime _date;
  late TextEditingController _locCtrl, _clientCtrl, _rentCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.parse(widget.trip['date']);
    _locCtrl = TextEditingController(text: widget.trip['location'] ?? '');
    _clientCtrl = TextEditingController(text: widget.trip['client_name'] ?? '');
    _rentCtrl = TextEditingController(text: (widget.trip['rent'] ?? 0).toString());
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = await DatabaseHelper.instance.database;
    await db.update('transport', {
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'location': _locCtrl.text, 'client_name': _clientCtrl.text,
      'rent': double.tryParse(_rentCtrl.text) ?? 0,
    }, where: 'id=?', whereArgs: [widget.trip['id']]);
    await ExcelService.instance.updateStockSheet();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Trip')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppDatePicker(date: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 14),
        TextField(controller: _locCtrl, decoration: InputDecoration(labelText: AppStrings.get('delivery_location'))),
        const SizedBox(height: 10),
        TextField(controller: _clientCtrl, decoration: InputDecoration(labelText: AppStrings.get('client'))),
        const SizedBox(height: 10),
        TextField(controller: _rentCtrl, decoration: InputDecoration(labelText: AppStrings.get('rent')), keyboardType: TextInputType.number),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(AppStrings.get('save')))),
      ])),
    );
  }
}
