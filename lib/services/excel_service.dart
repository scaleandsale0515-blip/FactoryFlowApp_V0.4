import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database_helper.dart';
import '../services/settings_service.dart';

class ExcelService {
  static final ExcelService instance = ExcelService._();
  ExcelService._();

  Future<String> _storageFolder() async {
    final company = (await SettingsService.instance.get('company_name') ?? 'FactoryFlow')
        .replaceAll(RegExp(r'[^\w]'), '_');

    final folder = '/storage/emulated/0/${company}_FactoryFlow_Data';

    try {
      await Directory(folder).create(recursive: true);
      return folder;
    } catch (_) {
      return (await getExternalStorageDirectory() ?? await getTemporaryDirectory()).path;
    }
  }

  Future<String?> _activePath() async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.query('excel_cycles', where: 'is_active=1', limit: 1);
    return r.isEmpty ? null : r.first['file_path'] as String?;
  }

  Future<void> checkAndRotate() async {
    final db = await DatabaseHelper.instance.database;

    final r = await db.query('excel_cycles', where: 'is_active=1', limit: 1);

    if (r.isEmpty) {
      await _startNewCycle(db);
      return;
    }

    final end = DateTime.parse(r.first['end_date'] as String);

    if (DateTime.now().isAfter(end)) {
      await db.update('excel_cycles', {'is_active': 0}, where: 'is_active=1');
      await _startNewCycle(db);
    }
  }

  Future<void> _startNewCycle(dynamic db) async {
    final company = await SettingsService.instance.get('company_name') ?? 'FactoryFlow';

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 3, 0);

    final startStr = DateFormat('dd MMM yyyy').format(start);
    final endStr = DateFormat('dd MMM yyyy').format(end);

    final fileName = '$company - $startStr - $endStr.xlsx';

    final folder = await _storageFolder();
    final filePath = '$folder/$fileName';

    final excel = Excel.createExcel();

    _initHeaders(excel);

    excel.delete('Sheet1');

    await File(filePath).writeAsBytes(excel.encode()!);

    await db.insert('excel_cycles', {
      'company_name': company,
      'start_date': start.toIso8601String(),
      'end_date': end.toIso8601String(),
      'file_path': filePath,
      'file_name': fileName,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  void _initHeaders(Excel excel) {
    excel['Production'].appendRow([
      'Date','Worker','Product','Size','Qty','Rate','Amount','Notes'
    ]);

    excel['Transport'].appendRow([
      'Date','Transporter','Vehicle','Vehicle No','Location','Client',
      'Product','Size','Qty','Cement','Sand','Sand Unit','Grit','Grit Unit','Rent'
    ]);

    excel['Purchases'].appendRow([
      'Date','Supplier','Material','Grade','Qty','Unit','Rate','Amount'
    ]);

    excel['Invoices'].appendRow([
      'Invoice No','Date','Customer','Service','Qty','Unit','Rate','Amount','GST%','Total'
    ]);

    excel['Quotations'].appendRow([
      'Quote No','Date','Customer','Service','Qty','Unit','Rate','Amount','GST%','Total','Status'
    ]);

    excel['Stock'].appendRow([
      'Product','Size','Quantity'
    ]);
  }

  Future<void> _writeToFile(String path, Excel excel) async {
    await File(path).writeAsBytes(excel.encode()!);
  }

  Future<Excel?> _readFile(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    return Excel.decodeBytes(await f.readAsBytes());
  }

  Future<void> appendProduction(Map<String, dynamic> prod, List<Map<String, dynamic>> items) async {
    await checkAndRotate();
    final path = await _activePath();
    if (path == null) return;

    final excel = await _readFile(path);
    if (excel == null) return;

    final sheet = excel['Production'];

    for (var i in items) {
      sheet.appendRow([
        prod['date'],
        prod['worker_name'],
        i['product_name'],
        i['size'],
        i['quantity'],
        i['rate'],
        i['amount'],
        prod['notes'],
      ]);
    }

    await _writeToFile(path, excel);
  }

  Future<void> appendTransport(Map<String, dynamic> t, List<Map<String, dynamic>> items) async {
    await checkAndRotate();
    final path = await _activePath();
    if (path == null) return;

    final excel = await _readFile(path);
    if (excel == null) return;

    final sheet = excel['Transport'];

    for (var i in items) {
      sheet.appendRow([
        t['date'],
        t['transporter_name'],
        t['vehicle'],
        t['vehicle_number'],
        t['location'],
        t['client_name'],
        i['product_name'],
        i['size'],
        i['quantity'],
        t['cement_bags'],
        t['sand_qty'],
        t['sand_unit'],
        t['grit_qty'],
        t['grit_unit'],
        t['rent'],
      ]);
    }

    await _writeToFile(path, excel);
  }

  Future<void> appendPurchase(Map<String, dynamic> p, List<Map<String, dynamic>> items) async {
    await checkAndRotate();
    final path = await _activePath();
    if (path == null) return;

    final excel = await _readFile(path);
    if (excel == null) return;

    final sheet = excel['Purchases'];

    for (var i in items) {
      sheet.appendRow([
        p['date'],
        p['supplier_name'],
        i['material_name'],
        i['grade'],
        i['quantity'],
        i['unit'],
        i['rate'],
        i['amount'],
      ]);
    }

    await _writeToFile(path, excel);
  }

  Future<void> updateStockSheet() async {
    final path = await _activePath();
    if (path == null) return;

    final excel = await _readFile(path);
    if (excel == null) return;

    final db = await DatabaseHelper.instance.database;

    excel.delete('Stock');

    final sheet = excel['Stock'];

    sheet.appendRow(['Product','Size','Quantity']);

    for (var r in await db.query('stock')) {
      sheet.appendRow([
        r['product_name'],
        r['size'],
        r['quantity'],
      ]);
    }

    await _writeToFile(path, excel);
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;

    var s = await Permission.manageExternalStorage.request();
    if (s.isGranted) return true;

    s = await Permission.storage.request();
    return s.isGranted;
  }
}
