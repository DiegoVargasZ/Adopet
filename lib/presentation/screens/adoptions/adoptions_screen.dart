// lib/presentation/screens/adoptions/adoptions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/role_provider.dart';
import '../../../data/models/adoption_request.dart';
import '../../../data/services/adoption_service.dart';
import '../../../data/services/chat_service.dart';

// ── Providers ─────────────────────────────────────────────────
final _myRequestsProvider = FutureProvider.autoDispose<List<AdoptionRequest>>(
  (_) => AdoptionService().getMyRequests(),
);

final _shelterRequestsProvider =
    FutureProvider.autoDispose<List<AdoptionRequest>>(
  (_) => AdoptionService().getShelterRequests(),
);

// ── Screen ────────────────────────────────────────────────────
class AdoptionsScreen extends ConsumerStatefulWidget {
  const AdoptionsScreen({super.key});

  @override
  ConsumerState<AdoptionsScreen> createState() => _AdoptionsScreenState();
}

class _AdoptionsScreenState extends ConsumerState<AdoptionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // WebSocket — escucha cambios de estado en las solicitudes del adoptante
  RealtimeChannel? _adoptionChannel;
  // WebSocket — escucha nuevas solicitudes que llegan al refugio
  RealtimeChannel? _shelterChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    final profile = ref.read(roleProvider).valueOrNull;
    final isShelterOrAdmin =
        profile?.isShelter == true || profile?.isAdmin == true;

    // Adoptante: recibe actualizaciones cuando el refugio cambia el estado
    _adoptionChannel = ChatService().subscribeToAdoptionStatus(
      (requestId, newStatus) {
        if (mounted) ref.invalidate(_myRequestsProvider);
      },
    );

    // Refugio/Admin: recibe nuevas solicitudes en tiempo real
    if (isShelterOrAdmin) {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      if (myId != null) {
        _shelterChannel = Supabase.instance.client
            .channel('shelter_adoptions:$myId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'adoption_requests',
              callback: (_) {
                if (mounted) ref.invalidate(_shelterRequestsProvider);
              },
            )
            .subscribe();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _adoptionChannel?.unsubscribe();
    _shelterChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isShelterOrAdmin =
        ref.watch(roleProvider).valueOrNull?.isShelter == true ||
            ref.watch(roleProvider).valueOrNull?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adopciones'),
        bottom: isShelterOrAdmin
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Mis solicitudes'),
                  Tab(text: 'Recibidas'),
                ],
              )
            : null,
      ),
      body: isShelterOrAdmin
          ? TabBarView(
              controller: _tabController,
              children: const [
                _MyRequestsTab(),
                _ShelterRequestsTab(),
              ],
            )
          : const _MyRequestsTab(),
    );
  }
}

// ── Tab adoptante ──────────────────────────────────────────────
class _MyRequestsTab extends ConsumerWidget {
  const _MyRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myRequestsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data: (requests) {
        if (requests.isEmpty) {
          return const _EmptyState(
            icon: Icons.pets,
            title: 'Sin solicitudes',
            subtitle:
                'Ve al perfil de una mascota y pulsa "Solicitar adopción" para empezar el proceso.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(_myRequestsProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (_, i) => _RequestCard(
              request: requests[i],
              isOwner: true,
              onCancel: requests[i].isPending
                  ? () => _cancel(context, ref, requests[i])
                  : null,
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, AdoptionRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content:
            Text('¿Cancelar la solicitud de adopción de ${r.petName ?? "la mascota"}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, cancelar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdoptionService().cancel(r.id);
      ref.invalidate(_myRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud cancelada')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ── Tab refugio ───────────────────────────────────────────────
class _ShelterRequestsTab extends ConsumerWidget {
  const _ShelterRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_shelterRequestsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data: (requests) {
        if (requests.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Sin solicitudes recibidas',
            subtitle:
                'Las solicitudes de adopción que envíen los adoptantes aparecerán aquí.',
          );
        }

        // Separar pendientes de resueltas
        final pending  = requests.where((r) => r.isPending).toList();
        final resolved = requests.where((r) => !r.isPending).toList();

        return RefreshIndicator(
          onRefresh: () => ref.refresh(_shelterRequestsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                _SectionHeader(
                    '${pending.length} pendiente${pending.length != 1 ? 's' : ''}'),
                ...pending.map((r) => _RequestCard(
                      request: r,
                      isOwner: false,
                      onApprove: () => _approve(context, ref, r),
                      onReject:  () => _rejectWithNote(context, ref, r),
                    )),
                const SizedBox(height: 12),
              ],
              if (resolved.isNotEmpty) ...[
                const _SectionHeader('Historial'),
                ...resolved.map((r) => _RequestCard(
                      request: r,
                      isOwner: false,
                    )),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _approve(
      BuildContext context, WidgetRef ref, AdoptionRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar adopción'),
        content: Text(
            '¿Aprobar la adopción de ${r.petName ?? "la mascota"}? La mascota quedará marcada como adoptada.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D6A4F)),
            child: const Text('Aprobar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdoptionService().approve(r.id, r.petId);
      ref.invalidate(_shelterRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Adopción aprobada. Mascota marcada como adoptada.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _rejectWithNote(
      BuildContext context, WidgetRef ref, AdoptionRequest r) async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Motivo del rechazo (opcional)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rechazar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (note == null) return;
    try {
      await AdoptionService()
          .reject(r.id, note: note.isEmpty ? null : note);
      ref.invalidate(_shelterRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud rechazada')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ── Request card ──────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final AdoptionRequest request;
  final bool isOwner;
  final VoidCallback? onCancel;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _RequestCard({
    required this.request,
    required this.isOwner,
    this.onCancel,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(request.status);
    final fmt = DateFormat('d MMM yyyy', 'es');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Imagen mascota
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: request.petImageUrl != null
                      ? Image.network(
                          request.petImageUrl!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            request.speciesEmoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              request.petName ?? 'Mascota',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOwner
                            ? request.shelterName ?? 'Refugio'
                            : request.userName ??
                                request.userEmail ??
                                'Adoptante',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        fmt.format(request.createdAt),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Badge estado
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    request.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Mensaje del adoptante ───────────────────────────
          if (request.message != null && request.message!.isNotEmpty)
            _noteRow(
              Icons.message_outlined,
              '"${request.message!}"',
              Colors.grey.shade600,
            ),

          // ── Nota del refugio ────────────────────────────────
          if (request.adminNote != null && request.adminNote!.isNotEmpty)
            _noteRow(
              Icons.info_outline,
              request.adminNote!,
              Colors.red.shade400,
            ),

          // ── Aprobado banner ─────────────────────────────────
          if (request.isApproved)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Color(0xFF2D6A4F), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¡Adopción aprobada! El refugio se pondrá en contacto contigo.',
                      style: TextStyle(
                          color: Color(0xFF2D6A4F), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // ── Acciones ────────────────────────────────────────
          if (request.isPending && (onCancel != null || onApprove != null))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  if (isOwner && onCancel != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Cancelar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  if (!isOwner) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Rechazar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Aprobar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D6A4F),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _noteRow(IconData icon, String text, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color, fontSize: 13, fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      );

  Widget _placeholder() => Container(
        width: 64,
        height: 64,
        color: const Color(0xFFF5F5F5),
        child: const Icon(Icons.pets, color: Colors.grey, size: 32),
      );

  Color _statusColor(String status) => switch (status) {
        'approved' => const Color(0xFF2D6A4F),
        'rejected' => Colors.red,
        _          => const Color(0xFFFF9800),
      };
}

// ── Helpers ───────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
