import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shelter.dart';
import '../models/pet.dart';

class ShelterService {
  final _client = Supabase.instance.client;

  /// Lista de refugios sin conteo de mascotas (uso general/mapa)
  Future<List<Shelter>> getShelters() async {
    final data = await _client
        .from('shelters')
        .select()
        .order('name');
    return (data as List)
        .map((e) => Shelter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lista de refugios con conteo de mascotas disponibles
  Future<List<Shelter>> getSheltersWithPetCount() async {
    final data = await _client
        .from('shelters')
        .select('*, pets(count)')
        .order('name');
    return (data as List)
        .map((e) => Shelter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Refugio del usuario autenticado actual
  Future<Shelter?> getMyShelter() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('shelters')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Shelter.fromJson(data);
  }

  /// Actualiza los datos del refugio del usuario actual
  Future<void> updateShelter({
    required String shelterId,
    String? name,
    String? description,
    String? address,
    String? phone,
    String? email,
    String? imageUrl,
    String? qrUrl,
    double? latitude,
    double? longitude,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (address != null) updates['address'] = address;
    if (phone != null) updates['phone'] = phone;
    if (email != null) updates['email'] = email;
    if (imageUrl != null) updates['image_url'] = imageUrl;
    if (qrUrl != null) updates['qr_url'] = qrUrl;
    // Soportar ambas convenciones: lat/lng (schema) y latitude/longitude
    if (latitude != null) {
      updates['lat']  = latitude;
      updates['latitude'] = latitude;
    }
    if (longitude != null) {
      updates['lng']  = longitude;
      updates['longitude'] = longitude;
    }

    if (updates.isEmpty) return;

    await _client
        .from('shelters')
        .update(updates)
        .eq('id', shelterId);
  }

  /// Sube imagen del refugio al storage y devuelve la URL pública
  Future<String> uploadShelterImage(
      String shelterId, Uint8List bytes, String ext) async {
    final path = 'shelters/$shelterId/cover.$ext';
    await _client.storage.from('pet-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
              contentType: 'image/$ext', upsert: true),
        );
    return _client.storage.from('pet-images').getPublicUrl(path);
  }

  /// Sube imagen QR al storage y devuelve la URL pública
  Future<String> uploadQrImage(
      String shelterId, Uint8List bytes, String ext) async {
    final path = 'shelters/$shelterId/qr.$ext';
    await _client.storage.from('pet-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
              contentType: 'image/$ext', upsert: true),
        );
    return _client.storage.from('pet-images').getPublicUrl(path);
  }

  /// Mascotas disponibles (no adoptadas) de un refugio específico
  Future<List<Pet>> getPetsByShelter(String shelterId) async {
    final data = await _client
        .from('pets')
        .select()
        .eq('shelter_id', shelterId)
        .eq('is_adopted', false)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Pet.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
