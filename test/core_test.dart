import 'package:flutter_test/flutter_test.dart';
import 'package:adoptapet/core/utils/validators.dart';
import 'package:adoptapet/data/models/pet_filter.dart';
import 'package:adoptapet/data/models/user_profile.dart';

void main() {
  test('los filtros conservan criterios y convierten edades a meses', () {
    const initial = PetFilter(species: 'dog', ageRange: 'joven');
    final changed = initial.copyWith(gender: 'female');
    expect(changed.activeCount, 3);
    expect(changed.ageMonthsRange, (13, 36));
    expect(changed.copyWith(clearSpecies: true).species, isNull);
    expect(changed.copyWith(clearAgeRange: true).ageMonthsRange, (null, null));
  });

  test('los permisos de gestión corresponden al rol', () {
    final createdAt = DateTime.utc(2026);
    for (final role in ['adoptante', 'refugio', 'admin']) {
      final profile = UserProfile(id: 'user', role: role, createdAt: createdAt);
      expect(profile.canManagePets, role != 'adoptante');
      expect(profile.isAdmin, role == 'admin');
    }
  });

  test('se rechazan datos vacíos y contraseñas cortas', () {
    expect(Validators.validateEmail(' '), isNotNull);
    expect(Validators.validatePassword('12345'), isNotNull);
    expect(Validators.validateEmail('persona@ejemplo.com'), isNull);
    expect(Validators.validatePassword('123456'), isNull);
  });
}
