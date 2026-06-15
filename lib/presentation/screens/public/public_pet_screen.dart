// lib/presentation/screens/public/public_pet_screen.dart
//
// Página PÚBLICA — no requiere autenticación.
// Se abre cuando alguien escanea el QR de una mascota.
//
// Para que funcione sin login, ejecuta en Supabase:
//   CREATE POLICY "Public puede ver mascotas" ON pets
//     FOR SELECT TO anon USING (true);
//   CREATE POLICY "Public puede ver refugios" ON shelters
//     FOR SELECT TO anon USING (true);

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

class PublicPetScreen extends StatefulWidget {
  final String petId;
  const PublicPetScreen({super.key, required this.petId});

  @override
  State<PublicPetScreen> createState() => _PublicPetScreenState();
}

class _PublicPetScreenState extends State<PublicPetScreen> {
  Map<String, dynamic>? _pet;
  Map<String, dynamic>? _shelter;
  bool   _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Usa la anon key — no requiere sesión activa.
      // Si hay RLS restrictivo, lanzará un error de permisos.
      final petData = await Supabase.instance.client
          .from('pets')
          .select()
          .eq('id', widget.petId)
          .maybeSingle();

      if (petData == null) {
        if (mounted) setState(() { _error = 'Mascota no encontrada.'; _loading = false; });
        return;
      }

      Map<String, dynamic>? shelterData;
      final shelterId = petData['shelter_id'] as String?;
      if (shelterId != null) {
        shelterData = await Supabase.instance.client
            .from('shelters')
            .select()
            .eq('id', shelterId)
            .maybeSingle();
      }

      if (mounted) {
        setState(() {
          _pet     = petData;
          _shelter = shelterData;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString().contains('permission')
              ? 'Acceso denegado. El administrador debe habilitar '
                'la lectura pública en Supabase.'
              : 'Error al cargar: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  // ── helpers ─────────────────────────────────────────────────────
  String _species(dynamic v) {
    final s = v?.toString() ?? '';
    return s == 'dog' ? 'Perro' : s == 'cat' ? 'Gato' : s.isEmpty ? '' : s;
  }

  String _gender(dynamic v) {
    final s = v?.toString() ?? '';
    return s == 'male' ? 'Macho' : s == 'female' ? 'Hembra' : s.isEmpty ? '' : s;
  }

  String _age(dynamic v) {
    final m = v is int ? v : int.tryParse(v?.toString() ?? '');
    if (m == null) return 'Desconocida';
    if (m < 12)   return '$m ${m == 1 ? "mes" : "meses"}';
    final y = m ~/ 12;
    return '$y ${y == 1 ? "año" : "años"}';
  }

  String _bool(dynamic v) => v == true ? 'Sí' : v == false ? 'No' : '';

  String _fmtVal(String key, dynamic val) {
    if (val == null) return '';
    if (key == 'species')    return _species(val);
    if (key == 'gender')     return _gender(val);
    if (key == 'age_months') return _age(val);
    if (key == 'is_adopted') return val == true ? 'Ya fue adoptado' : 'Disponible para adopción';
    if (val is bool)         return _bool(val);
    return val.toString();
  }

  static const Map<String, String> _labels = {
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

  static const Set<String> _skip = {
    'id', 'shelter_id', 'image_url', 'extra_images',
    'created_at', 'updated_at', 'qr_url', 'name', 'description',
  };

  static const Set<String> _shelterSkip = {
    'id', 'user_id', 'image_url', 'lat', 'lng',
    'latitude', 'longitude', 'created_at', 'updated_at',
    'name', 'description',
  };

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _launchWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri   = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final name = _pet?['name']?.toString() ?? 'Mascota';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Text(name),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text('Cargando información...',
                style: TextStyle(color: AppTheme.textSub)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, size: 64, color: AppTheme.primary),
              const SizedBox(height: 20),
              const Text('No se pudo cargar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSub)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final pet     = _pet!;
    final shelter = _shelter ?? {};

    final imageUrl  = pet['image_url']?.toString();
    final name      = pet['name']?.toString() ?? '';
    final desc      = pet['description']?.toString() ?? '';
    final isAdopted = pet['is_adopted'] == true;
    final species   = _species(pet['species']);
    final gender    = _gender(pet['gender']);
    final age       = _age(pet['age_months']);

    // Campos adicionales del animal
    const orderedKeys = [
      'species', 'breed', 'gender', 'age_months', 'is_adopted',
      'color', 'size', 'weight_kg', 'vaccinated', 'dewormed',
      'sterilized', 'microchip', 'good_with_kids',
      'good_with_dogs', 'good_with_cats', 'personality', 'health_notes',
    ];

    final dataRows = <_Row>[];
    for (final key in orderedKeys) {
      final val = pet[key];
      if (val == null || val.toString().isEmpty) continue;
      dataRows.add(_Row(_labels[key] ?? key, _fmtVal(key, val)));
    }
    for (final e in pet.entries) {
      if (_skip.contains(e.key)) continue;
      if (orderedKeys.contains(e.key)) continue;
      final val = e.value;
      if (val == null || val.toString().isEmpty) continue;
      dataRows.add(_Row(_labels[e.key] ?? e.key, _fmtVal(e.key, val)));
    }

    // Refugio
    final shelterName  = shelter['name']?.toString();
    final shelterDesc  = shelter['description']?.toString() ?? '';
    final address      = shelter['address']?.toString();
    final phone        = shelter['phone']?.toString();
    final email        = shelter['email']?.toString();

    final extraShelter = <_Row>[];
    for (final e in shelter.entries) {
      if (_shelterSkip.contains(e.key)) continue;
      if ({'phone','email','address','name','description'}.contains(e.key)) continue;
      final val = e.value;
      if (val == null || val.toString().isEmpty) continue;
      extraShelter.add(_Row(e.key, val.toString()));
    }

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Foto ─────────────────────────────────────────────
              if (imageUrl != null && imageUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, s) => Container(
                      color: AppTheme.surface,
                      child: const Icon(Icons.pets,
                          size: 80, color: AppTheme.primary),
                    ),
                  ),
                )
              else
                Container(
                  height: 180,
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.pets,
                      size: 80, color: AppTheme.primary),
                ),

              // ── Cabecera ──────────────────────────────────────────
              Container(
                color: AppTheme.primary,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        _StatusPill(isAdopted: isAdopted),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (species.isNotEmpty) _WhiteTag(species),
                        if (gender.isNotEmpty)  _WhiteTag(gender),
                        _WhiteTag(age),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Ficha de datos ────────────────────────────────────
              if (dataRows.isNotEmpty)
                _Card(
                  icon: Icons.fact_check_outlined,
                  title: 'Datos del animal',
                  child: Column(
                    children: dataRows
                        .map((r) => _FieldRow(r.label, r.value))
                        .toList(),
                  ),
                ),

              const SizedBox(height: 12),

              // ── Descripción ───────────────────────────────────────
              if (desc.isNotEmpty)
                _Card(
                  icon: Icons.notes_outlined,
                  title: 'Historia de $name',
                  child: Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppTheme.textMain,
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // ── Refugio ───────────────────────────────────────────
              if (shelter.isNotEmpty)
                _Card(
                  icon: Icons.home_work_outlined,
                  title: 'Dónde vive actualmente',
                  color: const Color(0xFFF0FAF4),
                  titleColor: const Color(0xFF2D6A4F),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      if (shelterName != null) ...[
                        Text(
                          shelterName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      if (shelterDesc.isNotEmpty) ...[
                        Text(
                          shelterDesc,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSub,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (address != null)
                        _IconRow(
                          icon: Icons.location_on_outlined,
                          text: address,
                        ),

                      ...extraShelter.map(
                          (r) => _FieldRow(r.label, r.value)),

                      // Botones de contacto
                      if (phone != null || email != null) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Text(
                          'Contactar al refugio',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textSub,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (phone != null) ...[
                          _IconRow(
                            icon: Icons.phone_outlined,
                            text: phone,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _ContactBtn(
                                  icon: Icons.call_outlined,
                                  label: 'Llamar',
                                  color: const Color(0xFF2D6A4F),
                                  onTap: () => _launchPhone(phone),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ContactBtn(
                                  icon: Icons.chat_outlined,
                                  label: 'WhatsApp',
                                  color: const Color(0xFF25D366),
                                  onTap: () => _launchWhatsApp(phone),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (email != null) ...[
                          const SizedBox(height: 10),
                          _IconRow(
                            icon: Icons.email_outlined,
                            text: email,
                          ),
                          const SizedBox(height: 8),
                          _ContactBtn(
                            icon: Icons.email_outlined,
                            label: 'Enviar correo a $email',
                            color: AppTheme.primary,
                            onTap: () => _launchEmail(email),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

              // ── Footer ────────────────────────────────────────────
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.pets,
                        size: 16, color: AppTheme.textSub),
                    const SizedBox(width: 6),
                    const Text(
                      'AdoptaPet Bolivia',
                      style: TextStyle(
                          color: AppTheme.textSub, fontSize: 12),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.petId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('ID copiado'),
                              duration: Duration(seconds: 1)),
                        );
                      },
                      child: Text(
                        'ID: ${widget.petId.substring(0, 8)}...',
                        style: const TextStyle(
                          color: AppTheme.textSub,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
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

// ── Modelos y widgets de apoyo ────────────────────────────────────

class _Row {
  final String label, value;
  const _Row(this.label, this.value);
}

class _StatusPill extends StatelessWidget {
  final bool isAdopted;
  const _StatusPill({required this.isAdopted});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isAdopted
              ? Colors.orange.withValues(alpha: 0.2)
              : const Color(0xFF6FCF97).withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isAdopted ? Colors.orange.shade200 : const Color(0xFF6FCF97),
          ),
        ),
        child: Text(
          isAdopted ? 'Adoptado' : 'En adopción',
          style: TextStyle(
            color: isAdopted ? Colors.orange.shade200 : const Color(0xFF6FCF97),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
}

class _WhiteTag extends StatelessWidget {
  final String label;
  const _WhiteTag(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );
}

class _Card extends StatelessWidget {
  final IconData   icon;
  final String     title;
  final Widget     child;
  final Color      color;
  final Color      titleColor;

  const _Card({
    required this.icon,
    required this.title,
    required this.child,
    this.color      = Colors.white,
    this.titleColor = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: titleColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );
}

class _FieldRow extends StatelessWidget {
  final String label, value;
  const _FieldRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textSub),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textMain),
              ),
            ),
          ],
        ),
      );
}

class _IconRow extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _IconRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: AppTheme.textSub),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textMain)),
            ),
          ],
        ),
      );
}

class _ContactBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  const _ContactBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 46),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      );
}
