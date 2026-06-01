// lib/presentation/screens/roles/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';

class LocationPickerScreen extends StatefulWidget {
  /// Coordenadas iniciales (las actuales del refugio, si existen)
  final LatLng? initial;

  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final MapController _mapCtrl;

  // Cochabamba como centro por defecto
  static const _defaultCenter = LatLng(-17.3895, -66.1568);

  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
    _selected = widget.initial;
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.initial ?? _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_selected != null)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, _selected),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Confirmar',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Mapa ─────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                onTap: (_, ll) => setState(() => _selected = ll),
              ),
              children: [
                // IgnorePointer evita que los tiles (Image.network) que
                // cargan asíncronamente disparen box.dart:2251 en web
                IgnorePointer(
                  child: TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.adoptapet.app',
                  ),
                ),
                if (_selected != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selected!,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.location_pin,
                          color: AppTheme.primary,
                          size: 48,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ── Instrucción flotante ──────────────────────────
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selected == null
                          ? 'Toca el mapa para marcar la ubicación de tu refugio'
                          : 'Lat: ${_selected!.latitude.toStringAsFixed(5)}, '
                              'Lng: ${_selected!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Botón confirmar abajo ─────────────────────────
          if (_selected != null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _selected),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar esta ubicación',
                    style: TextStyle(fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
