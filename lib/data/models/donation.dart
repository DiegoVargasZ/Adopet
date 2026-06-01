// lib/data/models/donation.dart
class Donation {
  final String id;
  final String userId;
  final String shelterId;
  final double amount;
  final String currency;
  final String? message;
  final String status;
  final DateTime createdAt;

  const Donation({
    required this.id,
    required this.userId,
    required this.shelterId,
    required this.amount,
    required this.currency,
    this.message,
    required this.status,
    required this.createdAt,
  });

  factory Donation.fromJson(Map<String, dynamic> json) => Donation(
        id:        json['id'] as String,
        userId:    json['user_id'] as String,
        shelterId: json['shelter_id'] as String,
        amount:    (json['amount'] as num).toDouble(),
        currency:  json['currency'] as String? ?? 'BOB',
        message:   json['message'] as String?,
        status:    json['status'] as String? ?? 'completed',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String get formattedAmount => 'Bs. ${amount.toStringAsFixed(2)}';
}