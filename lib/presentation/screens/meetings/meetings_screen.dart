// lib/presentation/screens/meetings/meetings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/role_provider.dart';
import '../../../data/models/meeting.dart';
import '../../../data/services/meeting_service.dart';
import '../../../data/services/chat_service.dart';

// ── Providers ─────────────────────────────────────────────────
final _myMeetingsProvider = FutureProvider.autoDispose<List<Meeting>>(
  (_) => MeetingService().getMyMeetings(),
);

final _shelterMeetingsProvider = FutureProvider.autoDispose<List<Meeting>>(
  (_) => MeetingService().getShelterMeetings(),
);

// ── Screen ────────────────────────────────────────────────────
class MeetingsScreen extends ConsumerStatefulWidget {
  const MeetingsScreen({super.key});

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // WebSocket — escucha cambios de estado en las citas del adoptante
  RealtimeChannel? _meetingChannel;
  // WebSocket — escucha nuevas citas que llegan al refugio
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
    _meetingChannel = ChatService().subscribeToMeetingStatus(
      (meetingId, newStatus) {
        if (mounted) ref.invalidate(_myMeetingsProvider);
      },
    );

    // Refugio/Admin: recibe nuevas citas en tiempo real
    if (isShelterOrAdmin) {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      if (myId != null) {
        _shelterChannel = Supabase.instance.client
            .channel('shelter_meetings:$myId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'meetings',
              callback: (_) {
                if (mounted) ref.invalidate(_shelterMeetingsProvider);
              },
            )
            .subscribe();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _meetingChannel?.unsubscribe();
    _shelterChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(roleProvider);
    final isShelterOrAdmin = roleAsync.valueOrNull?.isShelter == true ||
        roleAsync.valueOrNull?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Citas'),
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
                _MyMeetingsTab(),
                _ShelterMeetingsTab(),
              ],
            )
          : const _MyMeetingsTab(),
    );
  }
}

// ── Tab Adoptante ─────────────────────────────────────────────
class _MyMeetingsTab extends ConsumerWidget {
  const _MyMeetingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myMeetingsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (meetings) {
        if (meetings.isEmpty) {
          return const _EmptyState(
            icon: Icons.event_outlined,
            title: 'Sin citas agendadas',
            subtitle:
                'Ve al perfil de una mascota y pulsa "Agendar visita" para solicitar una cita.',
          );
        }

        final upcoming = meetings
            .where((m) => m.status == 'pending' || m.status == 'confirmed')
            .toList();
        final history = meetings
            .where((m) => m.status == 'cancelled' || m.status == 'rejected')
            .toList();

        return RefreshIndicator(
          onRefresh: () => ref.refresh(_myMeetingsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (upcoming.isNotEmpty) ...[
                const _SectionHeader('Próximas'),
                ...upcoming.map(
                  (m) => _MeetingCard(
                    meeting: m,
                    isOwner: true,
                    onCancel: m.isPending
                        ? () => _cancel(context, ref, m)
                        : null,
                  ),
                ),
                if (history.isNotEmpty) const SizedBox(height: 12),
              ],
              if (history.isNotEmpty) ...[
                const _SectionHeader('Historial'),
                ...history.map(
                  (m) => _MeetingCard(meeting: m, isOwner: true),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, Meeting m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text('¿Cancelar la visita a ${m.petName ?? "la mascota"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, cancelar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await MeetingService().cancelMeeting(m.id);
      ref.invalidate(_myMeetingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita cancelada')),
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

// ── Tab Refugio ───────────────────────────────────────────────
class _ShelterMeetingsTab extends ConsumerWidget {
  const _ShelterMeetingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_shelterMeetingsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (meetings) {
        if (meetings.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Sin solicitudes',
            subtitle: 'Las citas que los adoptantes agenden aparecerán aquí.',
          );
        }

        final pending  = meetings.where((m) => m.isPending).toList();
        final resolved = meetings.where((m) => !m.isPending).toList();

        return RefreshIndicator(
          onRefresh: () => ref.refresh(_shelterMeetingsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                _SectionHeader(
                    '${pending.length} pendiente${pending.length != 1 ? 's' : ''}'),
                ...pending.map(
                  (m) => _MeetingCard(
                    meeting: m,
                    isOwner: false,
                    onConfirm: () =>
                        _updateStatus(context, ref, m, 'confirmed'),
                    onReject: () => _rejectWithNote(context, ref, m),
                  ),
                ),
                if (resolved.isNotEmpty) const SizedBox(height: 12),
              ],
              if (resolved.isNotEmpty) ...[
                const _SectionHeader('Historial'),
                ...resolved.map(
                  (m) => _MeetingCard(meeting: m, isOwner: false),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, Meeting m,
      String status, {String? note}) async {
    try {
      await MeetingService().updateStatus(m.id, status, adminNote: note);
      ref.invalidate(_shelterMeetingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'confirmed'
                ? 'Cita confirmada'
                : 'Cita rechazada'),
          ),
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
      BuildContext context, WidgetRef ref, Meeting m) async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar cita'),
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
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Rechazar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (note == null) return;
    if (context.mounted) {
      await _updateStatus(context, ref, m, 'rejected',
          note: note.isEmpty ? null : note);
    }
  }
}

// ── Card de cita ──────────────────────────────────────────────
class _MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final bool isOwner;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  const _MeetingCard({
    required this.meeting,
    required this.isOwner,
    this.onCancel,
    this.onConfirm,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(meeting.status);
    final fmt = DateFormat('EEE d MMM, HH:mm', 'es');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
          // Header con imagen + info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: meeting.petImageUrl != null
                      ? Image.network(
                          meeting.petImageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _petPlaceholder(),
                        )
                      : _petPlaceholder(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.petName ?? 'Mascota',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (isOwner && meeting.shelterName != null)
                        Text(
                          meeting.shelterName!,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      if (!isOwner)
                        Text(
                          meeting.userName ??
                              meeting.userEmail ??
                              'Adoptante',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            fmt.format(meeting.scheduledAt),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    meeting.statusLabel,
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

          // Notas del adoptante
          if (meeting.notes != null && meeting.notes!.isNotEmpty)
            _noteRow(Icons.notes_outlined, meeting.notes!, Colors.grey),

          // Nota del refugio (rechazo)
          if (meeting.adminNote != null && meeting.adminNote!.isNotEmpty)
            _noteRow(
                Icons.info_outline, meeting.adminNote!, Colors.red.shade300),

          // Banner confirmada (solo para el adoptante)
          if (meeting.isConfirmed && isOwner)
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
                      '¡Cita confirmada! El refugio te espera en la fecha indicada.',
                      style: TextStyle(
                          color: Color(0xFF2D6A4F), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Acciones (solo pendientes con callbacks)
          if (meeting.isPending && (onCancel != null || onConfirm != null))
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
                        onPressed: onConfirm,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Confirmar'),
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

  Widget _noteRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _petPlaceholder() => Container(
        width: 60,
        height: 60,
        color: const Color(0xFFF5F5F5),
        child: const Icon(Icons.pets, color: Colors.grey, size: 30),
      );

  Color _statusColor(String status) => switch (status) {
        'confirmed' => const Color(0xFF2D6A4F),
        'rejected'  => Colors.red,
        'cancelled' => Colors.grey,
        _           => const Color(0xFFFF9800),
      };
}

// ── Section header ────────────────────────────────────────────
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
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────
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
