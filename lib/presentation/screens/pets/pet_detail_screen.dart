// lib/presentation/screens/pets/pet_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/pet.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/meeting_service.dart';
import '../../../data/services/adoption_service.dart';

class PetDetailScreen extends StatelessWidget {
  final Pet pet;
  const PetDetailScreen({super.key, required this.pet});

  // ── Galería de imágenes ────────────────────────────────────────
  Widget _gallery() => _PetGallery(images: pet.allImages);

  // ── Info + botones (reutilizable en ambos layouts) ─────────────
  Widget _info(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(pet.name,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              Text(pet.speciesEmoji,
                  style: const TextStyle(fontSize: 32)),
            ],
          ),
          if (pet.breed != null && pet.breed!.isNotEmpty)
            Text(pet.breed!,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _InfoChip(Icons.cake_outlined, pet.ageLabel),
              if (pet.gender != null)
                _InfoChip(
                  pet.gender == 'male' ? Icons.male : Icons.female,
                  pet.gender == 'male' ? 'Macho' : 'Hembra',
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Banner de adoptado
          if (pet.isAdopted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2D6A4F)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.favorite, color: Color(0xFF2D6A4F), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¡Esta mascota ya fue adoptada! 🎉\nSigue explorando para encontrar tu compañero ideal.',
                      style: TextStyle(
                        color: Color(0xFF2D6A4F),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (pet.description != null && pet.description!.isNotEmpty) ...[
            const Text('Sobre mí',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(pet.description!,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 15, height: 1.6)),
            const SizedBox(height: 32),
          ],
          // Botón principal — deshabilitado si ya está adoptado
          ElevatedButton.icon(
            onPressed: pet.isAdopted ? null : () => _requestAdoption(context),
            icon: Icon(pet.isAdopted ? Icons.check_circle : Icons.favorite),
            label: Text(pet.isAdopted ? 'Ya adoptado' : 'Solicitar adopción'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor:
                  pet.isAdopted ? Colors.grey.shade300 : const Color(0xFFFF6B35),
              foregroundColor:
                  pet.isAdopted ? Colors.grey.shade600 : Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          // Botones secundarios — visita y chat solo disponibles si no está adoptado
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      pet.isAdopted ? null : () => _scheduleMeeting(context),
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: const Text('Agendar visita'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    side: BorderSide(
                        color: pet.isAdopted
                            ? Colors.grey.shade300
                            : const Color(0xFFFF6B35)),
                    foregroundColor: pet.isAdopted
                        ? Colors.grey.shade400
                        : const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openChat(context),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Contactar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    side: BorderSide(color: Colors.grey.shade400),
                    foregroundColor: Colors.grey.shade700,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = R.isWide(context);

    if (isWide) {
      // ── Desktop / Tablet: imagen izquierda + detalle derecha ──
      return Scaffold(
        appBar: AppBar(
          title: Text(pet.name),
          backgroundColor: const Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_rounded),
              tooltip: 'Ver código QR',
              onPressed: () => context.push('/pets/qr', extra: pet),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: R.maxContent),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Galería fija (40% del ancho, máx 480px)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.40,
                    height: 420,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(16),
                      ),
                      child: _gallery(),
                    ),
                  ),
                ),
                // Detalle scrollable
                Expanded(
                  child: SingleChildScrollView(child: _info(context)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Móvil: SliverAppBar con imagen expandida ───────────────
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: const Color(0xFFFF6B35),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_rounded),
                tooltip: 'Ver código QR',
                onPressed: () => context.push('/pets/qr', extra: pet),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(background: _gallery()),
          ),
          SliverToBoxAdapter(child: _info(context)),
        ],
      ),
    );
  }

  Future<void> _requestAdoption(BuildContext context) async {
    if (pet.shelterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta mascota no tiene un refugio asociado.')),
      );
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para solicitar adopción.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AdoptionSheet(pet: pet),
    );
  }

  Future<void> _scheduleMeeting(BuildContext context) async {
    if (pet.shelterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta mascota no tiene un refugio asociado.')),
      );
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para agendar una visita.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ScheduleSheet(pet: pet),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    if (pet.shelterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta mascota no tiene un refugio asociado.'),
        ),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para contactar al refugio.'),
        ),
      );
      return;
    }

    try {
      // Obtener nombre del refugio y crear/obtener chat en paralelo
      final results = await Future.wait<dynamic>([
        Supabase.instance.client
            .from('shelters')
            .select('name')
            .eq('id', pet.shelterId!)
            .maybeSingle(),
        ChatService().getOrCreateChat(pet.shelterId!),
      ]);

      final shelterData  = results[0] as Map<String, dynamic>?;
      final shelterName  = shelterData?['name'] as String? ?? 'Refugio';
      final chatId       = results[1] as String;

      if (context.mounted) {
        context.push('/chats/chat', extra: {
          'chatId': chatId,
          'shelterName': shelterName,
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir chat: $e')),
        );
      }
    }
  }
}

// ── Bottom sheet para solicitar adopción ──────────────────────
class _AdoptionSheet extends StatefulWidget {
  final Pet pet;
  const _AdoptionSheet({required this.pet});

  @override
  State<_AdoptionSheet> createState() => _AdoptionSheetState();
}

class _AdoptionSheetState extends State<_AdoptionSheet> {
  final _msgCtrl = TextEditingController();
  bool _loading  = false;
  bool _done     = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.pet.shelterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta mascota no tiene refugio asociado.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await AdoptionService().requestAdoption(
        petId:     widget.pet.id,
        shelterId: widget.pet.shelterId!,
        message:   _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al solicitar adopción: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: _done ? _successView() : _form(),
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        Text(
          'Adoptar a ${widget.pet.name} ${widget.pet.speciesEmoji}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'El refugio revisará tu solicitud y te dará una respuesta.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),

        // Info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3EE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Cómo funciona?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              SizedBox(height: 8),
              _StepItem(n: '1', text: 'Envías tu solicitud con un mensaje'),
              _StepItem(n: '2', text: 'El refugio revisa y responde'),
              _StepItem(n: '3', text: 'Si aprueban, la mascota queda reservada'),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text('¿Por qué quieres adoptar a ${widget.pet.name}?',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _msgCtrl,
          maxLines: 4,
          maxLength: 300,
          decoration: const InputDecoration(
            hintText:
                'Ej: Tengo casa con jardín, experiencia con perros, busco un compañero activo...',
          ),
        ),

        const SizedBox(height: 16),

        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.favorite),
          label: Text(_loading ? 'Enviando...' : 'Enviar solicitud'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: const Color(0xFFFF6B35),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _successView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3EE),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite,
                size: 60, color: Color(0xFFFF6B35)),
          ),
        ),
        const SizedBox(height: 24),
        const Text('¡Solicitud enviada!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'El refugio revisará tu solicitud. Te notificaremos cuando haya una respuesta.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            context.pop();
            context.push('/adoptions');
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: const Color(0xFFFF6B35),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Ver mis solicitudes'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Volver a la mascota',
              style: TextStyle(color: Colors.grey)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  final String n;
  final String text;
  const _StepItem({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            width: 20, height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFF6B35),
              shape: BoxShape.circle,
            ),
            child: Text(n,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet para agendar cita ────────────────────────────
class _ScheduleSheet extends StatefulWidget {
  final Pet pet;
  const _ScheduleSheet({required this.pet});

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  final _notesCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _loading = false;
  bool _done = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  DateTime? get _scheduledAt {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (t != null) setState(() => _selectedTime = t);
  }

  Future<void> _confirm() async {
    final dt = _scheduledAt;
    if (dt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha y hora')),
      );
      return;
    }
    if (widget.pet.shelterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta mascota no tiene refugio asociado.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await MeetingService().requestMeeting(
        petId:       widget.pet.id,
        shelterId:   widget.pet.shelterId!,
        scheduledAt: dt,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al agendar cita: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: _done ? _successView() : _form(),
      ),
    );
  }

  Widget _form() {
    final fmt = DateFormat('EEE d MMM yyyy', 'es');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        Text(
          'Agendar visita — ${widget.pet.name}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'El refugio confirmará o rechazará tu solicitud.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),

        // Fecha
        const Text('Fecha', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: Color(0xFFFF6B35), size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDate != null
                        ? fmt.format(_selectedDate!)
                        : 'Seleccionar fecha',
                    style: TextStyle(
                      color: _selectedDate != null
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Hora
        const Text('Hora', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_outlined,
                      color: Color(0xFFFF6B35), size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _selectedTime != null
                        ? _selectedTime!.format(context)
                        : 'Seleccionar hora',
                    style: TextStyle(
                      color: _selectedTime != null
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Notas
        const Text('Mensaje al refugio (opcional)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'Ej: Tengo experiencia con perros grandes...',
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: _loading ? null : _confirm,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.event_available),
          label: Text(_loading ? 'Enviando...' : 'Solicitar cita'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: const Color(0xFFFF6B35),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _successView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available,
                size: 60, color: Color(0xFF2D6A4F)),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '¡Solicitud enviada!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'El refugio revisará tu solicitud y te confirmará la visita.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            context.pop();
            context.push('/meetings');
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: const Color(0xFF2D6A4F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Ver mis citas'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Volver a la mascota',
              style: TextStyle(color: Color(0xFFFF6B35))),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Galería deslizable de fotos ────────────────────────────────
class _PetGallery extends StatefulWidget {
  final List<String> images;
  const _PetGallery({required this.images});

  @override
  State<_PetGallery> createState() => _PetGalleryState();
}

class _PetGalleryState extends State<_PetGallery> {
  final _ctrl = PageController();
  int _page   = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;

    if (imgs.isEmpty) {
      return Container(
        color: const Color(0xFFF5F5F5),
        child: const Center(child: Icon(Icons.pets, size: 80, color: Colors.grey)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _ctrl,
          itemCount:  imgs.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => Image.network(
            imgs[i],
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => Container(
              color: const Color(0xFFF5F5F5),
              child: const Center(
                  child: Icon(Icons.pets, size: 80, color: Colors.grey)),
            ),
          ),
        ),

        if (imgs.length > 1) ...[
          // Indicadores de punto
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(imgs.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width:  _page == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),

          // Contador
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_page + 1} / ${imgs.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFF6B35)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}