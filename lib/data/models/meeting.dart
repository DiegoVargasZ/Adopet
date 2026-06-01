// lib/data/models/meeting.dart

class Meeting {
  final String id;
  final String userId;
  final String petId;
  final String shelterId;
  final DateTime scheduledAt;
  final String status; // pending | confirmed | rejected | cancelled
  final String? notes;
  final String? adminNote;
  final DateTime createdAt;

  // Joined via select
  final String? petName;
  final String? petImageUrl;
  final String? shelterName;
  final String? userName;
  final String? userEmail;

  const Meeting({
    required this.id,
    required this.userId,
    required this.petId,
    required this.shelterId,
    required this.scheduledAt,
    required this.status,
    this.notes,
    this.adminNote,
    required this.createdAt,
    this.petName,
    this.petImageUrl,
    this.shelterName,
    this.userName,
    this.userEmail,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    final pet     = json['pets']     as Map<String, dynamic>?;
    final shelter = json['shelters'] as Map<String, dynamic>?;
    final profile = json['profiles'] as Map<String, dynamic>?;

    return Meeting(
      id:          json['id'] as String,
      userId:      json['user_id'] as String,
      petId:       json['pet_id'] as String,
      shelterId:   json['shelter_id'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
      status:      json['status'] as String,
      notes:       json['notes'] as String?,
      adminNote:   json['admin_note'] as String?,
      createdAt:   DateTime.parse(json['created_at'] as String).toLocal(),
      petName:     pet?['name'] as String?,
      petImageUrl: pet?['image_url'] as String?,
      shelterName: shelter?['name'] as String?,
      userName:    profile?['full_name'] as String?,
      userEmail:   profile?['email'] as String?,
    );
  }

  String get statusLabel => switch (status) {
        'pending'   => 'Pendiente',
        'confirmed' => 'Confirmada',
        'rejected'  => 'Rechazada',
        'cancelled' => 'Cancelada',
        _           => status,
      };

  bool get isPending   => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled' || status == 'rejected';
}
