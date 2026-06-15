// lib/presentation/screens/pets/pet_qr_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/pet.dart';

class PetQrScreen extends StatefulWidget {
  final Pet pet;
  const PetQrScreen({super.key, required this.pet});

  @override
  State<PetQrScreen> createState() => _PetQrScreenState();
}

class _PetQrScreenState extends State<PetQrScreen> {
  Map<String, dynamic>? _rawPet;
  Map<String, dynamic>? _rawShelter;

  bool _loading       = true;
  bool _generatingPdf = false;
  String? _error;

  final GlobalKey _qrRepaintKey = GlobalKey();

  // ── Campos a omitir en el PDF / texto ────────────────────────
  static const Set<String> _petSkip = {
    'id', 'shelter_id', 'image_url', 'extra_images',
    'created_at', 'updated_at', 'qr_url',
  };
  static const Set<String> _shelterSkip = {
    'id', 'user_id', 'image_url', 'lat', 'lng',
    'latitude', 'longitude', 'created_at', 'updated_at',
  };
  static const Map<String, String> _petLabels = {
    'name':         'Nombre',
    'species':      'Especie',
    'breed':        'Raza',
    'gender':       'Género',
    'age_months':   'Edad',
    'is_adopted':   'Estado',
    'color':        'Color',
    'size':         'Tamaño',
    'weight_kg':    'Peso (kg)',
    'vaccinated':   'Vacunado',
    'dewormed':     'Desparasitado',
    'sterilized':   'Esterilizado',
    'microchip':    'Microchip',
    'personality':  'Personalidad',
    'health_notes': 'Notas de salud',
    'good_with_kids':  'Con niños',
    'good_with_dogs':  'Con perros',
    'good_with_cats':  'Con gatos',
  };
  static const Map<String, String> _shelterLabels = {
    'name':        'Refugio',
    'description': 'Descripción',
    'address':     'Dirección',
    'phone':       'Teléfono',
    'email':       'Correo',
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ── Carga SELECT * desde Supabase ─────────────────────────────
  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rawPet = await Supabase.instance.client
          .from('pets')
          .select()
          .eq('id', widget.pet.id)
          .maybeSingle();

      Map<String, dynamic>? rawShelter;
      final shelterId = (rawPet?['shelter_id'] as String?)
          ?? widget.pet.shelterId;
      if (shelterId != null) {
        rawShelter = await Supabase.instance.client
            .from('shelters')
            .select()
            .eq('id', shelterId)
            .maybeSingle();
      }
      if (mounted) {
        setState(() {
          _rawPet     = rawPet;
          _rawShelter = rawShelter;
          _loading    = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Texto completo que va dentro del QR ──────────────────────
  // Al escanear, el celular muestra todo el texto con los datos del animal.
  String get _qrData {
    final pet     = _rawPet     ?? {};
    final shelter = _rawShelter ?? {};
    final buf     = StringBuffer();

    // Encabezado
    buf.writeln('ADOPTAPET - FICHA DE MASCOTA');
    buf.writeln('============================');

    // Datos del animal
    void add(String label, dynamic val, {String? formatted}) {
      final text = formatted ?? val?.toString() ?? '';
      if (text.isNotEmpty) buf.writeln('$label: $text');
    }

    add('Nombre',  pet['name']);
    add('Especie', pet['species'],    formatted: _speciesLabel(pet['species']));
    add('Raza',    pet['breed']);
    add('Genero',  pet['gender'],     formatted: _genderLabel(pet['gender']));
    add('Edad',    pet['age_months'], formatted: pet['age_months'] != null ? _ageLabel(pet['age_months']) : null);
    add('Estado',  pet['is_adopted'] == true ? 'Ya fue adoptado' : 'Disponible para adopcion');
    add('Color',   pet['color']);
    add('Tamano',  pet['size']);
    add('Peso',    pet['weight_kg'] != null ? '${pet['weight_kg']} kg' : null);

    // Campos de salud y comportamiento
    _boolField(buf, pet, 'vaccinated',   'Vacunado');
    _boolField(buf, pet, 'dewormed',     'Desparasitado');
    _boolField(buf, pet, 'sterilized',   'Esterilizado');
    _boolField(buf, pet, 'microchip',    'Microchip');
    _boolField(buf, pet, 'good_with_kids', 'Bueno con ninos');
    _boolField(buf, pet, 'good_with_dogs', 'Bueno con perros');
    _boolField(buf, pet, 'good_with_cats', 'Bueno con gatos');
    add('Personalidad', pet['personality']);
    add('Notas de salud', pet['health_notes']);

    // Descripción
    final desc = pet['description']?.toString() ?? '';
    if (desc.isNotEmpty) {
      buf.writeln();
      buf.writeln('DESCRIPCION');
      buf.writeln(desc);
    }

    // Refugio
    if (shelter.isNotEmpty) {
      buf.writeln();
      buf.writeln('DONDE VIVE ACTUALMENTE');
      buf.writeln('----------------------');
      add('Refugio',   shelter['name']);
      add('Direccion', shelter['address']);

      add('Email', shelter['email']);

      final shelterDesc = shelter['description']?.toString() ?? '';
      if (shelterDesc.isNotEmpty) {
        buf.writeln('Info: $shelterDesc');
      }
    }

    buf.writeln();
    buf.write('AdoptaPet Bolivia');
    return buf.toString().trim();
  }

  static void _boolField(StringBuffer buf, Map<String,dynamic> map,
      String key, String label) {
    final v = map[key];
    if (v == true)  buf.writeln('$label: Si');
    if (v == false) buf.writeln('$label: No');
  }

  // ── Helpers ───────────────────────────────────────────────────
  String _speciesLabel(dynamic v) {
    final s = v?.toString() ?? '';
    return s == 'dog' ? 'Perro' : s == 'cat' ? 'Gato' : s;
  }
  String _genderLabel(dynamic v) {
    final s = v?.toString() ?? '';
    return s == 'male' ? 'Macho' : s == 'female' ? 'Hembra' : s;
  }
  String _ageLabel(dynamic v) {
    final m = v is int ? v : int.tryParse(v?.toString() ?? '');
    if (m == null) return 'Desconocida';
    if (m < 12)   return '$m ${m == 1 ? "mes" : "meses"}';
    final y = m ~/ 12;
    return '$y ${y == 1 ? "año" : "años"}';
  }
  String _fmtVal(String key, dynamic val) {
    if (val == null) return '';
    if (key == 'species')    return _speciesLabel(val);
    if (key == 'gender')     return _genderLabel(val);
    if (key == 'age_months') return _ageLabel(val);
    if (key == 'is_adopted') return val == true ? 'Ya fue adoptado' : 'Disponible para adopción';
    if (val is bool)         return val ? 'Sí' : 'No';
    return val.toString();
  }

  // ── Generar PDF ────────────────────────────────────────────────
  Future<void> _generatePdf() async {
    setState(() => _generatingPdf = true);
    try {
      // Capturar QR
      Uint8List? qrBytes;
      try {
        final boundary = _qrRepaintKey.currentContext
            ?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final img = await boundary.toImage(pixelRatio: 4.0);
          final bd  = await img.toByteData(format: ui.ImageByteFormat.png);
          qrBytes   = bd?.buffer.asUint8List();
        }
      } catch (_) {}

      // Foto del animal
      Uint8List? petImageBytes;
      final imageUrl = (_rawPet?['image_url'] as String?) ?? widget.pet.imageUrl;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final resp = await http.get(Uri.parse(imageUrl));
          if (resp.statusCode == 200) petImageBytes = resp.bodyBytes;
        } catch (_) {}
      }

      final pet     = _rawPet ?? {};
      final shelter = _rawShelter ?? {};

      final petName   = pet['name']?.toString() ?? widget.pet.name;
      final petDesc   = pet['description']?.toString() ?? '';
      final isAdopted = pet['is_adopted'] == true;
      final species   = _speciesLabel(pet['species']);
      final gender    = pet['gender'] != null ? _genderLabel(pet['gender']) : null;
      final age       = pet['age_months'] != null ? _ageLabel(pet['age_months']) : null;

      // Filas del animal
      const petOrder = [
        'species', 'breed', 'gender', 'age_months', 'is_adopted',
        'color', 'size', 'weight_kg', 'vaccinated', 'dewormed',
        'sterilized', 'microchip', 'good_with_kids', 'good_with_dogs',
        'good_with_cats', 'personality', 'health_notes',
      ];
      final petRows = <_Row>[];
      for (final k in petOrder) {
        final v = pet[k];
        if (v == null || v.toString().isEmpty) continue;
        petRows.add(_Row(_petLabels[k] ?? k, _fmtVal(k, v)));
      }
      for (final e in pet.entries) {
        if (_petSkip.contains(e.key)) continue;
        if (petOrder.contains(e.key) || e.key == 'name' || e.key == 'description') continue;
        if (e.value == null || e.value.toString().isEmpty) continue;
        petRows.add(_Row(_petLabels[e.key] ?? e.key, _fmtVal(e.key, e.value)));
      }

      // Filas del refugio
      final shelterName  = shelter['name']?.toString();
      final shelterDesc  = shelter['description']?.toString() ?? '';
      final shelterOrder = ['address', 'phone', 'email'];
      final shelterRows  = <_Row>[];
      for (final k in shelterOrder) {
        final v = shelter[k];
        if (v == null || v.toString().isEmpty) continue;
        shelterRows.add(_Row(_shelterLabels[k] ?? k, v.toString()));
      }
      for (final e in shelter.entries) {
        if (_shelterSkip.contains(e.key)) continue;
        if ({'name','description','address','phone','email'}.contains(e.key)) continue;
        if (e.value == null || e.value.toString().isEmpty) continue;
        shelterRows.add(_Row(e.key, e.value.toString()));
      }

      // ── Construcción del PDF ───────────────────────────────────
      final doc    = pw.Document(
          title: 'Ficha de $petName', author: 'AdoptaPet Bolivia');
      final fontR  = pw.Font.helvetica();
      final fontB  = pw.Font.helveticaBold();

      final orange  = PdfColor.fromHex('#F2994A');
      final green   = PdfColor.fromHex('#2D6A4F');
      final grey    = PdfColor.fromHex('#555555');
      final line    = PdfColor.fromHex('#DDDDDD');
      final bgGrey  = PdfColor.fromHex('#F5F5F5');
      final bgGreen = PdfColor.fromHex('#F0FAF4');

      pw.TextStyle ts(double sz, {pw.Font? font, PdfColor? color}) =>
          pw.TextStyle(font: font ?? fontR, fontSize: sz,
              color: color ?? PdfColors.black);

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Cabecera
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: orange,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (petImageBytes != null) ...[
                    pw.Container(
                      width: 76, height: 76,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.white, width: 2),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Image(pw.MemoryImage(petImageBytes),
                          fit: pw.BoxFit.cover, width: 76, height: 76),
                    ),
                    pw.SizedBox(width: 14),
                  ],
                  pw.Expanded(child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(petName, style: ts(24, font: fontB, color: PdfColors.white)),
                      pw.SizedBox(height: 5),
                      pw.Row(children: [
                        _chip(fontB, species),
                        if (gender != null) ...[pw.SizedBox(width: 5), _chip(fontB, gender)],
                        if (age    != null) ...[pw.SizedBox(width: 5), _chip(fontB, age)],
                      ]),
                      pw.SizedBox(height: 7),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: isAdopted ? PdfColors.orange200 : PdfColors.lightGreen200,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Text(
                          isAdopted ? 'Ya fue adoptado' : 'Disponible para adopción',
                          style: ts(9, font: fontB,
                              color: isAdopted ? PdfColors.deepOrange900 : PdfColors.green900),
                        ),
                      ),
                    ],
                  )),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Cuerpo en dos columnas
            pw.Expanded(child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [

                // Columna izquierda
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [

                    // Datos del animal
                    if (petRows.isNotEmpty)
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: bgGrey,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Datos del animal',
                                style: ts(10, font: fontB, color: orange)),
                            pw.SizedBox(height: 8),
                            ...petRows.map((r) => _pdfRow(fontB, fontR, grey, r.label, r.value)),
                          ],
                        ),
                      ),

                    // Descripción
                    if (petDesc.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: line),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Historia', style: ts(10, font: fontB, color: orange)),
                            pw.SizedBox(height: 6),
                            pw.Text(petDesc, style: ts(10, color: grey)),
                          ],
                        ),
                      ),
                    ],

                    // Refugio
                    if (shelter.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: bgGreen,
                          border: pw.Border.all(color: PdfColor.fromHex('#C8E6C9')),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Dónde vive actualmente',
                                style: ts(10, font: fontB, color: green)),
                            pw.SizedBox(height: 8),
                            if (shelterName != null)
                              _pdfRow(fontB, fontR, grey, 'Refugio', shelterName),
                            ...shelterRows.map((r) => _pdfRow(fontB, fontR, grey, r.label, r.value)),
                            if (shelterDesc.isNotEmpty) ...[
                              pw.SizedBox(height: 5),
                              pw.Text(shelterDesc, style: ts(9, color: grey)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                )),

                pw.SizedBox(width: 14),

                // QR + enlace (derecha)
                pw.SizedBox(width: 124, child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: line),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: qrBytes != null
                          ? pw.Image(pw.MemoryImage(qrBytes), width: 106, height: 106)
                          : pw.SizedBox(width: 106, height: 106),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Escanea para ver\ntoda la información',
                      style: ts(7.5, color: grey),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Contiene nombre, especie,\nedad, descripcion y\ndatos del refugio.',
                      style: ts(6.5, color: grey),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                )),
              ],
            )),

            // Pie
            pw.SizedBox(height: 8),
            pw.Divider(color: line),
            pw.SizedBox(height: 4),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('AdoptaPet Bolivia · Cochabamba', style: ts(8, color: grey)),
                pw.Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                  style: ts(8, color: grey),
                ),
              ],
            ),
          ],
        ),
      ));

      await Printing.layoutPdf(
        onLayout: (_) => doc.save(),
        name: 'Ficha_${petName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  static pw.Widget _chip(pw.Font font, String label) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Text(label,
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.black)),
      );

  static pw.Widget _pdfRow(pw.Font bold, pw.Font reg, PdfColor vc,
          String label, String value) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 70,
              child: pw.Text('$label:',
                  style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.black))),
          pw.Expanded(
              child: pw.Text(value, style: pw.TextStyle(font: reg, fontSize: 10, color: vc))),
        ]),
      );

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _qrData));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Texto copiado al portapapeles'),
          duration: Duration(seconds: 2)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final petName = _rawPet?['name']?.toString() ?? widget.pet.name;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('QR · $petName'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_loading && _error == null)
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copiar texto',
              onPressed: _copyText,
            ),
          if (_error != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text('Cargando datos desde Supabase...',
                      style: TextStyle(color: AppTheme.textSub)),
                ],
              ),
            )
          : _error != null
              ? _buildError()
              : _buildContent(petName),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              const Text('No se pudieron cargar los datos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center, maxLines: 4),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );

  Widget _buildContent(String petName) {
    final pet     = _rawPet ?? {};
    final shelter = _rawShelter ?? {};

    final imageUrl  = pet['image_url']?.toString() ?? widget.pet.imageUrl;
    final isAdopted = pet['is_adopted'] == true;
    final species   = _speciesLabel(pet['species']);
    final gender    = pet['gender'] != null ? _genderLabel(pet['gender']) : null;
    final age       = pet['age_months'] != null ? _ageLabel(pet['age_months']) : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ── Tarjeta con QR ─────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabecera naranja
                    Container(
                      color: AppTheme.primary,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                      child: Row(
                        children: [
                          _PetAvatar(imageUrl: imageUrl, size: 60),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(petName,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 22,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  _WhiteTag(species),
                                  if (gender != null) _WhiteTag(gender),
                                  if (age    != null) _WhiteTag(age),
                                ]),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: isAdopted
                                          ? Colors.orange.shade200
                                          : const Color(0xFF6FCF97),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isAdopted
                                        ? 'Ya fue adoptado'
                                        : 'Disponible para adopción',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Nota explicativa
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.qr_code_scanner_outlined,
                              color: AppTheme.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(fontSize: 13, color: AppTheme.textMain),
                                children: [
                                  TextSpan(
                                    text: 'Escanea con cualquier cámara ',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(
                                    text: 'y verás directamente el texto con '
                                        'nombre, especie, edad, descripción, '
                                        'dirección y teléfono del refugio.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // QR
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.25),
                                width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(14),
                          child: RepaintBoundary(
                            key: _qrRepaintKey,
                            child: QrImageView(
                              data: _qrData,
                              version: QrVersions.auto,
                              size: 220,
                              errorCorrectionLevel: QrErrorCorrectLevel.L,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF1A1A1A)),
                              dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF1A1A1A)),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Vista previa del texto que contiene el QR
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: GestureDetector(
                        onTap: _copyText,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.text_snippet_outlined,
                                  size: 16, color: AppTheme.textSub),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _qrData,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSub,
                                    fontFamily: 'monospace',
                                    height: 1.5,
                                  ),
                                  maxLines: 6,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.copy_outlined,
                                  size: 15, color: AppTheme.textSub),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Resumen del refugio
                    if (shelter['name'] != null || shelter['phone'] != null ||
                        shelter['address'] != null) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.home_work_outlined,
                                  size: 16, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Text('Refugio actual',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.textMain)),
                            ]),
                            const SizedBox(height: 10),
                            if (shelter['name'] != null)
                              _ShelterRow(Icons.pets_outlined, shelter['name'].toString()),
                            if (shelter['address'] != null)
                              _ShelterRow(Icons.location_on_outlined, shelter['address'].toString()),
                            if (shelter['phone'] != null)
                              _ShelterRow(Icons.phone_outlined, shelter['phone'].toString()),
                            if (shelter['email'] != null)
                              _ShelterRow(Icons.email_outlined, shelter['email'].toString()),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Botón PDF
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _generatingPdf ? null : _generatePdf,
                  icon: _generatingPdf
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_generatingPdf ? 'Generando PDF...' : 'Generar / Imprimir PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Botón copiar texto
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _copyText,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copiar texto completo'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppTheme.primary.withValues(alpha: 0.4)),
                    foregroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.15)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Al escanear con la cámara del celular aparece directamente '
                        'el texto con todos los datos: nombre, especie, edad, '
                        'descripción, dirección y teléfono del refugio.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMain),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Modelo interno ────────────────────────────────────────────────
class _Row {
  final String label, value;
  const _Row(this.label, this.value);
}

// ── Widgets ───────────────────────────────────────────────────────
class _PetAvatar extends StatelessWidget {
  final String? imageUrl;
  final double  size;
  const _PetAvatar({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.2),
          border: Border.all(color: Colors.white, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(imageUrl!, fit: BoxFit.cover,
                errorBuilder: (ctx, e, s) =>
                    const Icon(Icons.pets, color: Colors.white, size: 30))
            : const Icon(Icons.pets, color: Colors.white, size: 30),
      );
}

class _WhiteTag extends StatelessWidget {
  final String label;
  const _WhiteTag(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}

class _ShelterRow extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _ShelterRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: AppTheme.textSub),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMain)),
            ),
          ],
        ),
      );
}
