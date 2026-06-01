// lib/presentation/screens/map/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/shelter.dart';
import '../../../data/services/shelter_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _shelterService = ShelterService();
  final _mapController  = MapController();

  List<Shelter> _shelters = [];
  Shelter? _selectedShelter;

  @override
  void initState() {
    super.initState();
    _loadShelters();
  }

  Future<void> _loadShelters() async {
    final data = await _shelterService.getShelters();
    setState(() => _shelters = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de refugios'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(-17.3895, -66.1568),
                initialZoom: 13,
                onTap: (_, __) => setState(() {
                  _selectedShelter = null;
                }),
              ),
              children: [
                // IgnorePointer evita que los tiles (Image.network) que
                // cargan asíncronamente sean registrados en el mouse tracker
                // de Flutter Web antes de ser trazados, eliminando
                // box.dart:2251 / mouse_tracker.dart:199 / object.dart:2702.
                IgnorePointer(
                  child: TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.adoptapet.app',
                  ),
                ),
                MarkerLayer(
                  markers: [
                    ..._shelters.map((shelter) {
                      final isSelected = _selectedShelter?.id == shelter.id;
                      return Marker(
                        point: LatLng(shelter.latitude, shelter.longitude),
                        width: isSelected ? 50 : 40,
                        height: isSelected ? 50 : 40,
                        // GestureDetector con HitTestBehavior.opaque garantiza
                        // que el render box nunca tenga tamaño cero en web.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              setState(() => _selectedShelter = shelter),
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
                                  color: Colors.black.withOpacity(0.2),
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
                    }),
                  ],
                ),
              ],
            ),
          ),
          if (_selectedShelter != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ShelterPanel(
                shelter: _selectedShelter!,
                onClose: () => setState(() {
                  _selectedShelter = null;
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShelterPanel extends StatelessWidget {
  final Shelter shelter;
  final VoidCallback onClose;

  const _ShelterPanel({
    required this.shelter,
    required this.onClose,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
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
              IconButton(icon: const Icon(Icons.close), onPressed: onClose),
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
              const SizedBox(width: 12),
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