// lib/core/providers/role_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/role_service.dart';

final roleProvider = AsyncNotifierProvider<RoleNotifier, UserProfile?>(
  RoleNotifier.new,
);

class RoleNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    return await RoleService().getMyProfile();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => RoleService().getMyProfile(),
    );
  }

  void clear() {
    state = const AsyncData(null);
  }
}