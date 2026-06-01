// lib/presentation/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/role_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading     = false;
  bool _obscurePass = true;
  bool _obscureConf = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _error = null);

    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    final confirm  = _confirmCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Completa todos los campos');
      return;
    }
    if (name.length < 3) {
      setState(() => _error = 'El nombre debe tener al menos 3 caracteres');
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      setState(() => _error = 'Correo electrónico no válido');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;

      // 1. Crear usuario en Supabase Auth
      final res = await client.auth.signUp(
        email:    email,
        password: password,
        data:     {'full_name': name},
      );

      if (!mounted) return;

      final user = res.user;
      if (user == null) {
        setState(() =>
            _error = 'No se pudo crear la cuenta. Intenta de nuevo.');
        return;
      }

      // 2. Sin sesión = email confirmation activo en Supabase.
      //    Desactívalo: Dashboard → Authentication → Providers → Email → "Confirm email" OFF
      if (res.session == null) {
        _showEmailConfirmationDialog();
        return;
      }

      // 3. Guardar perfil usando RPC con SECURITY DEFINER (bypasea RLS).
      //    Garantiza que el perfil siempre se crea correctamente.
      await client.rpc('create_user_profile', params: {
        'p_id':        user.id,
        'p_full_name': name,
        'p_email':     email,
      });

      // 4. Cargar perfil en Riverpod y navegar al home.
      // Cada await necesita su propio guard — el router puede navegar
      // y descartar este widget antes de que reload() termine.
      if (!mounted) return;
      await ref.read(roleProvider.notifier).reload();
      if (!mounted) return;
      context.go('/home');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _translateError(e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showEmailConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Confirma tu correo'),
        content: const Text(
          'Te enviamos un enlace de confirmación a tu correo electrónico. '
          'Ábrelo y luego inicia sesión.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            child: const Text('Ir al login'),
          ),
        ],
      ),
    );
  }

  String _translateError(String msg) {
    if (msg.contains('User already registered') ||
        msg.contains('already been registered'))
      return 'Este correo ya está registrado';
    if (msg.contains('Password should be'))
      return 'La contraseña debe tener al menos 6 caracteres';
    if (msg.contains('rate limit'))
      return 'Demasiados intentos, espera un momento';
    if (msg.contains('invalid')) return 'Correo electrónico no válido';
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ─────────────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pets,
                      size: 48,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Crear cuenta',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Únete a la comunidad AdoptaPet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 32),

                // ── Nombre ──────────────────────────────────
                AuthField(
                  controller: _nameCtrl,
                  hint: 'Nombre completo',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),

                // ── Email ───────────────────────────────────
                AuthField(
                  controller: _emailCtrl,
                  hint: 'Correo electrónico',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                ),
                const SizedBox(height: 14),

                // ── Contraseña ──────────────────────────────
                AuthField(
                  controller: _passCtrl,
                  hint: 'Contraseña (mínimo 6 caracteres)',
                  icon: Icons.lock_outlined,
                  obscure: _obscurePass,
                  onToggleObscure: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
                const SizedBox(height: 14),

                // ── Confirmar ───────────────────────────────
                AuthField(
                  controller: _confirmCtrl,
                  hint: 'Confirmar contraseña',
                  icon: Icons.lock_outlined,
                  obscure: _obscureConf,
                  onToggleObscure: () =>
                      setState(() => _obscureConf = !_obscureConf),
                  onSubmitted: (_) => _register(),
                ),

                // ── Info de rol ─────────────────────────────
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.secondary.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: AppTheme.secondary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Todas las cuentas inician como Adoptante. Puedes solicitar el rol de Refugio desde el menú principal.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.secondary),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Error ───────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AuthErrorBanner(message: _error!),
                ],

                const SizedBox(height: 24),

                // ── Botón ───────────────────────────────────
                AuthPrimaryButton(
                  label: 'Crear cuenta',
                  loading: _loading,
                  onPressed: _register,
                ),

                const SizedBox(height: 16),

                AuthLinkText(
                  prefix: '¿Ya tienes cuenta? ',
                  link: 'Inicia sesión',
                  onPressed:
                      _loading ? null : () => context.go('/login'),
                ),

                const SizedBox(height: 10),
                Text(
                  'Al registrarte aceptas nuestros términos y política de privacidad',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
