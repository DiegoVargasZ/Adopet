// lib/presentation/screens/roles/shelter_donations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

final _shelterDonationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser!.id;

  final shelter = await client
      .from('shelters')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();

  if (shelter == null) return [];

  final data = await client
      .from('donations')
      .select('*, profiles(full_name)')
      .eq('shelter_id', shelter['id'] as String)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(data as List);
});

class ShelterDonationsScreen extends ConsumerStatefulWidget {
  const ShelterDonationsScreen({super.key});

  @override
  ConsumerState<ShelterDonationsScreen> createState() =>
      _ShelterDonationsScreenState();
}

class _ShelterDonationsScreenState
    extends ConsumerState<ShelterDonationsScreen> {
  bool _exporting = false;

  // ── Exportar PDF ──────────────────────────────────────────────────

  Future<void> _exportPdf(List<Map<String, dynamic>> donations) async {
    setState(() => _exporting = true);
    try {
      final dateFmt  = DateFormat('dd/MM/yyyy', 'es');
      final timeFmt  = DateFormat('dd/MM/yyyy HH:mm', 'es');
      final today    = dateFmt.format(DateTime.now());
      final total    = donations.fold(
          0.0, (s, d) => s + (d['amount'] as num).toDouble());

      final doc = pw.Document(title: 'Donaciones');

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Reporte de Donaciones',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'AdoptaPet',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#FF6B35')),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generado el $today',
                style: pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey600),
              ),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
            ],
          ),
          footer: (ctx) => pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'AdoptaPet — Reporte de Donaciones',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey),
                  ),
                  pw.Text(
                    'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey),
                  ),
                ],
              ),
            ],
          ),
          build: (ctx) => [
            // ── Tarjeta de resumen ──────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F0F9F4'),
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8)),
                border: pw.Border.all(
                    color: PdfColor.fromHex('#B7DFC8'), width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfStat('Total recaudado',
                      'Bs. ${total.toStringAsFixed(2)}', true),
                  _pdfDivider(),
                  _pdfStat('Donaciones', '${donations.length}', false),
                  _pdfDivider(),
                  _pdfStat('Promedio',
                      donations.isEmpty
                          ? 'Bs. 0.00'
                          : 'Bs. ${(total / donations.length).toStringAsFixed(2)}',
                      false),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // ── Tabla de donaciones ──────────────────────────
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(78),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FixedColumnWidth(74),
                3: const pw.FlexColumnWidth(3),
              },
              children: [
                // Encabezado
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2D6A4F'),
                  ),
                  children: ['Fecha', 'Donante', 'Monto (Bs.)', 'Mensaje']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 7),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ))
                      .toList(),
                ),

                // Filas de datos
                ...donations.asMap().entries.map((entry) {
                  final i = entry.key;
                  final d = entry.value;
                  final profile =
                      d['profiles'] as Map<String, dynamic>?;
                  final dt = DateTime.parse(d['created_at'] as String)
                      .toLocal();
                  final isEven = i % 2 == 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      timeFmt.format(dt),
                      profile?['full_name'] as String? ??
                          'Donante anónimo',
                      (d['amount'] as num).toStringAsFixed(2),
                      d['message'] as String? ?? '',
                    ]
                        .map((text) => pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 5),
                              child: pw.Text(
                                text,
                                style:
                                    const pw.TextStyle(fontSize: 9),
                              ),
                            ))
                        .toList(),
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 12),

            // Total al pie de la tabla
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#2D6A4F'),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  'TOTAL: Bs. ${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name:
            'donaciones_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  pw.Widget _pdfStat(String label, String value, bool highlight) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(
                fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: highlight ? 16 : 14,
            fontWeight: pw.FontWeight.bold,
            color: highlight
                ? PdfColor.fromHex('#2D6A4F')
                : PdfColors.black,
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfDivider() => pw.Container(
        width: 0.5, height: 36, color: PdfColors.grey300);

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asyncDonations = ref.watch(_shelterDonationsProvider);
    final dateFmt = DateFormat('d MMM yyyy', 'es');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donaciones recibidas'),
        actions: [
          asyncDonations.maybeWhen(
            data: (donations) => donations.isEmpty
                ? const SizedBox.shrink()
                : _exporting
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        tooltip: 'Exportar PDF',
                        onPressed: () => _exportPdf(donations),
                      ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_shelterDonationsProvider),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: asyncDonations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Error al cargar donaciones'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(_shelterDonationsProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (donations) {
          if (donations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.volunteer_activism_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aún no hay donaciones',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final total = donations.fold(
              0.0, (s, d) => s + (d['amount'] as num).toDouble());

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(_shelterDonationsProvider),
            color: AppTheme.secondary,
            child: Column(
              children: [
                // ── Resumen ──────────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.secondary,
                        AppTheme.secondary.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total recaudado',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            'Bs. ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Donaciones',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            '${donations.length}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Nota de exportar (solo primera vez) ──
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.secondary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined,
                          color: AppTheme.secondary, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Toca el ícono PDF en la barra superior para exportar el reporte.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Lista ────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: donations.length,
                    separatorBuilder: (_, i) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final d       = donations[i];
                      final profile =
                          d['profiles'] as Map<String, dynamic>?;
                      final dt = DateTime.parse(
                              d['created_at'] as String)
                          .toLocal();
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.volunteer_activism,
                              color: AppTheme.secondary),
                        ),
                        title: Text(
                          'Bs. ${(d['amount'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?['full_name'] as String? ??
                                  'Donante anónimo',
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (d['message'] != null &&
                                (d['message'] as String).isNotEmpty)
                              Text(
                                '"${d['message']}"',
                                style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              dateFmt.format(dt),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Recibida',
                            style: TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
