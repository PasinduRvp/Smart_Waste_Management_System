import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AnalyticsDashboardScreen extends StatelessWidget {
  const AnalyticsDashboardScreen({super.key});

  Future<int> _count(String collection, [List<Query<Object?>> filters = const []]) async {
    Query q = FirebaseFirestore.instance.collection(collection);
    for (final f in filters) {
      q = q.where((f.parameters as dynamic)['field'], isEqualTo: (f.parameters as dynamic)['value']);
    }
    // Use count() aggregation if available; fallback to get()
    try {
      final agg = await q.count().get();
      return agg.count ?? 0;
    } catch (_) {
      final snap = await q.get();
      return snap.docs.length;
    }
  }

  Future<Map<String, int>> _loadMetrics() async {
    final futures = await Future.wait<int>([
      _count('users'),
      _count('special_pickups'),
      _count('pickups'),
      _count('payments'),
      _count('assigned_tasks'),
    ]);
    return {
      'users': futures[0],
      'specialPickups': futures[1],
      'regularPickups': futures[2],
      'payments': futures[3],
      'assignedTasks': futures[4],
    };
  }

  Future<List<_StatusSlice>> _specialPickupStatusBreakdown() async {
    final qs = await FirebaseFirestore.instance.collection('special_pickups').get();
    final map = <String, int>{};
    for (final d in qs.docs) {
      final s = (d['status'] ?? 'pending').toString();
      map[s] = (map[s] ?? 0) + 1;
    }
    return map.entries.map((e) => _StatusSlice(e.key, e.value)).toList();
  }

  Future<List<_MonthlyBar>> _completedPerMonth() async {
    final qs = await FirebaseFirestore.instance
        .collection('special_pickups')
        .where('status', isEqualTo: 'completed')
        .get();
    final buckets = <String, int>{};
    for (final d in qs.docs) {
      DateTime when;
      if (d.data().containsKey('collectionDate') && d['collectionDate'] is Timestamp) {
        when = (d['collectionDate'] as Timestamp).toDate();
      } else if (d.data().containsKey('scheduledDate') && d['scheduledDate'] is Timestamp) {
        when = (d['scheduledDate'] as Timestamp).toDate();
      } else {
        continue;
      }
      final key = '${when.year}-${when.month.toString().padLeft(2, '0')}';
      buckets[key] = (buckets[key] ?? 0) + 1;
    }
    final sortedKeys = buckets.keys.toList()..sort();
    return sortedKeys.map((k) => _MonthlyBar(k, buckets[k]!)).toList();
  }

  Future<void> _generatePdf(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Load all data
      final metrics = await _loadMetrics();
      final statusData = await _specialPickupStatusBreakdown();
      final monthlyData = await _completedPerMonth();

      // Create PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Title
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Analytics Dashboard Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),

              // Date
              pw.Text(
                'Generated: ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 30),

              // Metrics Summary
              pw.Header(
                level: 1,
                child: pw.Text('Summary Metrics', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),

              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                cellStyle: const pw.TextStyle(fontSize: 11),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 35,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                },
                data: [
                  ['Metric', 'Count'],
                  ['Users', metrics['users'].toString()],
                  ['Special Pickups', metrics['specialPickups'].toString()],
                  ['Regular Pickups', metrics['regularPickups'].toString()],
                  ['Payments', metrics['payments'].toString()],
                  ['Assigned Tasks', metrics['assignedTasks'].toString()],
                ],
              ),
              pw.SizedBox(height: 30),

              // Status Breakdown
              pw.Header(
                level: 1,
                child: pw.Text('Special Pickups by Status', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),

              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                cellStyle: const pw.TextStyle(fontSize: 11),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 35,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                },
                data: [
                  ['Status', 'Count'],
                  ...statusData.map((s) => [s.status, s.count.toString()]),
                ],
              ),
              pw.SizedBox(height: 30),

              // Monthly Breakdown
              pw.Header(
                level: 1,
                child: pw.Text('Completed Special Pickups per Month', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),

              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                cellStyle: const pw.TextStyle(fontSize: 11),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 35,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                },
                data: [
                  ['Month', 'Completed'],
                  ...monthlyData.map((m) => [m.month, m.count.toString()]),
                ],
              ),
            ];
          },
        ),
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show print/save dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'analytics_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Analytics', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _generatePdf(context),
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _loadMetrics(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final m = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _card('Users', m['users']!, Icons.people_outline),
                    _card('Special Pickups', m['specialPickups']!, Icons.star_outline),
                    _card('Regular Pickups', m['regularPickups']!, Icons.delete_outline),
                    _card('Payments', m['payments']!, Icons.payment),
                    _card('Assigned Tasks', m['assignedTasks']!, Icons.assignment_ind),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Special Pickups by Status', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                FutureBuilder<List<_StatusSlice>>(
                  future: _specialPickupStatusBreakdown(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
                    final data = snap.data!;
                    return SizedBox(
                      height: 220,
                      child: SfCircularChart(
                        legend: const Legend(isVisible: true, position: LegendPosition.bottom),
                        series: <PieSeries<_StatusSlice, String>>[
                          PieSeries<_StatusSlice, String>(
                            dataSource: data,
                            xValueMapper: (_StatusSlice d, _) => d.status,
                            yValueMapper: (_StatusSlice d, _) => d.count,
                            dataLabelSettings: const DataLabelSettings(isVisible: true),
                          )
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text('Completed Special Pickups per Month', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                FutureBuilder<List<_MonthlyBar>>(
                  future: _completedPerMonth(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
                    final data = snap.data!;
                    return SizedBox(
                      height: 260,
                      child: SfCartesianChart(
                        primaryXAxis: CategoryAxis(),
                        series: <CartesianSeries<_MonthlyBar, String>>[
                          ColumnSeries<_MonthlyBar, String>(
                            dataSource: data,
                            xValueMapper: (_MonthlyBar d, _) => d.month,
                            yValueMapper: (_MonthlyBar d, _) => d.count,
                            dataLabelSettings: const DataLabelSettings(isVisible: true),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(String title, int value, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x1100AA88)),
              child: Icon(icon, color: const Color(0xFF00AA88)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(
                  value.toString(),
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _StatusSlice {
  _StatusSlice(this.status, this.count);
  final String status;
  final int count;
}

class _MonthlyBar {
  _MonthlyBar(this.month, this.count);
  final String month;
  final int count;
}