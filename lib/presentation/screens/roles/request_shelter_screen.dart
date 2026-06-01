// lib/presentation/screens/roles/request_shelter_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/role_service.dart';
import '../../../core/providers/role_provider.dart';

class RequestShelterScreen extends ConsumerStatefulWidget {
  const RequestShelterScreen({super.key});
  @override
  ConsumerState<RequestShelterScreen> createState() =>
      _RequestShelterScreenState();
}

class _RequestShelterScreenState
    extends ConsumerState<RequestShelterScreen> {
  final _nameCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _roleService = RoleService();

  bool _loading   = false;
  bool _submitted = false;
  Map<String, dynamic>? _existingRequest;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkExisting() async {
    final req = await _roleService.getMyRequest();
    if (mounted) setState(() => _existingRequest = req);
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nombre y descripción son obligatorios')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _roleService.requestShelterRole(
        shelterName: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
      );
      setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar ser refugio')),
      body: _existingRequest != null
          ? _statusView()
          : _submitted
              ? _successView()
              : _form(),
    );
  }

  // ── Vista de estado de solicitud existente ────────────────
  Widget _statusView() {
    final status = _existingRequest!['status'] as String;

    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;

    switch (status) {
      case 'approved':
        color    = const Color(0xFF2D6A4F);
        icon     = Icons.check_circle;
        title    = '¡Solicitud aprobada!';
        subtitle = 'Ya tienes acceso como refugio.';
        break;
      case 'rejected':
        color    = Colors.red;
        icon     = Icons.cancel;
        title    = 'Solicitud rechazada';
        subtitle = _existingRequest!['admin_note'] as String? ??
            'Contacta al administrador.';
        break;
      default:
        color    = const Color(0xFFFF9800);
        icon     = Icons.hourglass_top;
        title    = 'Solicitud pendiente';
        subtitle = 'El administrador revisará tu solicitud pronto.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Botón según estado
            if (status == 'approved')
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(roleProvider.notifier).reload();
                  context.go('/home');
                },
                icon: const Icon(Icons.home),
                label: const Text('Ir al inicio'),
              ),
            if (status == 'rejected')
              ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
              ),
            if (status == 'pending')
              OutlinedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Volver al inicio'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF9800),
                  side: const BorderSide(color: Color(0xFFFF9800)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Vista de éxito al enviar ──────────────────────────────
  Widget _successView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top,
                  size: 64, color: Color(0xFFFF9800)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Solicitud enviada',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'El administrador revisará tu solicitud y recibirás una respuesta pronto.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.home),
              label: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Formulario ────────────────────────────────────────────
  Widget _form() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFF6B35).withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: Color(0xFFFF6B35), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'El administrador aprobará o rechazará tu solicitud.',
                    style: TextStyle(
                        color: Color(0xFFFF6B35), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _label('Nombre del refugio *'),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              hintText: 'Ej: Refugio Patitas Felices',
              prefixIcon: Icon(Icons.home_work_outlined),
            ),
          ),
          const SizedBox(height: 16),

          _label('Descripción *'),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe tu refugio y qué animales cuidan',
            ),
          ),
          const SizedBox(height: 16),

          _label('Teléfono'),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '+591 4 XXXXXXX',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),

          _label('Dirección'),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              hintText: 'Av. América 123, Cochabamba',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label:
                Text(_loading ? 'Enviando...' : 'Enviar solicitud'),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
        ),
      );
}