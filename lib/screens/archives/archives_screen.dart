import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../../services/excel_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../widgets/common_widgets.dart';

class ArchivesScreen extends StatefulWidget {
  const ArchivesScreen({Key? key}) : super(key: key);

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  List<Map<String, dynamic>> _cycles = [];
  bool _loading = true;
  DateTime? _fs, _fe;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ExcelService.instance.getAllCycles();

    if (mounted) {
      setState(() {
        _cycles = data;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_fs == null && _fe == null) return _cycles;

    return _cycles.where((c) {
      try {
        final start = DateTime.parse(c['start_date']);

        if (_fs != null && start.isBefore(_fs!)) return false;
        if (_fe != null && start.isAfter(_fe!)) return false;

        return true;
      } catch (_) {
        return true;
      }
    }).toList();
  }

  Future<void> _download(Map<String, dynamic> cycle) async {
    final file = File(cycle['file_path']);

    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found')),
        );
      }
      return;
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      text: cycle['file_name'],
    );
  }

  void _viewFile(Map<String, dynamic> cycle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExcelViewerScreen(cycle: cycle), // ✅ FIXED
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('archives')),
      ),
      body: Column(
        children: [
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

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? EmptyState(message: AppStrings.get('no_data'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final c = _filtered[i];
                          final file = File(c['file_path']);
                          final isActive = (c['is_active'] as int) == 1;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.description_rounded,
                                          color: AppColors.success),

                                      const SizedBox(width: 10),

                                      Expanded(
                                        child: Text(
                                          c['file_name'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),

                                      if (isActive)
                                        InfoChip(
                                          label: AppStrings.get('active_cycle'),
                                          color: AppColors.success,
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  FutureBuilder<FileStat>(
                                    future: file.exists()
                                        .then((e) => e
                                            ? file.stat()
                                            : Future.value(
                                                FileStat.statSync('/'))),
                                    builder: (context, snap) {
                                      final size = snap.data != null
                                          ? '${(snap.data!.size / 1024).toStringAsFixed(0)} KB'
                                          : '...';

                                      return Text(
                                        '${DateFormat('dd MMM').format(DateTime.parse(c['start_date']))}'
                                        ' - '
                                        '${DateFormat('dd MMM yyyy').format(DateTime.parse(c['end_date']))}'
                                        ' · $size',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 10),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _viewFile(c),
                                          icon: const Icon(Icons.visibility,
                                              size: 16),
                                          label: Text(
                                              AppStrings.get('view_file')),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _download(c),
                                          icon: const Icon(Icons.download,
                                              size: 16),
                                          label:
                                              Text(AppStrings.get('download')),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.success,
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
}

// ✅ CLEAN SEPARATE SCREEN
class ExcelViewerScreen extends StatefulWidget {
  final Map<String, dynamic> cycle;

  const ExcelViewerScreen({Key? key, required this.cycle})
      : super(key: key);

  @override
  State<ExcelViewerScreen> createState() => _ExcelViewerScreenState();
}

class _ExcelViewerScreenState extends State<ExcelViewerScreen> {
  bool _loading = true;
  Map<String, List<List<dynamic>>> _sheets = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ExcelService.instance
        .readForView(widget.cycle['file_path']);

    if (mounted) {
      setState(() {
        _sheets = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar:
            AppBar(title: Text(widget.cycle['file_name'] ?? '')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sheetNames = _sheets.keys.toList();

    if (sheetNames.isEmpty) {
      return Scaffold(
        appBar:
            AppBar(title: Text(widget.cycle['file_name'] ?? '')),
        body: EmptyState(message: AppStrings.get('no_data')),
      );
    }

    return DefaultTabController(
      length: sheetNames.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.cycle['file_name'] ?? ''),
          bottom: TabBar(
            isScrollable: true,
            tabs: sheetNames.map((e) => Tab(text: e)).toList(),
          ),
        ),
        body: TabBarView(
          children: sheetNames.map((name) {
            final rows = _sheets[name]!;

            return ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) {
                return ListTile(
                  title: Text(rows[i].join(" | ")),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}





  
