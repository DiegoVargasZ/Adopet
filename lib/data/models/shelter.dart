class Shelter {
  final String id;
  final String name;
  final String? description;
  final String? address;
  final String? phone;
  final String? email;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String? qrUrl;
  final int? petCount;

  const Shelter({
    required this.id,
    required this.name,
    this.description,
    this.address,
    this.phone,
    this.email,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.qrUrl,
    this.petCount,
  });

  factory Shelter.fromJson(Map<String, dynamic> json) {
    // petCount puede venir como json['pets'][0]['count'] desde Supabase
    int? petCount;
    final petsData = json['pets'];
    if (petsData is List && petsData.isNotEmpty) {
      petCount = (petsData.first as Map<String, dynamic>)['count'] as int?;
    } else if (petsData is int) {
      petCount = petsData;
    }

    return Shelter(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      latitude: ((json['latitude'] ?? json['lat']) as num? ?? 0).toDouble(),
      longitude: ((json['longitude'] ?? json['lng']) as num? ?? 0).toDouble(),
      imageUrl: json['image_url'] as String?,
      qrUrl: json['qr_url'] as String?,
      petCount: petCount,
    );
  }
}