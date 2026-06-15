// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/map/map_screen.dart';
import '../../presentation/screens/pets/pets_screen.dart';
import '../../presentation/screens/pets/pet_detail_screen.dart';
import '../../presentation/screens/pets/pet_qr_screen.dart';
import '../../presentation/screens/shelters/shelters_screen.dart';
import '../../presentation/screens/shelters/shelter_detail_screen.dart';
import '../../presentation/screens/chat/chats_list_screen.dart';
import '../../presentation/screens/chat/chat_screen.dart';
import '../../presentation/screens/donations/donations_screen.dart';
import '../../presentation/screens/donations/my_donations_screen.dart';
import '../../presentation/screens/roles/request_shelter_screen.dart';
import '../../presentation/screens/roles/admin_panel_screen.dart';
import '../../presentation/screens/roles/manage_pets_screen.dart';
import '../../presentation/screens/roles/shelter_donations_screen.dart';
import '../../presentation/screens/roles/shelter_settings_screen.dart';
import '../../presentation/screens/meetings/meetings_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/adoptions/adoptions_screen.dart';
import '../../presentation/widgets/app_shell.dart';
import '../../presentation/screens/public/public_pet_screen.dart';
import '../../data/models/pet.dart';
import '../../data/models/shelter.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier();

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth   = session != null;
      final location = state.matchedLocation;

      // Splash → redirigir según sesión
      if (location == '/') {
        await Future.delayed(const Duration(seconds: 2));
        return isAuth ? '/home' : '/login';
      }

      const publicRoutes = ['/login', '/register'];
      // /p/:petId es la página pública del QR — no requiere login
      if (!isAuth && !publicRoutes.contains(location) &&
          !location.startsWith('/p/')) return '/login';
      if (isAuth && publicRoutes.contains(location)) return '/home';

      return null;
    },
    routes: [
      // ── Rutas públicas ────────────────────────────────────────
      GoRoute(path: '/',         builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // Página pública del QR — sin login, para quien escanea
      GoRoute(
        path: '/p/:petId',
        builder: (_, state) =>
            PublicPetScreen(petId: state.pathParameters['petId']!),
      ),

      // ── Rutas autenticadas — envueltas en el shell responsivo ──
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.matchedLocation,
          child:    child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/map',
            builder: (_, __) => const MapScreen(),
          ),
          GoRoute(
            path: '/pets',
            builder: (_, __) => const PetsScreen(),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (_, state) =>
                    PetDetailScreen(pet: state.extra as Pet),
              ),
              GoRoute(
                path: 'qr',
                builder: (_, state) =>
                    PetQrScreen(pet: state.extra as Pet),
              ),
            ],
          ),
          GoRoute(
            path: '/shelters',
            builder: (_, __) => const SheltersScreen(),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (_, state) =>
                    ShelterDetailScreen(shelter: state.extra as Shelter),
              ),
            ],
          ),
          GoRoute(
            path: '/chats',
            builder: (_, __) => const ChatsListScreen(),
            routes: [
              GoRoute(
                path: 'chat',
                builder: (_, state) {
                  final args = state.extra as Map<String, String>;
                  return ChatScreen(
                    chatId:      args['chatId']!,
                    shelterName: args['shelterName']!,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/donations',
            builder: (_, state) =>
                DonationScreen(shelter: state.extra as Shelter),
          ),
          GoRoute(
            path: '/my-donations',
            builder: (_, __) => const MyDonationsScreen(),
          ),
          GoRoute(
            path: '/request-shelter',
            builder: (_, __) => const RequestShelterScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (_, __) => const AdminPanelScreen(),
          ),
          GoRoute(
            path: '/manage-pets',
            builder: (_, __) => const ManagePetsScreen(),
          ),
          GoRoute(
            path: '/shelter-donations',
            builder: (_, __) => const ShelterDonationsScreen(),
          ),
          GoRoute(
            path: '/shelter-settings',
            builder: (_, __) => const ShelterSettingsScreen(),
          ),
          GoRoute(
            path: '/meetings',
            builder: (_, __) => const MeetingsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/adoptions',
            builder: (_, __) => const AdoptionsScreen(),
          ),
        ],
      ),
    ],
  );
});

// ── Escucha cambios de sesión ─────────────────────────────────────
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }

  late final dynamic _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
