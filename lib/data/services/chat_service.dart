// lib/data/services/chat_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';

class ChatService {
  final _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  // Obtener o crear un chat con un refugio
  Future<String> getOrCreateChat(String shelterId) async {
    // Buscar chat existente
    final existing = await _client
        .from('chats')
        .select('id')
        .eq('user_id', _userId)
        .eq('shelter_id', shelterId)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    // Crear nuevo chat
    final created = await _client.from('chats').insert({
      'user_id': _userId,
      'shelter_id': shelterId,
    }).select('id').single();

    return created['id'] as String;
  }

  // Adoptante: sus chats con refugios (dos pasos para evitar FK ambigua)
  Future<List<Map<String, dynamic>>> getMyChats() async {
    final raw = List<Map<String, dynamic>>.from(
      await _client
          .from('chats')
          .select('id, shelter_id, created_at, messages(content, created_at, is_read, sender_id)')
          .eq('user_id', _userId)
          .order('created_at', ascending: false) as List,
    );

    if (raw.isEmpty) return [];

    final shelterIds =
        raw.map((c) => c['shelter_id'] as String).toSet().toList();
    final shelters = List<Map<String, dynamic>>.from(
      await _client
          .from('shelters')
          .select('id, name, address')
          .inFilter('id', shelterIds) as List,
    );
    final shelterMap = {for (final s in shelters) s['id'] as String: s};

    return raw.map((c) {
      final copy = Map<String, dynamic>.from(c);
      copy['shelters'] = shelterMap[c['shelter_id'] as String];
      return copy;
    }).toList();
  }

  // Refugio: chats recibidos de adoptantes
  Future<List<Map<String, dynamic>>> getShelterChats() async {
    final shelter = await _client
        .from('shelters')
        .select('id')
        .eq('user_id', _userId)
        .maybeSingle();

    if (shelter == null) return [];

    // Paso 1: chats con mensajes (sin join a profiles para evitar FK ambigua)
    final chats = List<Map<String, dynamic>>.from(
      await _client
          .from('chats')
          .select('id, user_id, created_at, messages(content, created_at, is_read, sender_id)')
          .eq('shelter_id', shelter['id'] as String)
          .order('created_at', ascending: false) as List,
    );

    if (chats.isEmpty) return [];

    // Paso 2: perfiles de los adoptantes
    final userIds = chats.map((c) => c['user_id'] as String).toSet().toList();
    final profiles = List<Map<String, dynamic>>.from(
      await _client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', userIds) as List,
    );
    final profileMap = {for (final p in profiles) p['id'] as String: p};

    // Combinar
    return chats.map((c) {
      final result = Map<String, dynamic>.from(c);
      result['profiles'] = profileMap[c['user_id'] as String];
      return result;
    }).toList();
  }

  // Obtener mensajes de un chat
  Future<List<Message>> getMessages(String chatId) async {
    final data = await _client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);

    return (data as List)
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Enviar mensaje
  Future<void> sendMessage(String chatId, String content) async {
    await _client.from('messages').insert({
      'chat_id':   chatId,
      'sender_id': _userId,
      'content':   content,
    });
  }

  // Suscripción en tiempo real a nuevos mensajes de UN chat
  RealtimeChannel subscribeToMessages(
    String chatId,
    void Function(Message) onMessage,
  ) {
    return _client
        .channel('messages:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            final msg = Message.fromJson(
                Map<String, dynamic>.from(payload.newRecord));
            onMessage(msg);
          },
        )
        .subscribe();
  }

  // Suscripción global — avisa cuando llega cualquier mensaje nuevo
  // que NO fue enviado por el usuario actual (para actualizar la lista de chats)
  RealtimeChannel subscribeToIncomingMessages(
    void Function() onIncoming,
  ) {
    final myId = _userId;
    return _client
        .channel('inbox:$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final senderId =
                payload.newRecord['sender_id'] as String?;
            // Solo notificar si el mensaje es de otra persona
            if (senderId != null && senderId != myId) {
              onIncoming();
            }
          },
        )
        .subscribe();
  }

  // Suscripción a cambios de estado en adoption_requests
  // (para que el adoptante vea aprobaciones/rechazos en tiempo real)
  RealtimeChannel subscribeToAdoptionStatus(
    void Function(String requestId, String newStatus) onStatusChange,
  ) {
    final myId = _userId;
    return _client
        .channel('adoptions:$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'adoption_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: myId,
          ),
          callback: (payload) {
            final id     = payload.newRecord['id']     as String?;
            final status = payload.newRecord['status'] as String?;
            if (id != null && status != null) {
              onStatusChange(id, status);
            }
          },
        )
        .subscribe();
  }

  // Suscripción a cambios de estado en meetings
  // (para que el adoptante vea confirmaciones/rechazos en tiempo real)
  RealtimeChannel subscribeToMeetingStatus(
    void Function(String meetingId, String newStatus) onStatusChange,
  ) {
    final myId = _userId;
    return _client
        .channel('meetings:$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'meetings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: myId,
          ),
          callback: (payload) {
            final id     = payload.newRecord['id']     as String?;
            final status = payload.newRecord['status'] as String?;
            if (id != null && status != null) {
              onStatusChange(id, status);
            }
          },
        )
        .subscribe();
  }
}