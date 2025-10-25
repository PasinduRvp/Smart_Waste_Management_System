import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class BillPdfService {
  Future<void> generateAndShareBillPdf({
    required Map<String, dynamic> bill,
  }) async {
    final pdf = pw.Document();

    final amount = (bill['actualAmount'] ?? 0.0) as num;
    final collectedWeight = (bill['collectedWeight'] ?? 0.0) as num;
    final wasteType = (bill['wasteType'] ?? 'Special Waste').toString();
    final address = (bill['address'] ?? '').toString();
    final description = (bill['description'] ?? '').toString();
    final id = (bill['id'] ?? '').toString();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('E-Waste Management', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Bill / Receipt', style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Text('Bill ID: $id', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 8),
                pw.Text('Waste Type: $wasteType', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 8),
                pw.Text('Collected Weight: ${collectedWeight.toStringAsFixed(2)} kg', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 8),
                pw.Text('Address: $address', style: const pw.TextStyle(fontSize: 12)),
                if (description.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text('Description:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(description, style: const pw.TextStyle(fontSize: 12)),
                ],
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Amount', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('LKR ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Text('Thank you for keeping the environment clean!', style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }
}



