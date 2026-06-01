// lib/data/models/adoption_request.dart

class AdoptionRequest {
  final String id;
  final String userId;
  final String petId;
  final String shelterId;
  final String status; // pending | approved | rejected
  final String? message;
  final String? adminNote;
  final DateTime createdAt;

  // Joined via select
  final String? petName;
  final String? petImageUrl;
  final String? petSpecies;
  final String? shelterName;
  final String? userName;
  final String? userEmail;

  const AdoptionRequest({
    required this.id,
    required this.userId,
    required this.petId,
    required this.shelterId,
    required this.status,
    this.message,
    this.adminNote,
    required this.createdAt,
    this.petName,
    this.petImageUrl,
    this.petSpecies,
    this.shelterName,
    this.userName,
    this.userEmail,
  });

  factory AdoptionRequest.fromJson(Map<String, dynamic> json) {
    final pet     = json['pets']     as Map<String, dynamic>?;
    final shelter = json['shelters'] as Map<String, dynamic>?;
    final profile = json['profiles'] as Map<String, dynamic>?;

    return AdoptionRequest(
      id:          json['id'] as String,
      userId:      json['user_id'] as String,
      petId:       json['pet_id'] as String,
      shelterId:   json['shelter_id'] as String,
      status:      json['status'] as String,
      message:     json['message'] as String?,
      adminNote:   json['admin_note'] as String?,
      createdAt:   DateTime.parse(json['created_at'] as String).toLocal(),
      petName:     pet?['name'] as String?,
      petImageUrl: pet?['image_url'] as String?,
      petSpecies:  pet?['species'] as String?,
      shelterName: shelter?['name'] as String?,
      userName:    profile?['full_name'] as String?,
      userEmail:   profile?['email'] as String?,
    );
  }

  String get statusLabel => switch (status) {
        'pending'  => 'Pendiente',
        'approved' => 'Aprobada',
        'rejected' => 'Rechazada',
        _          => status,
      };

  bool get isPending  => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get speciesEmoji => switch (petSpecies) {
        'dog' => '🐶',
        'cat' => '🐱',
        _     => '🐾',
      };
}
