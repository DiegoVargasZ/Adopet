// lib/data/services/meeting_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meeting.dart';

class MeetingService {
  final _client = Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  static const _baseSelect = '*, pets(name, image_url), shelters(name)';

  Future<void> requestMeeting({
    required String petId,
    required String shelterId,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    await _client.from('meetings').insert({
      'user_id':      _userId,
      'pet_id':       petId,
      'shelter_id':   shelterId,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'status':       'pending',
      'notes':        notes,
    });
  }

  // Adoptante: no necesita profiles (ve sus propias citas)
  Future<List<Meeting>> getMyMeetings() async {
    final data = await _client
        .from('meetings')
        .select(_baseSelect)
        .eq('user_id', _userId)
        .order('scheduled_at', ascending: false);

    return (data as List)
        .map((e) => Meeting.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Refugio: dos pasos para obtener profiles (user_id → auth.users, no profiles)
  Future<List<Meeting>> getShelterMeetings() async {
    final shelter = await _client
        .from('shelters')
        .select('id')
        .eq('user_id', _userId)
        .maybeSingle();

    if (shelter == null) return [];

    final raw = List<Map<String, dynamic>>.from(
      await _client
          .from('meetings')
          .select(_baseSelect)
          .eq('shelter_id', shelter['id'] as String)
          .order('scheduled_at', ascending: true) as List,
    );

    if (raw.isEmpty) return [];

    final userIds = raw.map((m) => m['user_id'] as String).toSet().toList();
    final profiles = List<Map<String, dynamic>>.from(
      await _client
          .from('profiles')
          .select('id, full_name, email')
          .inFilter('id', userIds) as List,
    );
    final profileMap = {for (final p in profiles) p['id'] as String: p};

    return raw.map((m) {
      final copy = Map<String, dynamic>.from(m);
      copy['profiles'] = profileMap[m['user_id'] as String];
      return Meeting.fromJson(copy);
    }).toList();
  }

  Future<void> updateStatus(
    String meetingId,
    String status, {
    String? adminNote,
  }) async {
    await _client.from('meetings').update({
      'status':     status,
      'admin_note': adminNote,
    }).eq('id', meetingId);
  }

  Future<void> cancelMeeting(String meetingId) async {
    await _client
        .from('meetings')
        .update({'status': 'cancelled'})
        .eq('id', meetingId)
        .eq('user_id', _userId);
  }
}
