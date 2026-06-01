// lib/presentation/screens/shelters/shelters_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/services/shelter_service.dart';
import '../../../data/models/shelter.dart';
import '../../widgets/shelter_card.dart';
import '../../../core/theme/app_theme.dart';

final _sheltersProvider = FutureProvider.autoDispose<List<Shelter>>((ref) {
  return ShelterService().getSheltersWithPetCount();
});

class SheltersScreen extends ConsumerStatefulWidget {
  const SheltersScreen({super.key});
  @override
  ConsumerState<SheltersScreen> createState() => _SheltersScreenState();
}

class _SheltersScreenState extends ConsumerState<SheltersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncShelters = ref.watch(_sheltersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Refugios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_sheltersProvider),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barra de búsqueda ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar refugio...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Lista ────────────────────────────────────
          Expanded(
            child: asyncShelters.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Error al cargar refugios',
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(_sheltersProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (shelters) {
                final filtered = _query.isEmpty
                    ? shelters
                    : shelters
                        .where((s) =>
                            s.name.toLowerCase().contains(_query) ||
                            (s.address?.toLowerCase().contains(_query) ??
                                false))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _query.isEmpty
                              ? Icons.home_work_outlined
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty
                              ? 'No hay refugios registrados'
                              : 'Sin resultados para "$_query"',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final cols = R.shelterCols(context);

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_sheltersProvider),
                  color: AppTheme.primary,
                  child: cols > 1
                      // ── Grid (tablet / desktop) ─────────────
                      ? GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:  cols,
                            crossAxisSpacing: 12,
                            mainAxisSpacing:  12,
                            childAspectRatio: 1.35,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) =>
                              ShelterCard(shelter: filtered[i]),
                        )
                      // ── Lista (móvil) ───────────────────────
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) =>
                              ShelterCard(shelter: filtered[i]),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
