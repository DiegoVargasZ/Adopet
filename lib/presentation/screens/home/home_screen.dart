// lib/presentation/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/user_profile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roleProvider.notifier).reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(roleProvider);
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pets, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'AdoptaPet',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: AppTheme.textSub, size: 20),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              ref.read(roleProvider.notifier).clear();
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: roleAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: R.maxContent),
            child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserHeader(
                profile: profile,
                email: email,
                onTap: () => context.push('/profile'),
              ),
              const SizedBox(height: 28),

              _SectionTitle(title: 'Explorar'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: R.homeCols(context),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  _GridCard(
                    icon: Icons.map_outlined,
                    label: 'Mapa de\nrefugios',
                    color: AppTheme.primary,
                    onTap: () => context.push('/map'),
                  ),
                  _GridCard(
                    icon: Icons.pets,
                    label: 'Mascotas en\nadopción',
                    color: AppTheme.accent,
                    onTap: () => context.push('/pets'),
                  ),
                  _GridCard(
                    icon: Icons.home_work_outlined,
                    label: 'Refugios',
                    color: AppTheme.primary,
                    onTap: () => context.push('/shelters'),
                  ),
                  _GridCard(
                    icon: Icons.chat_bubble_outline,
                    label: 'Mis\nmensajes',
                    color: AppTheme.accent,
                    onTap: () => context.push('/chats'),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              _SectionTitle(title: 'Mi actividad'),
              const SizedBox(height: 12),
              SizedBox(
                height: 108,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _ActivityCard(
                      icon: Icons.favorite_outline,
                      label: 'Adopciones',
                      color: AppTheme.primary,
                      onTap: () => context.push('/adoptions'),
                    ),
                    _ActivityCard(
                      icon: Icons.event_available_outlined,
                      label: 'Citas',
                      color: AppTheme.accent,
                      onTap: () => context.push('/meetings'),
                    ),
                    _ActivityCard(
                      icon: Icons.volunteer_activism_outlined,
                      label: 'Donaciones',
                      color: AppTheme.primary,
                      onTap: () => context.push('/my-donations'),
                    ),
                  ],
                ),
              ),

              if (profile?.isShelter == true || profile?.isAdmin == true) ...[
                const SizedBox(height: 28),
                _SectionTitle(title: 'Gestión de refugio'),
                const SizedBox(height: 12),
                _ListCard(
                  icon: Icons.add_circle_outline,
                  label: 'Mis mascotas',
                  subtitle: 'Agregar y gestionar mascotas',
                  color: AppTheme.primary,
                  onTap: () => context.push('/manage-pets'),
                ),
                const SizedBox(height: 8),
                _ListCard(
                  icon: Icons.volunteer_activism_outlined,
                  label: 'Donaciones recibidas',
                  subtitle: 'Ver historial de donaciones',
                  color: AppTheme.accent,
                  onTap: () => context.push('/shelter-donations'),
                ),
              ],

              if (profile?.isAdoptante == true) ...[
                const SizedBox(height: 28),
                _SectionTitle(title: 'Mi cuenta'),
                const SizedBox(height: 12),
                _ListCard(
                  icon: Icons.store_outlined,
                  label: 'Solicitar ser refugio',
                  subtitle: 'Registra tu organización',
                  color: AppTheme.accent,
                  onTap: () => context.push('/request-shelter'),
                ),
              ],

              if (profile?.isAdmin == true) ...[
                const SizedBox(height: 28),
                _SectionTitle(title: 'Administración'),
                const SizedBox(height: 12),
                _ListCard(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Panel de administrador',
                  subtitle: 'Estadísticas y gestión global',
                  color: const Color(0xFF1A237E),
                  onTap: () => context.push('/admin'),
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final UserProfile? profile;
  final String email;
  final VoidCallback onTap;

  const _UserHeader({
    required this.profile,
    required this.email,
    required this.onTap,
  });

  String _roleLabel(UserProfile? p) {
    if (p?.isAdmin == true) return 'Administrador';
    if (p?.isShelter == true) return 'Refugio';
    return 'Adoptante';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = profile?.fullName?.trim().split(' ').first;

    return Material(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withOpacity(0.25),
                backgroundImage: (profile?.avatarUrl?.isNotEmpty ?? false)
                    ? NetworkImage(profile!.avatarUrl!)
                    : null,
                child: (profile?.avatarUrl?.isEmpty ?? true)
                    ? const Icon(Icons.person, color: Colors.white, size: 26)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstName != null ? 'Hola, $firstName' : 'Hola',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _roleLabel(profile),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white54, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.textMain,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GridCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMain,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 100,
        child: Material(
          color: AppTheme.bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMain,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ListCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textMain,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textSub,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppTheme.textSub),
          ),
        ),
      ),
    );
  }
}
