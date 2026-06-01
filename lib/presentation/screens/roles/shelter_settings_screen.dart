// lib/presentation/screens/roles/shelter_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/shelter.dart';
import '../../../data/services/shelter_service.dart';
import 'location_picker_screen.dart';

final _myShelterProvider =
    FutureProvider.autoDispose<Shelter?>((ref) => ShelterService().getMyShelter());

class ShelterSettingsScreen extends ConsumerStatefulWidget {
  const ShelterSettingsScreen({super.key});

  @override
  ConsumerState<ShelterSettingsScreen> createState() =>
      _ShelterSettingsScreenState();
}

class _ShelterSettingsScreenState
    extends ConsumerState<ShelterSettingsScreen> {
  final _service  = ShelterService();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String?  _shelterId;
  LatLng?  _location;
  String?  _imageUrl;
  String?  _qrUrl;
  bool     _saving    = false;
  bool     _upImgBusy = false;
  bool     _upQrBusy  = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // Inicializa los campos la primera vez que llega el shelter
  void _initFrom(Shelter s) {
    if (_shelterId == s.id) return; // ya inicializado
    _shelterId = s.id;

    // Defer setState para no modificar estado durante build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _imageUrl = s.imageUrl;
        _qrUrl    = s.qrUrl;
        _location = (s.latitude != 0 || s.longitude != 0)
            ? LatLng(s.latitude, s.longitude)
            : null;
      });
      _nameCtrl.text  = s.name;
      _descCtrl.text  = s.description ?? '';
      _addrCtrl.text  = s.address ?? '';
      _phoneCtrl.text = s.phone ?? '';
      _emailCtrl.text = s.email ?? '';
    });
  }

  // ── Subir imagen del refugio ──────────────────────────────
  Future<void> _pickShelterImage() async {
    if (_shelterId == null) return;
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (file == null) return;

    setState(() => _upImgBusy = true);
    try {
      final bytes = await file.readAsBytes();
      final ext   = file.name.split('.').last.toLowerCase();
      final url   = await _service.uploadShelterImage(_shelterId!, bytes, ext);
      if (mounted) setState(() => _imageUrl = url);
    } catch (e) {
      _snack('Error al subir imagen: $e');
    } finally {
      if (mounted) setState(() => _upImgBusy = false);
    }
  }

  // ── Subir QR de donaciones ────────────────────────────────
  Future<void> _pickQr() async {
    if (_shelterId == null) return;
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (file == null) return;

    setState(() => _upQrBusy = true);
    try {
      final bytes = await file.readAsBytes();
      final ext   = file.name.split('.').last.toLowerCase();
      final url   = await _service.uploadQrImage(_shelterId!, bytes, ext);
      if (mounted) setState(() => _qrUrl = url);
    } catch (e) {
      _snack('Error al subir QR: $e');
    } finally {
      if (mounted) setState(() => _upQrBusy = false);
    }
  }

  // ── Seleccionar ubicación en el mapa ──────────────────────
  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initial: _location),
      ),
    );
    if (result != null && mounted) setState(() => _location = result);
  }

  // ── Guardar cambios ───────────────────────────────────────
  Future<void> _save() async {
    if (_shelterId == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('El nombre del refugio es obligatorio');
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.updateShelter(
        shelterId:   _shelterId!,
        name:        name,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        address:     _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim(),
        phone:       _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email:       _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        imageUrl:    _imageUrl,
        qrUrl:       _qrUrl,
        latitude:    _location?.latitude,
        longitude:   _location?.longitude,
      );
      // Resetear para que al volver los datos se recarguen
      _shelterId = null;
      ref.invalidate(_myShelterProvider);
      _snack('¡Refugio actualizado correctamente!');
    } catch (e) {
      _snack('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final asyncShelter = ref.watch(_myShelterProvider);

    // Inicializar cuando llegan los datos (sin modificar estado durante build)
    asyncShelter.whenData((s) { if (s != null) _initFrom(s); });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Mi refugio'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Guardar',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: asyncShelter.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: '$e',
          onRetry: () => ref.invalidate(_myShelterProvider),
        ),
        data: (shelter) {
          if (shelter == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home_work_outlined,
                        size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No tienes un refugio registrado.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Solicita el rol de refugio desde el menú principal.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Foto del refugio ─────────────────────────
                _SectionLabel(icon: Icons.photo_camera, label: 'Foto del refugio'),
                const SizedBox(height: 10),
                _UploadCard(
                  imageUrl: _imageUrl,
                  busy: _upImgBusy,
                  onTap: _upImgBusy ? null : _pickShelterImage,
                  hint: 'Toca para agregar una foto',
                  height: 170,
                ),

                const SizedBox(height: 24),

                // ── Información básica ───────────────────────
                _SectionLabel(icon: Icons.info_outline, label: 'Información'),
                const SizedBox(height: 10),
                _InfoCard(children: [
                  _Row(
                    icon: Icons.home_work_outlined,
                    child: TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del refugio *',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _Row(
                    icon: Icons.description_outlined,
                    child: TextField(
                      controller: _descCtrl,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                    top: true,
                  ),
                  const Divider(height: 1),
                  _Row(
                    icon: Icons.location_on_outlined,
                    child: TextField(
                      controller: _addrCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _Row(
                    icon: Icons.phone_outlined,
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _Row(
                    icon: Icons.email_outlined,
                    child: TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Ubicación en el mapa ─────────────────────
                _SectionLabel(icon: Icons.map_outlined, label: 'Ubicación en el mapa'),
                const SizedBox(height: 4),
                const Text(
                  'Marca el punto exacto donde está tu refugio.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 10),
                _InfoCard(children: [
                  // Preview del mapa — solo si hay ubicación
                  if (_location != null)
                    LayoutBuilder(
                      builder: (_, constraints) => IgnorePointer(
                        child: SizedBox(
                          height: 150,
                          width: constraints.maxWidth,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: _location!,
                                initialZoom: 15,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none,
                                ),
                              ),
                              children: [
                                // IgnorePointer evita que los tiles asíncronos
                                // disparen box.dart:2251 en el mouse tracker
                                IgnorePointer(
                                  child: TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.adoptapet.app',
                                  ),
                                ),
                                MarkerLayer(markers: [
                                  Marker(
                                    point: _location!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: AppTheme.primary,
                                      size: 40,
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _location != null
                                ? 'Lat: ${_location!.latitude.toStringAsFixed(5)}\n'
                                    'Lng: ${_location!.longitude.toStringAsFixed(5)}'
                                : 'Sin ubicación configurada',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _pickLocation,
                          icon: const Icon(Icons.edit_location_alt, size: 18),
                          label: Text(_location != null
                              ? 'Cambiar'
                              : 'Configurar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── QR para donaciones ───────────────────────
                _SectionLabel(icon: Icons.qr_code, label: 'QR para donaciones'),
                const SizedBox(height: 4),
                const Text(
                  'Sube el QR de tu banco o billetera para recibir donaciones directas.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 10),
                _UploadCard(
                  imageUrl: _qrUrl,
                  busy: _upQrBusy,
                  onTap: _upQrBusy ? null : _pickQr,
                  hint: 'Toca para subir tu código QR',
                  height: 220,
                  isQr: true,
                ),

                const SizedBox(height: 32),

                // ── Botón guardar ────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Guardando...' : 'Guardar cambios',
                      style: const TextStyle(fontSize: 16),
                    ),
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

// ─── Widgets internos ──────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      );
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Widget child;
  final bool top;
  const _Row({required this.icon, required this.child, this.top = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Row(
          crossAxisAlignment:
              top ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(top: top ? 14.0 : 0),
              child: Icon(icon, size: 18, color: Colors.grey.shade400),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ),
      );
}

/// Tarjeta para subir imagen — usa Material+InkWell (no GestureDetector)
class _UploadCard extends StatelessWidget {
  final String? imageUrl;
  final bool busy;
  final VoidCallback? onTap;
  final String hint;
  final double height;
  final bool isQr;

  const _UploadCard({
    required this.imageUrl,
    required this.busy,
    required this.onTap,
    required this.hint,
    required this.height,
    this.isQr = false,
  });

  @override
  Widget build(BuildContext context) {
    // Container exterior lleva el boxShadow (fuera del clip de Material)
    // InkWell > Container interior lleva solo el border (sin Ink, evita
    // box.dart:2251 / mouse_tracker assertion en Flutter Web)
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.primary.withOpacity(0.25), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: _body(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (busy) return const Center(child: CircularProgressIndicator());

    if (imageUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl!,
            fit: isQr ? BoxFit.contain : BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text('Cambiar',
                      style:
                          TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return _placeholder();
  }

  Widget _placeholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isQr ? Icons.qr_code_2 : Icons.add_photo_alternate_outlined,
            size: 52,
            color: AppTheme.primary.withOpacity(0.35),
          ),
          const SizedBox(height: 10),
          Text(hint,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Toca para seleccionar',
              style: TextStyle(
                  color: AppTheme.primary.withOpacity(0.6), fontSize: 12)),
        ],
      );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error al cargar el refugio',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(error,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
}
