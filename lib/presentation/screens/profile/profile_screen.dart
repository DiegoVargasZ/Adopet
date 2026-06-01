// lib/presentation/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/role_service.dart';
import '../../../data/services/meeting_service.dart';
import '../../../data/services/donation_service.dart';

// ── Stats provider ─────────────────────────────────────────────
final _profileStatsProvider =
    FutureProvider.autoDispose<Map<String, int>>((_) async {
  final meetings  = await MeetingService().getMyMeetings();
  final donations = await DonationService().getMyDonations();
  return {
    'meetings':  meetings.length,
    'donations': donations.length,
  };
});

// ── Screen ─────────────────────────────────────────────────────
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl  = TextEditingController();
  bool _editingName = false;
  bool _savingName  = false;
  bool _uploadingAvatar = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Avatar ────────────────────────────────────────────────────
  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file   = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final ext   = file.name.split('.').last.toLowerCase();
      final url   = await RoleService().uploadAvatar(bytes, ext);

      final profile = ref.read(roleProvider).valueOrNull;
      if (profile == null) return;

      await RoleService().updateProfile(
        fullName:  profile.fullName ?? '',
        avatarUrl: url,
      );
      await ref.read(roleProvider.notifier).reload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ── Nombre ────────────────────────────────────────────────────
  void _startEditName(String current) {
    _nameCtrl.text = current;
    setState(() => _editingName = true);
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _savingName = true);
    try {
      await RoleService().updateProfile(fullName: name);
      await ref.read(roleProvider.notifier).reload();
      setState(() => _editingName = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nombre actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    ref.read(roleProvider.notifier).clear();
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(roleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: roleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (profile) {
          if (profile == null) {
            return const Center(child: Text('Perfil no encontrado'));
          }
          return _buildBody(profile);
        },
      ),
    );
  }

  Widget _buildBody(UserProfile profile) {
    final email    = Supabase.instance.client.auth.currentUser?.email ?? '';
    final fmtDate  = DateFormat('d MMM yyyy', 'es');
    final rolColor = _roleColor(profile.role);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // ── Avatar ──────────────────────────────────────────
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              _AvatarWidget(
                avatarUrl: profile.avatarUrl,
                uploading: _uploadingAvatar,
              ),
              Material(
                color: const Color(0xFFFF6B35),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Nombre ──────────────────────────────────────────
          _editingName
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                        ),
                        onSubmitted: (_) => _saveName(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _editingName = false),
                      icon: const Icon(Icons.close),
                    ),
                    _savingName
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            onPressed: _saveName,
                            icon: const Icon(Icons.check,
                                color: Color(0xFF2D6A4F)),
                          ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      profile.fullName?.isNotEmpty == true
                          ? profile.fullName!
                          : 'Sin nombre',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: Colors.grey),
                      onPressed: () =>
                          _startEditName(profile.fullName ?? ''),
                    ),
                  ],
                ),

          const SizedBox(height: 4),

          // Email
          Text(email,
              style:
                  const TextStyle(color: Colors.grey, fontSize: 14)),

          const SizedBox(height: 10),

          // Badge rol
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: rolColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _roleLabel(profile.role),
              style: TextStyle(
                color: rolColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Miembro desde
          Text(
            'Miembro desde ${fmtDate.format(profile.createdAt)}',
            style:
                const TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 28),

          // ── Estadísticas ─────────────────────────────────────
          Consumer(
            builder: (_, ref, __) {
              final statsAsync = ref.watch(_profileStatsProvider);
              return statsAsync.when(
                loading: () => const SizedBox(
                  height: 80,
                  child:
                      Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox(),
                data: (stats) => Row(
                  children: [
                    _StatCard(
                      icon: Icons.event_available_outlined,
                      label: 'Citas',
                      value: '${stats['meetings']}',
                      color: const Color(0xFF7B61FF),
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.volunteer_activism_outlined,
                      label: 'Donaciones',
                      value: '${stats['donations']}',
                      color: const Color(0xFF2D6A4F),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          // ── Accesos rápidos ──────────────────────────────────
          if (profile.isShelter || profile.isAdmin)
            _QuickLink(
              icon: Icons.home_work_outlined,
              label: 'Editar mi refugio',
              onTap: () => context.push('/shelter-settings'),
            ),
          _QuickLink(
            icon: Icons.event_outlined,
            label: 'Mis citas',
            onTap: () => context.push('/meetings'),
          ),
          _QuickLink(
            icon: Icons.volunteer_activism_outlined,
            label: 'Mis donaciones',
            onTap: () => context.push('/my-donations'),
          ),

          const SizedBox(height: 32),

          // ── Cerrar sesión ────────────────────────────────────
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Cerrar sesión',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) => switch (role) {
        'admin'   => const Color(0xFF1A237E),
        'refugio' => AppTheme.primary,
        _         => AppTheme.secondary,
      };

  String _roleLabel(String role) => switch (role) {
        'admin'   => 'Administrador',
        'refugio' => 'Refugio',
        _         => 'Adoptante',
      };
}

// ── Avatar widget ─────────────────────────────────────────────
class _AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final bool uploading;
  const _AvatarWidget({this.avatarUrl, required this.uploading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFF6B35), width: 3),
      ),
      child: ClipOval(
        child: uploading
            ? const ColoredBox(
                color: Color(0xFFF5F5F5),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : avatarUrl != null
                ? Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => const ColoredBox(
        color: Color(0xFFF5F5F5),
        child: Center(
          child: Icon(Icons.person, size: 50, color: Colors.grey),
        ),
      );
}

// ── Stat card ─────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Quick link ────────────────────────────────────────────────
class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLink(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFFFF6B35)),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios,
          size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}
