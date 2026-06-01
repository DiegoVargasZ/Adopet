// lib/data/models/user_profile.dart
class UserProfile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String role;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    required this.role,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id:        json['id'] as String,
        fullName:  json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        role:      json['role'] as String? ?? 'adoptante',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  bool get isAdoptante    => role == 'adoptante';
  bool get isShelter      => role == 'refugio';
  bool get isAdmin        => role == 'admin';
  bool get canManagePets  => isShelter || isAdmin;
}