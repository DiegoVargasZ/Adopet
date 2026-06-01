// lib/data/services/pet_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pet.dart';
import '../models/pet_filter.dart'; // 👈 asegúrate de tener esto

class PetService {
  final _client = Supabase.instance.client;

  // 🔥 MÉTODO UNIFICADO
  Future<List<Pet>> getPets({
    PetFilter? filter,
    String? search,
    String? species, // 👈 compatibilidad con tu código anterior
  }) async {
    var query = _client
        .from('pets')
        .select()
        .eq('is_adopted', false);

    // 🟢 Compatibilidad con species antiguo
    if (species != null && species != 'all') {
      query = query.eq('species', species);
    }

    // 🟢 Filtro especie (nuevo)
    if (filter?.species != null) {
      query = query.eq('species', filter!.species!);
    }

    // 🟢 Filtro género
    if (filter?.gender != null) {
      query = query.eq('gender', filter!.gender!);
    }

    // 🟢 Filtro edad
    if (filter?.ageRange != null) {
      final (min, max) = filter!.ageMonthsRange;
      if (min != null) query = query.gte('age_months', min);
      if (max != null) query = query.lte('age_months', max);
    }

    // 🟢 Búsqueda por nombre
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('name', '%${search.trim()}%');
    }

    final data = await query.order('created_at', ascending: false);

    return (data as List)
        .map((e) => Pet.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Obtener TODAS las mascotas del refugio actual (incluye adoptadas)
  Future<List<Pet>> getMyPets() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final shelter = await _client
        .from('shelters')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (shelter == null) return [];

    final data = await _client
        .from('pets')
        .select()
        .eq('shelter_id', shelter['id'])
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => Pet.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Crear mascota
  Future<void> createPet({
    required String name,
    required String species,
    String? breed,
    int? ageMonths,
    String? gender,
    String? description,
    String? imageUrl,
    List<String> extraImages = const [],
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado');

    final shelter = await _client
        .from('shelters')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (shelter == null) {
      throw Exception(
          'No se encontró un refugio asociado a tu cuenta. '
          'Asegúrate de que tu solicitud fue aprobada.');
    }

    await _client.from('pets').insert({
      'shelter_id':   shelter['id'],
      'name':         name,
      'species':      species,
      'breed':        breed,
      'age_months':   ageMonths,
      'gender':       gender,
      'description':  description,
      'image_url':    imageUrl,
      'extra_images': extraImages,
      'is_adopted':   false,
    });
  }

  // Actualizar mascota
  Future<void> updatePet({
    required String petId,
    required String name,
    required String species,
    String? breed,
    int? ageMonths,
    String? gender,
    String? description,
    String? imageUrl,
    List<String> extraImages = const [],
  }) async {
    await _client
        .from('pets')
        .update({
          'name':         name,
          'species':      species,
          'breed':        breed,
          'age_months':   ageMonths,
          'gender':       gender,
          'description':  description,
          'image_url':    imageUrl,
          'extra_images': extraImages,
        })
        .eq('id', petId);
  }

  // Eliminar mascota
  Future<void> deletePet(String petId) async {
    await _client.from('pets').delete().eq('id', petId);
  }

  /// Admin: todas las mascotas de todos los refugios (incluye adoptadas)
  Future<List<Map<String, dynamic>>> getAllPetsAdmin() async {
    final data = await _client
        .from('pets')
        .select('*, shelters(name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }
}