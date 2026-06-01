import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/pet_filter.dart';

final petFilterProvider =
    NotifierProvider<PetFilterNotifier, PetFilter>(
  PetFilterNotifier.new,
);

class PetFilterNotifier extends Notifier<PetFilter> {
  @override
  PetFilter build() => const PetFilter();

  void setSpecies(String? species) {
    state = state.copyWith(
      species: species,
      clearSpecies: species == null,
    );
  }

  void setGender(String? gender) {
    state = state.copyWith(
      gender: gender,
      clearGender: gender == null,
    );
  }

  void setAgeRange(String? ageRange) {
    state = state.copyWith(
      ageRange: ageRange,
      clearAgeRange: ageRange == null,
    );
  }

  void clearAll() {
    state = const PetFilter();
  }
}