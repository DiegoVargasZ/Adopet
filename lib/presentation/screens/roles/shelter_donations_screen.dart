// lib/presentation/screens/roles/shelter_donations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

class ShelterDonationsScreen extends ConsumerWidget {
  const ShelterDonationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDonations = ref.watch(_shelterDonationsProvider);
    final dateFmt = DateFormat('d MMM yyyy', 'es');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donaciones recibidas'),
        actions: [
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
                        AppTheme.secondary.withOpacity(0.75),
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

                // ── Lista ────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: donations.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final d = donations[i];
                      final profile =
                          d['profiles'] as Map<String, dynamic>?;
                      final dt = DateTime.parse(
                          d['created_at'] as String).toLocal();
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.secondary.withOpacity(0.1),
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
