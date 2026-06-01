// lib/data/services/donation_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/donation.dart';

class DonationService {
  final _client = Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  // Registrar donación
  Future<Donation> donate({
    required String shelterId,
    required double amount,
    String? message,
  }) async {
    final data = await _client.from('donations').insert({
      'user_id':    _userId,
      'shelter_id': shelterId,
      'amount':     amount,
      'message':    message,
      'currency':   'BOB',
      'status':     'completed',
    }).select().single();

    return Donation.fromJson(data as Map<String, dynamic>);
  }

  // Historial de donaciones del usuario
  Future<List<Donation>> getMyDonations() async {
    final data = await _client
        .from('donations')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => Donation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Total donado a un refugio
  Future<Map<String, dynamic>> getShelterTotals(String shelterId) async {
    final data = await _client
        .from('shelter_donation_totals')
        .select()
        .eq('shelter_id', shelterId)
        .maybeSingle();

    return data as Map<String, dynamic>? ??
        {'total_donations': 0, 'total_amount': 0.0};
  }
}