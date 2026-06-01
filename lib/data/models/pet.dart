// lib/data/models/pet.dart
class Pet {
  final String id;
  final String? shelterId;
  final String name;
  final String species;
  final String? breed;
  final int? ageMonths;
  final String? gender;
  final String? description;
  final String? imageUrl;
  final bool isAdopted;
  final List<String> extraImages;

  const Pet({
    required this.id,
    this.shelterId,
    required this.name,
    required this.species,
    this.breed,
    this.ageMonths,
    this.gender,
    this.description,
    this.imageUrl,
    this.isAdopted = false,
    this.extraImages = const [],
  });

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id:          json['id'] as String,
        shelterId:   json['shelter_id'] as String?,
        name:        json['name'] as String,
        species:     json['species'] as String,
        breed:       json['breed'] as String?,
        ageMonths:   json['age_months'] as int?,
        gender:      json['gender'] as String?,
        description: json['description'] as String?,
        imageUrl:    json['image_url'] as String?,
        isAdopted:   json['is_adopted'] as bool? ?? false,
        extraImages: (json['extra_images'] as List? ?? []).cast<String>(),
      );

  /// Todas las fotos: imagen principal + fotos extra
  List<String> get allImages {
    final list = <String>[];
    if (imageUrl != null && imageUrl!.isNotEmpty) list.add(imageUrl!);
    list.addAll(extraImages);
    return list;
  }

  String get ageLabel {
    if (ageMonths == null) return 'Edad desconocida';
    if (ageMonths! < 12) return '$ageMonths ${ageMonths == 1 ? "mes" : "meses"}';
    final years = ageMonths! ~/ 12;
    return '$years ${years == 1 ? "año" : "años"}';
  }

  String get speciesEmoji =>
      species == 'dog' ? '🐶' : species == 'cat' ? '🐱' : '🐾';
}