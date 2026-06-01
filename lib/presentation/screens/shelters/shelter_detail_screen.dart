// lib/presentation/screens/shelters/shelter_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/shelter.dart';
import '../../../data/models/pet.dart';
import '../../../data/services/shelter_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/pet_card.dart';

final _shelterPetsProvider =
    FutureProvider.autoDispose.family<List<Pet>, String>((ref, shelterId) {
  return ShelterService().getPetsByShelter(shelterId);
});

class ShelterDetailScreen extends ConsumerWidget {
  final Shelter shelter;
  const ShelterDetailScreen({super.key, required this.shelter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPets = ref.watch(_shelterPetsProvider(shelter.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          // ── App Bar con imagen / gradiente ──────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                shelter.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              background: shelter.imageUrl != null
                  ? Image.network(
                      shelter.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _headerGradient(),
                    )
                  : _headerGradient(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.volunteer_activism),
                tooltip: 'Donar',
                onPressed: () => context.push('/donations', extra: shelter),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Tarjeta info ─────────────────────────
                  _InfoCard(shelter: shelter),
                  const SizedBox(height: 20),

                  // ── Botones principales ──────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/map'),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Ver en mapa'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              context.push('/donations', extra: shelter),
                          icon: const Icon(Icons.volunteer_activism),
                          label: const Text('Donar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Mascotas disponibles ─────────────────
                  const Text(
                    'Mascotas disponibles',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Grid de mascotas ─────────────────────────────
          asyncPets.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('Error al cargar mascotas',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            ),
            data: (pets) {
              if (pets.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pets, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No hay mascotas disponibles',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => PetCard(
                      pet: pets[i],
                      onTap: () =>
                          ctx.push('/pets/detail', extra: pets[i]),
                    ),
                    childCount: pets.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _headerGradient() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, Color(0xFFFF8C5A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.home_work_outlined,
              size: 72, color: Colors.white54),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final Shelter shelter;
  const _InfoCard({required this.shelter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shelter.description != null) ...[
            Text(
              shelter.description!,
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.5),
            ),
            const SizedBox(height: 12),
          ],
          if (shelter.address != null)
            _InfoRow(
                icon: Icons.location_on_outlined, text: shelter.address!),
          if (shelter.phone != null)
            _InfoRow(icon: Icons.phone_outlined, text: shelter.phone!),
          if (shelter.email != null)
            _InfoRow(icon: Icons.email_outlined, text: shelter.email!),
          if (shelter.petCount != null) ...[
            const Divider(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pets,
                          size: 14, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${shelter.petCount} mascotas disponibles',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
