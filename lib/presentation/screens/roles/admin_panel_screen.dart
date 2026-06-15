import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/pet.dart';
import '../../../data/services/pet_service.dart';
import '../../../data/services/role_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _roleService = RoleService();
  final _petService  = PetService();

  Map<String, int>          _stats    = {};
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _users    = [];
  List<Map<String, dynamic>> _allPets  = [];

  bool _loadingStats    = true;
  bool _loadingRequests = true;
  bool _loadingUsers    = true;
  bool _loadingPets     = true;

  String? _errorStats;
  String? _errorRequests;
  String? _errorUsers;
  String? _errorPets;

  // Filtro de mascotas
  String _petSearch  = '';
  String _petFilter  = 'all'; // all | available | adopted

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadStats();
    _loadRequests();
    _loadUsers();
    _loadPets();
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() { _loadingStats = true; _errorStats = null; });
    try {
      final s = await _roleService.getStats();
      if (mounted) setState(() { _stats = s; _loadingStats = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingStats = false; _errorStats = '$e'; });
    }
  }

  Future<void> _loadRequests() async {
    if (mounted) setState(() { _loadingRequests = true; _errorRequests = null; });
    try {
      final r = await _roleService.getPendingRequests();
      if (mounted) setState(() { _requests = r; _loadingRequests = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingRequests = false; _errorRequests = '$e'; });
    }
  }

  Future<void> _loadUsers() async {
    if (mounted) setState(() { _loadingUsers = true; _errorUsers = null; });
    try {
      final u = await _roleService.getAllUsers();
      if (mounted) setState(() { _users = u; _loadingUsers = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingUsers = false; _errorUsers = '$e'; });
    }
  }

  Future<void> _loadPets() async {
    if (mounted) setState(() { _loadingPets = true; _errorPets = null; });
    try {
      final p = await _petService.getAllPetsAdmin();
      if (mounted) setState(() { _allPets = p; _loadingPets = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingPets = false; _errorPets = '$e'; });
    }
  }

  // ── Approve / Reject requests ──────────────────────────────

  Future<void> _approve(String requestId) async {
    try {
      await _roleService.approveRequest(requestId);
      _loadRequests();
      _loadUsers();
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refugio aprobado'),
            backgroundColor: Color(0xFF2D6A4F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aprobar: $e')),
        );
      }
    }
  }

  Future<void> _reject(String requestId) async {
    final noteCtrl = TextEditingController();
    final confirm  = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            hintText: 'Motivo del rechazo (opcional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    noteCtrl.dispose();
    if (confirm == true) {
      try {
        await _roleService.rejectRequest(requestId,
            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
        _loadRequests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Solicitud rechazada')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al rechazar: $e')),
          );
        }
      }
    }
  }

  Future<void> _changeRole(String userId, String currentRole) async {
    final roles = ['adoptante', 'refugio', 'admin'];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Cambiar rol'),
        children: roles.map((r) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, r),
          child: Row(
            children: [
              Icon(_roleIcon(r), color: _roleColor(r), size: 20),
              const SizedBox(width: 12),
              Text(r, style: TextStyle(
                fontWeight: r == currentRole
                    ? FontWeight.bold : FontWeight.normal,
              )),
              if (r == currentRole) ...[
                const SizedBox(width: 8),
                const Text('(actual)',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ],
          ),
        )).toList(),
      ),
    );
    if (selected != null && selected != currentRole) {
      try {
        await _roleService.changeUserRole(userId, selected);
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rol cambiado a $selected')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cambiar rol: $e')),
          );
        }
      }
    }
  }

  // ── Delete pet ─────────────────────────────────────────────

  Future<void> _deletePet(Map<String, dynamic> petMap) async {
    final name    = petMap['name'] as String? ?? 'esta mascota';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar mascota'),
        content: Text('¿Eliminar a $name? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _petService.deletePet(petMap['id'] as String);
        _loadPets();
        _loadStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name eliminado')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  // ── Edit pet dialog ────────────────────────────────────────

  Future<void> _editPetDialog(Map<String, dynamic> petMap) async {
    final pet = Pet.fromJson(petMap);

    final nameCtrl  = TextEditingController(text: pet.name);
    final breedCtrl = TextEditingController(text: pet.breed);
    final descCtrl  = TextEditingController(text: pet.description);
    final ageCtrl   = TextEditingController(
        text: pet.ageMonths?.toString() ?? '');

    String species = pet.species;
    String gender  = pet.gender ?? 'male';
    List<String> images = [
      if (pet.imageUrl != null && (pet.imageUrl?.isNotEmpty ?? false))
        pet.imageUrl!,
      ...pet.extraImages,
    ];
    bool uploading = false;
    bool saving    = false;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          Future<void> save() async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              setModal(() => error = 'El nombre es obligatorio');
              return;
            }
            setModal(() { saving = true; error = null; });
            try {
              final mainImg = images.isNotEmpty ? images.first : null;
              final extras  = images.length > 1 ? images.sublist(1) : <String>[];
              await _petService.updatePet(
                petId:        pet.id,
                name:         name,
                species:      species,
                breed:        breedCtrl.text.trim().isEmpty
                    ? null : breedCtrl.text.trim(),
                ageMonths:    int.tryParse(ageCtrl.text),
                gender:       gender,
                description:  descCtrl.text.trim().isEmpty
                    ? null : descCtrl.text.trim(),
                imageUrl:     mainImg,
                extraImages:  extras,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadPets();
            } catch (e) {
              setModal(() { saving = false; error = 'Error: $e'; });
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Editar mascota',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Imágenes (máx. 5) ──────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Fotos',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(width: 6),
                          Text('${images.length}/5',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 90,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ...images.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final url = entry.value;
                              return Container(
                                width: 80, height: 80,
                                margin: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        url,
                                        width: 80, height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                              color: const Color(0xFFF5F5F5),
                                              child: const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey),
                                            ),
                                      ),
                                    ),
                                    if (idx == 0)
                                      Positioned(
                                        bottom: 3, left: 3,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text('Principal',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 7,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ),
                                      ),
                                    Positioned(
                                      top: 2, right: 2,
                                      child: Material(
                                        color: Colors.black54,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: saving
                                              ? null
                                              : () => setModal(() =>
                                                    images.removeAt(idx)),
                                          child: const Padding(
                                            padding: EdgeInsets.all(3),
                                            child: Icon(Icons.close,
                                                color: Colors.white,
                                                size: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (uploading)
                              Container(
                                width: 80, height: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              ),
                            if (images.length < 5 && !uploading)
                              Material(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: saving
                                      ? null
                                      : () async {
                                          final file =
                                              await ImagePicker().pickImage(
                                                  source:
                                                      ImageSource.gallery,
                                                  maxWidth: 1200);
                                          if (file == null) return;
                                          setModal(() => uploading = true);
                                          try {
                                            final bytes =
                                                await file.readAsBytes();
                                            final ext =
                                                file.name.split('.').last;
                                            final fileName =
                                                '${const Uuid().v4()}.$ext';
                                            await Supabase
                                                .instance.client.storage
                                                .from('pet-images')
                                                .uploadBinary(fileName, bytes,
                                                    fileOptions: FileOptions(
                                                        contentType:
                                                            'image/$ext',
                                                        upsert: true));
                                            final url = Supabase
                                                .instance.client.storage
                                                .from('pet-images')
                                                .getPublicUrl(fileName);
                                            setModal(() {
                                              images.add(url);
                                              uploading = false;
                                            });
                                          } catch (_) {
                                            setModal(() => uploading = false);
                                          }
                                        },
                                  child: const SizedBox(
                                    width: 80, height: 80,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate,
                                            color: Colors.grey, size: 28),
                                        SizedBox(height: 2),
                                        Text('Agregar',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Nombre
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        hintText: 'Nombre *',
                        prefixIcon: Icon(Icons.pets)),
                  ),
                  const SizedBox(height: 10),

                  // Especie
                  Row(
                    children: ['dog', 'cat', 'other'].map((s) {
                      final label = s == 'dog'
                          ? 'Perro'
                          : s == 'cat' ? 'Gato' : 'Otro';
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _SelectBtn(
                            label: label,
                            selected: species == s,
                            selectedColor: AppTheme.primary,
                            onTap: saving
                                ? null
                                : () => setModal(() => species = s),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Género
                  Row(
                    children: [
                      Expanded(
                        child: _SelectBtn(
                          label: 'Macho',
                          selected: gender == 'male',
                          selectedColor: const Color(0xFF2196F3),
                          onTap: saving
                              ? null
                              : () => setModal(() => gender = 'male'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SelectBtn(
                          label: 'Hembra',
                          selected: gender == 'female',
                          selectedColor: const Color(0xFFE91E8C),
                          onTap: saving
                              ? null
                              : () => setModal(() => gender = 'female'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Raza y edad
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: breedCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          decoration:
                              const InputDecoration(hintText: 'Raza'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: ageCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              hintText: 'Edad (meses)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Descripción
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration:
                        const InputDecoration(hintText: 'Descripción'),
                  ),

                  // Error
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Guardar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: saving ? null : save,
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Guardar cambios',
                              style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    nameCtrl.dispose();
    breedCtrl.dispose();
    descCtrl.dispose();
    ageCtrl.dispose();
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de administrador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar todo',
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFFFF6B35),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF6B35),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(text: 'Resumen'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Solicitudes'),
                  if (_requests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B35),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_requests.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Mascotas'),
                  const SizedBox(width: 6),
                  if (!_loadingPets)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_allPets.length}',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            const Tab(text: 'Usuarios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _statsTab(),
          _requestsTab(),
          _petsTab(),
          _usersTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Estadísticas ──────────────────────────────────

  Widget _statsTab() {
    if (_loadingStats) return const Center(child: CircularProgressIndicator());
    if (_errorStats != null) return _errorView(_errorStats!, _loadStats);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen general',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard(
                label: 'Usuarios',
                value: '${_stats['users'] ?? 0}',
                icon: Icons.people_outline,
                color: const Color(0xFF2196F3),
              ),
              _StatCard(
                label: 'Mascotas',
                value: '${_stats['pets'] ?? 0}',
                icon: Icons.pets,
                color: const Color(0xFFFF6B35),
              ),
              _StatCard(
                label: 'Refugios',
                value: '${_stats['shelters'] ?? 0}',
                icon: Icons.home_work_outlined,
                color: const Color(0xFF2D6A4F),
              ),
              _StatCard(
                label: 'Donaciones',
                value: '${_stats['donations'] ?? 0}',
                icon: Icons.volunteer_activism,
                color: const Color(0xFF9C27B0),
              ),
              _StatCard(
                label: 'Solicitudes pendientes',
                value: '${_stats['pending'] ?? 0}',
                icon: Icons.hourglass_top,
                color: const Color(0xFFFF9800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Solicitudes pendientes ────────────────────────

  Widget _requestsTab() {
    if (_loadingRequests) return const Center(child: CircularProgressIndicator());
    if (_errorRequests != null) return _errorView(_errorRequests!, _loadRequests);
    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('Sin solicitudes pendientes',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final req     = _requests[i];
        final profile = req['profiles'] as Map<String, dynamic>?;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.home_work_outlined,
                        color: Color(0xFFFF6B35)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(req['shelter_name'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        if (profile?['full_name'] != null)
                          Text(profile!['full_name'] as String,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Pendiente',
                        style: TextStyle(
                            color: Color(0xFFFF9800),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              if (req['description'] != null) ...[
                const SizedBox(height: 10),
                Text(req['description'] as String,
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
              if (req['address'] != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(req['address'] as String,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ],
              if (req['phone'] != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(req['phone'] as String,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reject(req['id'] as String),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approve(req['id'] as String),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Aprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 3: Mascotas ──────────────────────────────────────

  Widget _petsTab() {
    if (_loadingPets) return const Center(child: CircularProgressIndicator());
    if (_errorPets != null) return _errorView(_errorPets!, _loadPets);

    // Filtrar
    final filtered = _allPets.where((p) {
      final name    = (p['name'] as String? ?? '').toLowerCase();
      final species = (p['species'] as String? ?? '').toLowerCase();
      final shelter = ((p['shelters'] as Map?)?['name'] as String? ?? '').toLowerCase();
      final q       = _petSearch.toLowerCase();

      final matchSearch = q.isEmpty ||
          name.contains(q) || species.contains(q) || shelter.contains(q);

      final adopted = p['is_adopted'] as bool? ?? false;
      final matchFilter = _petFilter == 'all'
          ? true
          : _petFilter == 'adopted' ? adopted : !adopted;

      return matchSearch && matchFilter;
    }).toList();

    return Column(
      children: [
        // Barra de búsqueda + filtro
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, especie o refugio...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _petSearch = v),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                initialValue: _petFilter,
                onSelected: (v) => setState(() => _petFilter = v),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'all',
                      child: Text('Todas')),
                  const PopupMenuItem(
                      value: 'available',
                      child: Text('Disponibles')),
                  const PopupMenuItem(
                      value: 'adopted',
                      child: Text('Adoptadas')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        _petFilter == 'all'
                            ? 'Todas'
                            : _petFilter == 'adopted'
                                ? 'Adoptadas'
                                : 'Disponibles',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        if (filtered.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No hay mascotas que mostrar',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _PetAdminCard(
                petMap: filtered[i],
                onEdit:   () => _editPetDialog(filtered[i]),
                onDelete: () => _deletePet(filtered[i]),
              ),
            ),
          ),
      ],
    );
  }

  // ── Tab 4: Usuarios ──────────────────────────────────────

  Widget _usersTab() {
    if (_loadingUsers) return const Center(child: CircularProgressIndicator());
    if (_errorUsers != null) return _errorView(_errorUsers!, _loadUsers);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final u    = _users[i];
        final role = u['role'] as String? ?? 'adoptante';
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          leading: CircleAvatar(
            backgroundColor: _roleColor(role).withOpacity(0.15),
            child: Icon(_roleIcon(role), color: _roleColor(role), size: 20),
          ),
          title: Text(
            u['full_name'] as String? ?? 'Sin nombre',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(role,
              style: TextStyle(color: _roleColor(role), fontSize: 12)),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.grey),
            onPressed: () => _changeRole(u['id'] as String, role),
            tooltip: 'Cambiar rol',
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  Widget _errorView(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Error al cargar datos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':   return const Color(0xFF1A237E);
      case 'refugio': return const Color(0xFFFF6B35);
      default:        return const Color(0xFF2D6A4F);
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':   return Icons.admin_panel_settings;
      case 'refugio': return Icons.home_work_outlined;
      default:        return Icons.person_outline;
    }
  }
}

// ── Pet card para el admin ────────────────────────────────────

class _PetAdminCard extends StatelessWidget {
  final Map<String, dynamic> petMap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PetAdminCard({
    required this.petMap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name      = petMap['name'] as String? ?? '';
    final species   = petMap['species'] as String? ?? '';
    final breed     = petMap['breed'] as String?;
    final ageMonths = petMap['age_months'] as int?;
    final imageUrl  = petMap['image_url'] as String?;
    final isAdopted = petMap['is_adopted'] as bool? ?? false;
    final shelterName =
        (petMap['shelters'] as Map?)?['name'] as String? ?? 'Refugio desconocido';

    String ageLabel = 'Edad desconocida';
    if (ageMonths != null) {
      ageLabel = ageMonths < 12
          ? '$ageMonths ${ageMonths == 1 ? "mes" : "meses"}'
          : '${ageMonths ~/ 12} ${(ageMonths ~/ 12) == 1 ? "año" : "años"}';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Imagen
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(14)),
            child: SizedBox(
              width: 90,
              height: 90,
              child: imageUrl != null
                  ? Image.network(imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),

          // Info
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (isAdopted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Adoptado',
                              style: TextStyle(
                                  color: AppTheme.secondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(breed ?? species,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                  Text(ageLabel,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.home_work_outlined,
                          size: 11, color: Colors.grey),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(shelterName,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Acciones
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppTheme.primary, size: 20),
                tooltip: 'Editar',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                tooltip: 'Eliminar',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFF5F5F5),
        child: const Center(
            child: Icon(Icons.pets, color: Colors.grey, size: 30)),
      );
}

// ── Stat card ────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Botón de selección (especie/género) ──────────────────────

class _SelectBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback? onTap;

  const _SelectBtn({
    required this.label,
    required this.selected,
    required this.selectedColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: selected ? Colors.white : Colors.black87,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
