// lib/data/services/adoption_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/adoption_request.dart';

class AdoptionService {
  final _client = Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  static const _baseSelect = '*, pets(name, image_url, species), shelters(name)';

  Future<void> requestAdoption({
    required String petId,
    required String shelterId,
    String? message,
  }) async {
    await _client.from('adoption_requests').insert({
      'user_id':    _userId,
      'pet_id':     petId,
      'shelter_id': shelterId,
      'status':     'pending',
      'message':    message,
    });
  }

  // Adoptante: no necesita profiles (ve sus propias solicitudes)
  Future<List<AdoptionRequest>> getMyRequests() async {
    final data = await _client
        .from('adoption_requests')
        .select(_baseSelect)
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => AdoptionRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Refugio: dos pasos para obtener profiles (user_id → auth.users, no profiles)
  Future<List<AdoptionRequest>> getShelterRequests() async {
    final shelter = await _client
        .from('shelters')
        .select('id')
        .eq('user_id', _userId)
        .maybeSingle();

    if (shelter == null) return [];

    final raw = List<Map<String, dynamic>>.from(
      await _client
          .from('adoption_requests')
          .select(_baseSelect)
          .eq('shelter_id', shelter['id'] as String)
          .order('created_at', ascending: false) as List,
    );

    if (raw.isEmpty) return [];

    final userIds = raw.map((r) => r['user_id'] as String).toSet().toList();
    final profiles = List<Map<String, dynamic>>.from(
      await _client
          .from('profiles')
          .select('id, full_name, email')
          .inFilter('id', userIds) as List,
    );
    final profileMap = {for (final p in profiles) p['id'] as String: p};

    return raw.map((r) {
      final copy = Map<String, dynamic>.from(r);
      copy['profiles'] = profileMap[r['user_id'] as String];
      return AdoptionRequest.fromJson(copy);
    }).toList();
  }

  Future<void> approve(String requestId, String petId) async {
    // 1. Aprobar la solicitud ganadora y marcar la mascota como adoptada en paralelo
    await Future.wait([
      _client
          .from('adoption_requests')
          .update({'status': 'approved'})
          .eq('id', requestId),
      _client
          .from('pets')
          .update({'is_adopted': true})
          .eq('id', petId),
    ]);

    // 2. Rechazar automáticamente todas las demás solicitudes pendientes
    //    para esta misma mascota (distinto requestId, mismo petId)
    await _client
        .from('adoption_requests')
        .update({
          'status': 'rejected',
          'admin_note':
              'La mascota fue adoptada por otro solicitante.',
        })
        .eq('pet_id', petId)
        .eq('status', 'pending')
        .neq('id', requestId);
  }

  Future<void> reject(String requestId, {String? note}) async {
    await _client.from('adoption_requests').update({
      'status':     'rejected',
      'admin_note': note,
    }).eq('id', requestId);
  }

  Future<void> cancel(String requestId) async {
    await _client
        .from('adoption_requests')
        .delete()
        .eq('id', requestId)
        .eq('user_id', _userId)
        .eq('status', 'pending');
  }
}
