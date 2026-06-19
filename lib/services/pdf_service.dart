import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';

class PdfService {
  static final PdfService instance = PdfService._();
  PdfService._();

  Future<void> generateAndShare({
    required Map<String, dynamic> doc,
    required List<Map<String, dynamic>> items,
    required bool isQuotation,
    required BuildContext context,
  }) async {
    final settings = await SettingsService.instance.getAll();
    final bytes = await _build(doc, items, settings, isQuotation);
    final docNum = isQuotation ? (doc['quote_number'] ?? 'QT') : (doc['invoice_number'] ?? 'INV');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$docNum.pdf');
    await file.writeAsBytes(bytes);
    if (context.mounted) {
      await showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.print_rounded, color: AppColors.primary),
            title: const Text('Print / Preview'),
            onTap: () async { Navigator.pop(ctx); await Printing.layoutPdf(onLayout: (_) async => bytes); },
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded, color: AppColors.accent),
            title: const Text('Share (WhatsApp / Other)'),
            onTap: () async { Navigator.pop(ctx); await Share.shareXFiles([XFile(file.path)], text: '${isQuotation ? "Quotation" : "Invoice"} $docNum'); },
          ),
          const SizedBox(height: 8),
        ])),
      );
    }
  }

  // ✅ NEW CODE UPDATE WITH AI.
 Future<Uint8List> _build(
  Map<String, dynamic> doc,
  List<Map<String, dynamic>> items,
  Map<String, String> s,
  bool isQ,
) async {
  final pdf = pw.Document();

  final orange = PdfColor.fromHex('#FF6B00');
  final darkBg = PdfColor.fromHex('#1A1A1A');
  final lightGrey = PdfColor.fromHex('#F5F5F0');
  final textDark = PdfColor.fromHex('#111111');
  final textGrey = PdfColor.fromHex('#666666');
  final green = PdfColor.fromHex('#22C55E');

  final company = s['company_name'] ?? 'FactoryFlow';
  final gst = s['gst_number'] ?? '';
  final addr = s['address'] ?? '';
  final phone = s['phone'] ?? '';
  final pt = s['payment_terms'] ?? '';
  final tc = s['terms_conditions'] ?? '';

  final docNum = isQ ? doc['quote_number'] : doc['invoice_number'];
  final custName = doc['customer_name'] ?? '';
  final custPhone = doc['customer_phone'] ?? '';

  pw.MemoryImage? logo;
  final logoPath = s['logo_path'] ?? '';
  if (logoPath.isNotEmpty) {
    try {
      final lf = File(logoPath);
      if (await lf.exists()) {
        logo = pw.MemoryImage(await lf.readAsBytes());
      }
    } catch (_) {}
  }

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // HEADER
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: darkBg,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(children: [
                  if (logo != null) ...[
                    pw.Image(logo, width: 46, height: 46),
                    pw.SizedBox(width: 12)
                  ],
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(company,
                          style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                      if (addr.isNotEmpty)
                        pw.Text(addr,
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: textGrey)), // ✅ FIXED
                      if (phone.isNotEmpty)
                        pw.Text(phone,
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: textGrey)), // ✅ FIXED
                    ],
                  ),
                ]),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: orange,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        isQ ? 'QUOTATION' : 'INVOICE',
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(docNum ?? '',
                        style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),
          pw.Text('Customer: $custName'),
          if (custPhone.isNotEmpty) pw.Text('Phone: $custPhone'),

          pw.SizedBox(height: 20),

          ...items.map((item) => pw.Text(
              "${item['service_name']} - ₹${item['amount']}")),

          pw.SizedBox(height: 20),

          pw.Text("Total: ₹${doc['total']}",
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: green)),
        ],
      ),
    ),
  );

  // ✅ IMPORTANT FIX (Uint8List)
  final bytes = await pdf.save();
  return Uint8List.fromList(bytes);
}

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // HEADER
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(color: darkBg, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Row(children: [
              if (logo != null) ...[pw.Image(logo, width: 46, height: 46), pw.SizedBox(width: 12)],
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(company, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                if (addr.isNotEmpty) pw.Text(addr, style: pw.TextStyle(fontSize: 8, color: PdfColors.white60)),
                if (phone.isNotEmpty) pw.Text(phone, style: pw.TextStyle(fontSize: 8, color: PdfColors.white60)),
              ]),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(color: orange, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text(isQ ? 'QUOTATION' : 'INVOICE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
              pw.SizedBox(height: 6),
              pw.Text(docNum ?? '', style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 14),

        // BILL TO / DATE
        pw.Row(children: [
          pw.Expanded(child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: lightGrey, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('BILL TO', style: pw.TextStyle(fontSize: 8, color: textGrey, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(custName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textDark)),
              if (custPhone.isNotEmpty) pw.Text(custPhone, style: pw.TextStyle(fontSize: 9, color: textGrey)),
            ]),
          )),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: lightGrey, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('DATE', style: pw.TextStyle(fontSize: 8, color: textGrey, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(_fmtDate(doc['date']), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textDark)),
              if (isQ && (doc['status'] ?? '').isNotEmpty)
                pw.Container(margin: const pw.EdgeInsets.only(top: 4), padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(color: orange, borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Text(doc['status'] ?? '', style: pw.TextStyle(fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
            ]),
          )),
        ]),
        pw.SizedBox(height: 14),

        // TABLE
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0'))),
          child: pw.Column(children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: orange,
              child: pw.Row(children: [
                pw.Expanded(flex: 4, child: pw.Text('SERVICE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                pw.Expanded(child: pw.Text('QTY', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center)),
                pw.Expanded(child: pw.Text('UNIT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center)),
                pw.Expanded(child: pw.Text('RATE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right)),
                pw.Expanded(child: pw.Text('AMOUNT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right)),
              ]),
            ),
            ...items.asMap().entries.map((e) {
              final item = e.value;
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: e.key % 2 == 0 ? PdfColors.white : lightGrey,
                child: pw.Row(children: [
                  pw.Expanded(flex: 4, child: pw.Text(item['service_name']?.toString() ?? '', style: pw.TextStyle(fontSize: 10, color: textDark))),
                  pw.Expanded(child: pw.Text((item['quantity'] as num).toStringAsFixed(2), style: pw.TextStyle(fontSize: 10, color: textDark), textAlign: pw.TextAlign.center)),
                  pw.Expanded(child: pw.Text(item['unit']?.toString() ?? '', style: pw.TextStyle(fontSize: 9, color: textGrey), textAlign: pw.TextAlign.center)),
                  pw.Expanded(child: pw.Text('₹${(item['rate'] as num).toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 10, color: textDark), textAlign: pw.TextAlign.right)),
                  pw.Expanded(child: pw.Text('₹${(item['amount'] as num).toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark), textAlign: pw.TextAlign.right)),
                ]),
              );
            }),
          ]),
        ),
        pw.SizedBox(height: 12),

        // TOTALS
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(
            width: 210,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: lightGrey, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Subtotal', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                pw.Text('₹${(doc['subtotal'] as num).toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 10, color: textDark)),
              ]),
              if ((doc['gst_percent'] as num) > 0) ...[
                pw.SizedBox(height: 4),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('GST ${doc['gst_percent']}%', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                  pw.Text('₹${(doc['gst_amount'] as num).toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 10, color: textDark)),
                ]),
              ],
              pw.Divider(color: PdfColor.fromHex('#CCCCCC')),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textDark)),
                pw.Text('₹${(doc['total'] as num).toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: green)),
              ]),
            ]),
          ),
        ]),

        if (gst.isNotEmpty) ...[pw.SizedBox(height: 8), pw.Text('GST No: $gst', style: pw.TextStyle(fontSize: 9, color: textGrey))],
        pw.SizedBox(height: 10),

        // PAYMENT TERMS
        if (pt.isNotEmpty) ...[
          pw.Text('PAYMENT TERMS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark)),
          pw.SizedBox(height: 4),
          ...pt.split('\n').map((l) => pw.Text('• $l', style: pw.TextStyle(fontSize: 8, color: textGrey))),
          pw.SizedBox(height: 8),
        ],

        // T&C
        if (tc.isNotEmpty) ...[
          pw.Text('TERMS & CONDITIONS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark)),
          pw.SizedBox(height: 4),
          ...tc.split('\n').map((l) => pw.Text('• $l', style: pw.TextStyle(fontSize: 8, color: textGrey))),
          pw.SizedBox(height: 10),
        ],

        pw.Spacer(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Container(width: 160, height: 1, color: PdfColor.fromHex('#CCCCCC')),
            pw.SizedBox(height: 4),
            pw.Text('Authorised Signature', style: pw.TextStyle(fontSize: 9, color: textGrey)),
          ]),
        ]),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColor.fromHex('#E0E0E0')),
        pw.Center(child: pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 10, color: textGrey))),
      ]),
    ));
    return await pdf.save();
  }

  String _fmtDate(dynamic d) { try { return DateFormat('dd MMM yyyy').format(DateTime.parse(d.toString())); } catch (_) { return d?.toString() ?? ''; } }
}
