// lib/presentation/screens/map/map_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../data/models/shelter.dart';
import '../../../data/services/shelter_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Obtén tu clave gratuita en https://openrouteservice.org
  static const _orsApiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjE3NmY1NTFmOGQ5MDM3ZjU3NDA1NGM4MTUxNGUyYWU0YjgyNjAzMmRkOThkNDA2ZDIxMDA5MGJmIiwiaCI6Im11cm11cjY0In0=';

  final _shelterService = ShelterService();
  final _mapController  = MapController();

  // Datos
  List<Shelter> _shelters     = [];
  Shelter?      _selected;
  List<LatLng>  _routePoints  = [];
  String?       _routeInfo;
  bool          _loadingRoute = false;

  // Filtros
  String    _searchText  = '';
  double?   _kmFilter;
  Position? _userPos;
  bool      _fetchingPos = false;

  @override
  void initState() {
    super.initState();
    _loadShelters();
  }

  Future<void> _loadShelters() async {
    final data = await _shelterService.getShelters();
    if (mounted) setState(() => _shelters = data);
  }

  // ── Filtrado ──────────────────────────────────────────────────────

  List<Shelter> get _visibleShelters {
    return _shelters.where((s) {
      if (_searchText.isNotEmpty) {
        final q = _searchText.toLowerCase();
        if (!s.name.toLowerCase().contains(q) &&
            !(s.address ?? '').toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_kmFilter != null && _userPos != null) {
        final dist = Geolocator.distanceBetween(
              _userPos!.latitude, _userPos!.longitude,
              s.latitude, s.longitude,
            ) /
            1000;
        if (dist > _kmFilter!) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _applyDistanceFilter(double? km) async {
    if (km == null) {
      setState(() => _kmFilter = null);
      return;
    }
    if (_userPos != null) {
      setState(() => _kmFilter = km);
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _snack('Activa los permisos de ubicación en Configuración');
      return;
    }
    if (permission == LocationPermission.denied) {
      _snack('Se necesita permiso de ubicación para filtrar por distancia');
      return;
    }

    setState(() => _fetchingPos = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      setState(() {
        _userPos     = pos;
        _kmFilter    = km;
        _fetchingPos = false;
      });
    } catch (e) {
      setState(() => _fetchingPos = false);
      _snack('No se pudo obtener tu ubicación');
    }
  }

  // ── Routing ───────────────────────────────────────────────────────

  Future<void> _getRoute(Shelter shelter) async {
    if (_orsApiKey == 'TU_API_KEY_AQUI') {
      _snack('Configura tu API key de OpenRouteService en map_screen.dart');
      return;
    }

    setState(() {
      _loadingRoute = true;
      _routePoints  = [];
      _routeInfo    = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _loadingRoute = false);
        _showLocationServiceDialog();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _snack('Activa los permisos de ubicación en Configuración');
        setState(() => _loadingRoute = false);
        return;
      }
      if (permission == LocationPermission.denied) {
        _snack('Se necesita permiso de ubicación para calcular la ruta');
        setState(() => _loadingRoute = false);
        return;
      }

      late Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
      } on TimeoutException {
        _snack('No se pudo obtener tu ubicación');
        if (mounted) setState(() => _loadingRoute = false);
        return;
      }

      final response = await http
          .post(
            Uri.parse(
              'https://api.openrouteservice.org/v2/directions/driving-car/geojson',
            ),
            headers: {
              'Authorization': _orsApiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'coordinates': [
                [pos.longitude, pos.latitude],
                [shelter.longitude, shelter.latitude],
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode != 200) {
        _snack('Error al calcular la ruta (${response.statusCode})');
        setState(() => _loadingRoute = false);
        return;
      }

      final json    = jsonDecode(response.body) as Map<String, dynamic>;
      final feature = (json['features'] as List).first as Map<String, dynamic>;
      final coords  = feature['geometry']['coordinates'] as List;
      final points  = coords
          .map((c) =>
              LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      final summary = feature['properties']['summary'] as Map<String, dynamic>;
      final distKm  = ((summary['distance'] as num) / 1000).toStringAsFixed(1);
      final mins    = ((summary['duration'] as num) / 60).round();

      setState(() {
        _routePoints  = points;
        _routeInfo    = '$distKm km · ~$mins min en auto';
        _loadingRoute = false;
      });

      if (points.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.fromLTRB(32, 80, 32, 220),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Error al calcular la ruta');
      setState(() => _loadingRoute = false);
    }
  }

  void _clearRoute() => setState(() {
        _routePoints = [];
        _routeInfo   = null;
      });

  void _selectShelter(Shelter s) => setState(() {
        _selected    = s;
        _routePoints = [];
        _routeInfo   = null;
      });

  void _deselectShelter() => setState(() {
        _selected    = null;
        _routePoints = [];
        _routeInfo   = null;
      });

  void _showLocationServiceDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubicación desactivada'),
        content: const Text(
          'El GPS está apagado. Actívalo en la configuración del dispositivo para calcular la ruta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await Geolocator.openLocationSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final visible = _visibleShelters;
    final selectedVisible =
        _selected == null || visible.any((s) => s.id == _selected!.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de refugios'),
      ),
      body: Stack(
        children: [
          // ── Mapa ──────────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(-17.3895, -66.1568),
                initialZoom: 13,
                onTap: (tapPos, point) => _deselectShelter(),
              ),
              children: [
                IgnorePointer(
                  child: TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.adoptapet.app',
                  ),
                ),

                // Polyline de la ruta
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: const Color(0xFF2563EB),
                        strokeWidth: 5,
                      ),
                    ],
                  ),

                // Punto azul de posición del usuario (cuando hay filtro activo)
                if (_userPos != null && _kmFilter != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                            _userPos!.latitude, _userPos!.longitude),
                        width: 20, height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                // Marcadores de refugios (solo los visibles)
                MarkerLayer(
                  markers: visible.map((shelter) {
                    final isSelected = _selected?.id == shelter.id;
                    return Marker(
                      point: LatLng(shelter.latitude, shelter.longitude),
                      width:  isSelected ? 50 : 40,
                      height: isSelected ? 50 : 40,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _selectShelter(shelter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF6B35)
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFFF6B35), width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.pets,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFFF6B35),
                            size: isSelected ? 28 : 22,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // ── Barra de búsqueda + chips (oculta cuando hay ruta activa) ─
          if (_routeInfo == null)
            Positioned(
              top: 12, left: 16, right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barra de búsqueda
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchText = v),
                      decoration: InputDecoration(
                        hintText: 'Buscar refugio por nombre o dirección...',
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.grey, size: 20),
                        suffixIcon: _searchText.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close,
                                    size: 18, color: Colors.grey),
                                onPressed: () =>
                                    setState(() => _searchText = ''),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Chips de filtro por distancia
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Todos',
                          icon: Icons.public,
                          selected: _kmFilter == null,
                          loading: false,
                          onTap: () => _applyDistanceFilter(null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Cerca (5 km)',
                          icon: Icons.near_me,
                          selected: _kmFilter == 5,
                          loading: _fetchingPos,
                          onTap: () => _applyDistanceFilter(5),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Dentro de 10 km',
                          icon: Icons.location_searching,
                          selected: _kmFilter == 10,
                          loading: _fetchingPos,
                          onTap: () => _applyDistanceFilter(10),
                        ),
                      ],
                    ),
                  ),

                  // Contador de resultados (solo con filtro activo)
                  if (_searchText.isNotEmpty || _kmFilter != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: visible.isEmpty
                            ? Colors.red.withValues(alpha: 0.1)
                            : const Color(0xFFFF6B35).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        visible.isEmpty
                            ? 'Sin refugios que coincidan'
                            : '${visible.length} refugio${visible.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: visible.isEmpty
                              ? Colors.red
                              : const Color(0xFFFF6B35),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // ── Banner de ruta calculada ───────────────────────────
          if (_routeInfo != null)
            Positioned(
              top: 12, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car,
                        color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _routeInfo!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    GestureDetector(
                      onTap: _clearRoute,
                      child: const Icon(Icons.close,
                          size: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

          // ── Panel inferior del refugio seleccionado ────────────
          if (_selected != null && selectedVisible)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _ShelterPanel(
                shelter:      _selected!,
                loadingRoute: _loadingRoute,
                onClose:      _deselectShelter,
                onRoute:      () => _getRoute(_selected!),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Chip de filtro ────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;
  final bool     loading;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6B35) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading && !selected)
              const SizedBox(
                width: 13, height: 13,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFFF6B35)),
              )
            else
              Icon(
                selected ? Icons.check : icon,
                size: 14,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Panel inferior ────────────────────────────────────────────────

class _ShelterPanel extends StatelessWidget {
  final Shelter      shelter;
  final VoidCallback onClose;
  final VoidCallback onRoute;
  final bool         loadingRoute;

  const _ShelterPanel({
    required this.shelter,
    required this.onClose,
    required this.onRoute,
    required this.loadingRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Encabezado
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pets, color: Color(0xFFFF6B35)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shelter.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    if (shelter.address != null)
                      Text(shelter.address!,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.close), onPressed: onClose),
            ],
          ),

          if (shelter.description != null) ...[
            const SizedBox(height: 8),
            Text(
              shelter.description!,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 16),

          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/donations', extra: shelter),
                  icon: const Icon(Icons.volunteer_activism, size: 18),
                  label: const Text('Donar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B35),
                    side: const BorderSide(color: Color(0xFFFF6B35)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: loadingRoute
                    ? const Center(
                        child: SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2563EB)),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: onRoute,
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Cómo llegar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(
                              color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    onClose();
                    context.push('/shelters/detail', extra: shelter);
                  },
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Ver detalle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
