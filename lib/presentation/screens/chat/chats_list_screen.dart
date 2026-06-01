// lib/presentation/screens/chat/chats_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/chat_service.dart';

class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key});
  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  final _chatService = ChatService();
  List<Map<String, dynamic>> _chats    = [];
  bool _loading   = true;
  bool _isShelter = false;
  String? _error;

  // WebSocket — escucha mensajes entrantes para actualizar la lista
  RealtimeChannel? _inboxChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToInbox();
  }

  void _subscribeToInbox() {
    _inboxChannel = _chatService.subscribeToIncomingMessages(() {
      // Cuando llega un mensaje nuevo de otra persona, recargar la lista
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _inboxChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final profile = ref.read(roleProvider).valueOrNull;
      _isShelter = profile?.isShelter == true || profile?.isAdmin == true;
      final data = await (_isShelter
          ? _chatService.getShelterChats()
          : _chatService.getMyChats());

      // Ordenar por fecha del último mensaje (más reciente primero)
      data.sort((a, b) {
        final ta = _lastMessageDate(a);
        final tb = _lastMessageDate(b);
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      if (mounted) setState(() { _chats = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Helpers de fecha ─────────────────────────────────────────

  DateTime? _lastMessageDate(Map<String, dynamic> chat) {
    final msgs = (chat['messages'] as List?) ?? [];
    if (msgs.isEmpty) return null;
    try {
      final raw = msgs.last['created_at'] as String?;
      if (raw == null) return null;
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// "14:30" si hoy • "Ayer" si ayer • "23 May" si este año • "23/5/24" si otro año
  String _smartTimestamp(Map<String, dynamic> chat) {
    final dt = _lastMessageDate(chat);
    if (dt == null) return '';
    final now = DateTime.now();
    final isToday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    final isYesterday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day - 1;

    if (isToday) {
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    if (isYesterday) return 'Ayer';
    if (dt.year == now.year) return DateFormat('d MMM', 'es').format(dt);
    return DateFormat('d/M/yy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mensajes',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textMain,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_outlined, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No se pudieron cargar los mensajes',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 3),
              const SizedBox(height: 20),
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

    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  size: 52, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('Sin conversaciones',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.textMain)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _isShelter
                    ? 'Los adoptantes podrán contactarte desde la pantalla de mascotas'
                    : 'Toca "Contactar" en el perfil de una mascota para iniciar una conversación',
                style: const TextStyle(color: AppTheme.textSub, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        itemCount: _chats.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 80, endIndent: 16),
        itemBuilder: (_, i) => _ChatTile(
          chat:      _chats[i],
          myId:      myId,
          isShelter: _isShelter,
          timestamp: _smartTimestamp(_chats[i]),
          onTap: () {
            final chat = _chats[i];
            final String label;
            if (_isShelter) {
              final p = chat['profiles'] as Map<String, dynamic>? ?? {};
              label = p['full_name'] as String? ?? 'Adoptante';
            } else {
              final s = chat['shelters'] as Map<String, dynamic>? ?? {};
              label = s['name'] as String? ?? 'Refugio';
            }
            context.push('/chats/chat', extra: {
              'chatId':      chat['id'] as String,
              'shelterName': label,
            });
          },
        ),
      ),
    );
  }
}

// ── Tile individual de chat ───────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final String    myId;
  final bool      isShelter;
  final String    timestamp;
  final VoidCallback onTap;

  const _ChatTile({
    required this.chat,
    required this.myId,
    required this.isShelter,
    required this.timestamp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final msgs = (chat['messages'] as List?) ?? [];

    // Último mensaje visible
    final lastContent = msgs.isNotEmpty
        ? msgs.last['content'] as String? ?? ''
        : '';

    // Mensajes no leídos que no son míos
    final unread = msgs.where((m) =>
        m['is_read'] == false && m['sender_id'] != myId).length;

    final hasUnread = unread > 0;

    // Nombre e imagen según el rol
    final String displayName;
    final String? avatarUrl;

    if (isShelter) {
      final p = chat['profiles'] as Map<String, dynamic>? ?? {};
      displayName = p['full_name'] as String? ?? 'Adoptante';
      avatarUrl   = p['avatar_url'] as String?;
    } else {
      final s = chat['shelters'] as Map<String, dynamic>? ?? {};
      displayName = s['name'] as String? ?? 'Refugio';
      avatarUrl   = null; // shelters no tienen avatar aún
    }

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        AppTheme.primary.withOpacity(0.12),
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Icon(
                            isShelter ? Icons.person : Icons.pets,
                            color: AppTheme.primary,
                            size: 26,
                          )
                        : null,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 14),

              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.textMain,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastContent.isEmpty
                          ? 'Sin mensajes aún'
                          : lastContent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread
                            ? AppTheme.textMain
                            : AppTheme.textSub,
                        fontSize: 13,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Columna derecha: timestamp + badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timestamp,
                    style: TextStyle(
                      fontSize: 11,
                      color: hasUnread
                          ? AppTheme.primary
                          : AppTheme.textSub,
                      fontWeight: hasUnread
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
