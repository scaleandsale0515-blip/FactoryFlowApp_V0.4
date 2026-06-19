import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../services/excel_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

//class ArchivesScreen extends StatefulWidget {
//  const ArchivesScreen({super.key});
//  @override
//  State<ArchivesScreen> createState() => _ArchivesScreenState();
//}
class ArchivesScreen extends StatefulWidget {
  final Map<String, dynamic> cycle; // ✅ ADD THIS

  const ArchivesScreen({Key? key, required this.cycle}) : super(key: key);

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  List<Map<String, dynamic>> _cycles = [];
  bool _loading = true;
  DateTime? _fs, _fe;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = await ExcelService.instance.getAllCycles();
    if (mounted) setState(() { _cycles = c; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_fs == null && _fe == null) return _cycles;
    return _cycles.where((c) {
      try {
        final start = DateTime.parse(c['start_date']);
        if (_fs != null && start.isBefore(_fs!)) return false;
        if (_fe != null && start.isAfter(_fe!)) return false;
        return true;
      } catch (_) { return true; }
    }).toList();
  }

  Future<void> _download(Map<String, dynamic> cycle) async {
    final file = File(cycle['file_path']);
    if (!await file.exists()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File not found on device')));
      return;
    }
    await Share.shareXFiles([XFile(file.path)], text: cycle['file_name']);
  }

  Future<void> _viewFile(Map<String, dynamic> cycle) async {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _ExcelViewerScreen(cycle: cycle)));
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(AppStrings.get('archives')),
    ),
    body: Column(
      children: [
        // Date Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: DateRangeFilter(
            onChanged: (s, e) {
              setState(() {
                _fs = s;
                _fe = e;
              });
            },
          ),
        ),

        // Content
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(), // ✅ FIXED (removed color error)
                )
              : _filtered.isEmpty
                  ? EmptyState(
                      message: AppStrings.get('no_data'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final c = _filtered[i];
                        final isActive = (c['is_active'] as int) == 1;
                        final file = File(c['file_path']);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Row
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.description_rounded,
                                      color: AppColors.success,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),

                                    // File Name
                                    Expanded(
                                      child: Text(
                                        c['file_name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                    // Active Chip
                                    if (isActive)
                                      InfoChip(
                                        label: AppStrings.get('active_cycle'),
                                        color: AppColors.success,
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // File Info (Size + Date)
                                FutureBuilder<bool>(
                                  future: file.exists(),
                                  builder: (context, existsSnap) {
                                    if (!existsSnap.hasData) {
                                      return const Text(
                                        'Loading...',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      );
                                    }

                                    if (!existsSnap.data!) {
                                      return const Text(
                                        'File not found',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red,
                                        ),
                                      );
                                    }

                                    return FutureBuilder<FileStat>(
                                      future: file.stat(),
                                      builder: (context, statSnap) {
                                        final size = statSnap.hasData
                                            ? '${(statSnap.data!.size / 1024).toStringAsFixed(0)} KB'
                                            : '...';

                                        return Text(
                                          '${DateFormat('dd MMM').format(DateTime.parse(c['start_date']))}'
                                          ' - '
                                          '${DateFormat('dd MMM yyyy').format(DateTime.parse(c['end_date']))}'
                                          '  ·  $size',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),

                                const SizedBox(height: 10),

                                // Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _viewFile(c),
                                        icon: const Icon(
                                          Icons.visibility_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          AppStrings.get('view_file'),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.info,
                                          side: const BorderSide(
                                            color: AppColors.info,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _download(c),
                                        icon: const Icon(
                                          Icons.download_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          AppStrings.get('download'),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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

class _ExcelViewerScreen extends StatefulWidget {
  final Map<String, dynamic> cycle;
  const _ExcelViewerScreen({required this.cycle});
  @override
  State<_ExcelViewerScreen> createState() => _ExcelViewerScreenState();
}

class _ExcelViewerScreenState extends State<_ExcelViewerScreen> {
  Map<String, List<List<String>>> _sheets = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await ExcelService.instance.readForView(widget.cycle['file_path']);
    if (mounted) setState(() { _sheets = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(title: Text(widget.cycle['file_name'] ?? '')), body: const Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final sheetNames = _sheets.keys.toList();
    if (sheetNames.isEmpty) return Scaffold(appBar: AppBar(title: Text(widget.cycle['file_name'] ?? '')), body: EmptyState(message: AppStrings.get('no_data')));

    return DefaultTabController(length: sheetNames.length, child: Scaffold(
      appBar: AppBar(
        title: Text(widget.cycle['file_name'] ?? '', style: const TextStyle(fontSize: 14)),
        bottom: TabBar(isScrollable: true, tabs: sheetNames.map((s) => Tab(text: s)).toList(), labelColor: AppColors.primary, indicatorColor: AppColors.primary),
      ),
      body: TabBarView(children: sheetNames.map((sheetName) {
        final rows = _sheets[sheetName]!;
        if (rows.isEmpty) return EmptyState(message: AppStrings.get('no_data'));
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columns: rows.first.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)))).toList(),
              rows: rows.skip(1).map((r) => DataRow(cells: r.map((c) => DataCell(Text(c, style: const TextStyle(fontSize: 11)))).toList())).toList(),
            ),
          ),
        );
      }).toList()),
    ));
  }
}
