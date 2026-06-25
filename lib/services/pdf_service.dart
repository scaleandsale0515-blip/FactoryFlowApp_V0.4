import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_google_fonts/pdf_google_fonts.dart';
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

    final docNum = isQuotation
        ? (doc['quote_number'] ?? 'QT')
        : (doc['invoice_number'] ?? 'INV');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$docNum.pdf');
    await file.writeAsBytes(bytes);

    if (context.mounted) {
      await showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading:
                  const Icon(Icons.print_rounded, color: AppColors.primary),
              title: const Text('Print / Preview'),
              onTap: () async {
                Navigator.pop(ctx);
                await Printing.layoutPdf(onLayout: (_) async => bytes);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.share_rounded, color: AppColors.accent),
              title: const Text('Share'),
              onTap: () async {
                Navigator.pop(ctx);
                await Share.shareXFiles([XFile(file.path)],
                    text:
                        '${isQuotation ? "Quotation" : "Invoice"} $docNum');
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      );
    }
  }

  Future<Uint8List> _build(
    Map<String, dynamic> doc,
    List<Map<String, dynamic>> items,
    Map<String, String> s,
    bool isQ,
  ) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.notoSansRegular(); // ✅ FIX ₹

    final company = s['company_name'] ?? 'FactoryFlow';
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
        theme: pw.ThemeData.withFont(base: font), // ✅ font applied
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

            // HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(children: [
                  if (logo != null) pw.Image(logo, width: 50),
                  pw.SizedBox(width: 10),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(company,
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold)),
                      if (addr.isNotEmpty) pw.Text(addr),
                      if (phone.isNotEmpty) pw.Text(phone),
                    ],
                  ),
                ]),
                pw.Text(isQ ? "QUOTATION" : "INVOICE",
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),

            pw.SizedBox(height: 20),

            // CUSTOMER
            pw.Text("Customer: $custName"),
            if (custPhone.isNotEmpty) pw.Text("Phone: $custPhone"),

            pw.SizedBox(height: 20),

            // TABLE
            pw.Table.fromTextArray(
              headers: ['Item', 'Qty', 'Rate', 'Amount'],
              data: items.map((e) {
                final qty = e['qty'] ?? 1;
                final rate = e['rate'] ?? e['amount'] ?? 0;
                final total = qty * rate;
                return [
                  e['service_name'] ?? '',
                  qty.toString(),
                  '₹ $rate',
                  '₹ $total'
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 20),

            // TOTAL
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "Total: ₹ ${doc['total']}",
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold),
              ),
            ),

            pw.SizedBox(height: 20),

            // PAYMENT TERMS
            if (pt.isNotEmpty) ...[
              pw.Text("Payment Terms",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ...pt.split('\n').map((e) => pw.Bullet(text: e)),
            ],

            pw.SizedBox(height: 10),

            // TERMS
            if (tc.isNotEmpty) ...[
              pw.Text("Terms & Conditions",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ...tc.split('\n').map((e) => pw.Bullet(text: e)),
            ],

            pw.Spacer(),

            pw.Center(
              child: pw.Text("Thank you for your business!",
                  style: pw.TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  String _fmtDate(dynamic d) {
    try {
      return DateFormat('dd MMM yyyy')
          .format(DateTime.parse(d.toString()));
    } catch (_) {
      return d?.toString() ?? '';
    }
  }
}
