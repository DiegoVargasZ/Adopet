// lib/data/services/role_service.dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class RoleService {
  final _client = Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  // Obtener perfil con rol del usuario actual
  Future<UserProfile?> getMyProfile() async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', _userId)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  // Actualizar nombre y/o avatar del perfil
  Future<UserProfile> updateProfile({
    required String fullName,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{'full_name': fullName};
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    final data = await _client
        .from('profiles')
        .update(updates)
        .eq('id', _userId)
        .select()
        .single();

    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  // Subir avatar a Supabase Storage y devolver la URL pública
  Future<String> uploadAvatar(Uint8List bytes, String ext) async {
    final path = 'avatars/$_userId/avatar.$ext';
    await _client.storage
        .from('pet-images')
        .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'));
    return _client.storage.from('pet-images').getPublicUrl(path);
  }

  // Solicitar rol de refugio
  Future<void> requestShelterRole({
    required String shelterName,
    required String description,
    String? phone,
    String? address,
  }) async {
    await _client.from('shelter_requests').insert({
      'user_id':      _userId,
      'shelter_name': shelterName,
      'description':  description,
      'phone':        phone,
      'address':      address,
    });
  }

  // Ver mi solicitud actual
  Future<Map<String, dynamic>?> getMyRequest() async {
    final data = await _client
        .from('shelter_requests')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
    return data as Map<String, dynamic>?;
  }

  // ── Admin ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    // Fetch requests primero sin join para evitar problemas de RLS/FK
    final data = await _client
        .from('shelter_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at');

    final requests = List<Map<String, dynamic>>.from(data as List);
    if (requests.isEmpty) return requests;

    // Buscar los nombres de los usuarios en profiles por separado
    final userIds = requests.map((r) => r['user_id'] as String).toList();
    try {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name, email')
          .inFilter('id', userIds);

      final profileMap = {
        for (final p in profiles as List)
          (p as Map<String, dynamic>)['id'] as String: p,
      };

      // Inyectar el perfil en cada request
      return requests.map((r) {
        return {
          ...r,
          'profiles': profileMap[r['user_id'] as String],
        };
      }).toList();
    } catch (_) {
      // Si profiles no es accesible, devolver requests sin perfil
      return requests;
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final data = await _client
        .from('profiles')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> approveRequest(String requestId) async {
    await _client.rpc('approve_shelter_request',
        params: {'request_id': requestId});
  }

  Future<void> rejectRequest(String requestId, {String? note}) async {
    await _client.rpc('reject_shelter_request',
        params: {'request_id': requestId, 'note': note});
  }

  Future<void> changeUserRole(String userId, String role) async {
    await _client
        .from('profiles')
        .update({'role': role})
        .eq('id', userId);
  }

  // Estadísticas — queries en paralelo
  Future<Map<String, int>> getStats() async {
    final results = await Future.wait([
      _client.from('profiles').select('id'),
      _client.from('pets').select('id'),
      _client.from('shelters').select('id'),
      _client.from('donations').select('id'),
      _client.from('shelter_requests').select('id').eq('status', 'pending'),
    ]);

    return {
      'users':     (results[0] as List).length,
      'pets':      (results[1] as List).length,
      'shelters':  (results[2] as List).length,
      'donations': (results[3] as List).length,
      'pending':   (results[4] as List).length,
    };
  }
}