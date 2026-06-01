// lib/presentation/screens/donations/donation_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/shelter.dart';
import '../../../data/services/donation_service.dart';

class DonationScreen extends StatefulWidget {
  final Shelter shelter;
  const DonationScreen({super.key, required this.shelter});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  final _donationService = DonationService();
  final _messageCtrl     = TextEditingController();

  double _selectedAmount = 50;
  bool   _loading        = false;
  bool   _done           = false;
  Map<String, dynamic> _totals = {};

  final _amounts = [20.0, 50.0, 100.0, 200.0, 500.0];

  bool get _hasQr => widget.shelter.qrUrl != null;

  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTotals() async {
    final t = await _donationService.getShelterTotals(widget.shelter.id);
    if (mounted) setState(() => _totals = t);
  }

  Future<void> _donate() async {
    setState(() => _loading = true);
    try {
      await _donationService.donate(
        shelterId: widget.shelter.id,
        amount:    _selectedAmount,
        message:   _messageCtrl.text.trim().isEmpty
            ? null
            : _messageCtrl.text.trim(),
      );
      if (mounted) setState(() => _done = true);
      await _loadTotals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        appBar: AppBar(title: const Text('Donar')),
        body: _successView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Donar a ${widget.shelter.name}'),
      ),
      body: _hasQr ? _mainView() : _noQrView(),
    );
  }

  // ─── Vista principal (refugio tiene QR) ──────────────────────
  Widget _mainView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Header del refugio
          _shelterHeader(),

          // Estadísticas
          if (_totals.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _StatCard(
                  label: 'Donaciones',
                  value: '${_totals['total_donations'] ?? 0}',
                  icon: Icons.people_outline,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Total recaudado',
                  value: 'Bs. ${((_totals['total_amount'] ?? 0) as num).toStringAsFixed(0)}',
                  icon: Icons.attach_money,
                ),
              ],
            ),
          ],

          const SizedBox(height: 28),

          // ── PASO 1: QR ─────────────────────────────────────
          _StepHeader(n: '1', label: 'Escanea el QR y deposita'),
          const SizedBox(height: 4),
          const Text(
            'Abre tu app bancaria o billetera digital y escanea el código.',
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Imagen QR del refugio
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.09),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.15), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.shelter.qrUrl!,
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => SizedBox(
                    width: 240,
                    height: 240,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No se pudo cargar la imagen',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── PASO 2: Registrar ───────────────────────────────
          _StepHeader(n: '2', label: 'Registra tu donación'),
          const SizedBox(height: 4),
          const Text(
            'Después de transferir, registra el monto aquí para que el refugio lleve el control.',
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Montos
          const Text('Monto transferido',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _amounts.map((amount) {
              final selected = _selectedAmount == amount;
              return Material(
                color: selected ? AppTheme.primary : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => setState(() => _selectedAmount = amount),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Bs. ${amount.toInt()}',
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _amountLabel(amount),
                          style: TextStyle(
                            color: selected ? Colors.white70 : Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Mensaje
          const Text('Mensaje al refugio (opcional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _messageCtrl,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Ej: Espero que esto ayude a los peluditos',
            ),
          ),

          const SizedBox(height: 12),

          // Resumen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Monto a registrar',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                Text(
                  'Bs. ${_selectedAmount.toInt()}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Botón
          ElevatedButton.icon(
            onPressed: _loading ? null : _donate,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _loading
                  ? 'Registrando...'
                  : 'Registrar donación de Bs. ${_selectedAmount.toInt()}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sin QR configurado ───────────────────────────────────────
  Widget _noQrView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Header del refugio compacto
            _shelterHeader(),
            const SizedBox(height: 36),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_2,
                  size: 64, color: Colors.orange),
            ),
            const SizedBox(height: 24),

            const Text(
              'Sin imagen de pago',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Este refugio aún no ha subido su código QR o imagen de depósito. '
              'Puedes contactarlos directamente para coordinar tu donación.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 32),

            OutlinedButton.icon(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/shelters'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Pantalla de éxito ────────────────────────────────────────
  Widget _successView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite,
                    size: 72, color: Color(0xFF2D6A4F)),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '¡Gracias por tu donación!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tu aporte de Bs. ${_selectedAmount.toInt()} llegará a ${widget.shelter.name} y ayudará a muchos animales.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () =>
                  setState(() { _done = false; _messageCtrl.clear(); }),
              icon: const Icon(Icons.volunteer_activism),
              label: const Text('Donar de nuevo'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/shelters'),
              child: const Text('Volver al refugio',
                  style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header del refugio ───────────────────────────────────────
  Widget _shelterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          // Foto del refugio
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: widget.shelter.imageUrl != null
                  ? Image.network(
                      widget.shelter.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _shelterPlaceholder(),
                    )
                  : _shelterPlaceholder(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.shelter.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (widget.shelter.address != null)
                  Text(
                    widget.shelter.address!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shelterPlaceholder() => Container(
        color: AppTheme.primary.withOpacity(0.12),
        child: const Center(
          child: Icon(Icons.home_work_outlined,
              color: AppTheme.primary, size: 26),
        ),
      );

  // ─── Helpers ──────────────────────────────────────────────────
  String _amountLabel(double amount) {
    if (amount == 20)  return 'Comida x1 día';
    if (amount == 50)  return 'Vacuna básica';
    if (amount == 100) return 'Consulta vet.';
    if (amount == 200) return 'Esterilización';
    if (amount == 500) return 'Mes completo';
    return '';
  }
}

// ─── Cabecera de paso ─────────────────────────────────────────
class _StepHeader extends StatelessWidget {
  final String n;
  final String label;
  const _StepHeader({required this.n, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            n,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ─── Stat card ────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
