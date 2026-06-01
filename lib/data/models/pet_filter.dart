// lib/data/models/pet_filter.dart
class PetFilter {
  final String? species;
  final String? gender;
  final String? ageRange;

  const PetFilter({
    this.species,
    this.gender,
    this.ageRange,
  });

  bool get isEmpty =>
      species == null && gender == null && ageRange == null;

  int get activeCount => [species, gender, ageRange]
      .where((f) => f != null)
      .length;

  PetFilter copyWith({
    String? species,
    String? gender,
    String? ageRange,
    bool clearSpecies  = false,
    bool clearGender   = false,
    bool clearAgeRange = false,
  }) {
    return PetFilter(
      species:  clearSpecies  ? null : species  ?? this.species,
      gender:   clearGender   ? null : gender   ?? this.gender,
      ageRange: clearAgeRange ? null : ageRange ?? this.ageRange,
    );
  }

  // Convertir edad a rango en meses
  (int?, int?) get ageMonthsRange {
    switch (ageRange) {
      case 'cachorro': return (0, 12);
      case 'joven':    return (13, 36);
      case 'adulto':   return (37, null);
      default:         return (null, null);
    }
  }
}