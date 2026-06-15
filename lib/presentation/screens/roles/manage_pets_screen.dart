import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/pet.dart';
import '../../../data/services/pet_service.dart';
import '../../../core/theme/app_theme.dart';

class ManagePetsScreen extends ConsumerStatefulWidget {
  const ManagePetsScreen({super.key});
  @override
  ConsumerState<ManagePetsScreen> createState() => _ManagePetsScreenState();
}

class _ManagePetsScreenState extends ConsumerState<ManagePetsScreen> {
  final _petService = PetService();
  late Future<List<Pet>> _petsFuture;
  bool _showAdopted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final future = _petService.getMyPets();
    setState(() { _petsFuture = future; });
  }

  Future<void> _showPetDialog({Pet? pet}) async {
    final nameCtrl  = TextEditingController(text: pet?.name);
    final breedCtrl = TextEditingController(text: pet?.breed);
    final descCtrl  = TextEditingController(text: pet?.description);
    final ageCtrl   = TextEditingController(text: pet?.ageMonths?.toString());

    String species = pet?.species ?? 'dog';
    String gender  = pet?.gender  ?? 'male';
    List<String> images = [
      if (pet?.imageUrl != null && (pet!.imageUrl?.isNotEmpty ?? false))
        pet.imageUrl!,
      ...(pet?.extraImages ?? []),
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
              final mainImg  = images.isNotEmpty ? images.first : null;
              final extras   = images.length > 1 ? images.sublist(1) : <String>[];
              if (pet == null) {
                await _petService.createPet(
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
              } else {
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
              }
              // Cerrar sheet SOLO después del éxito
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) _load();
            } catch (e) {
              setModal(() {
                saving = false;
                error  = 'Error al guardar: $e';
              });
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
                  // Título + botón cerrar
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pet == null ? 'Agregar mascota' : 'Editar mascota',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: saving
                            ? null
                            : () => Navigator.pop(ctx),
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
                            // Miniaturas existentes
                            ...images.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final url = entry.value;
                              return Container(
                                width: 80,
                                height: 80,
                                margin: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        url,
                                        width: 80, height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: const Color(0xFFF5F5F5),
                                          child: const Icon(Icons.broken_image,
                                              color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    // Badge "Principal"
                                    if (idx == 0)
                                      Positioned(
                                        bottom: 3,
                                        left: 3,
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
                                    // Botón eliminar
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Material(
                                        color: Colors.black54,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: saving
                                              ? null
                                              : () => setModal(
                                                    () => images.removeAt(idx),
                                                  ),
                                          child: const Padding(
                                            padding: EdgeInsets.all(3),
                                            child: Icon(Icons.close,
                                                color: Colors.white, size: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            // Indicador de carga
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
                            // Botón agregar
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
                                                .uploadBinary(
                                                  fileName,
                                                  bytes,
                                                  fileOptions: FileOptions(
                                                      contentType:
                                                          'image/$ext',
                                                      upsert: true),
                                                );
                                            final url = Supabase
                                                .instance.client.storage
                                                .from('pet-images')
                                                .getPublicUrl(fileName);
                                            setModal(() {
                                              images.add(url);
                                              uploading = false;
                                            });
                                          } catch (e) {
                                            setModal(
                                                () => uploading = false);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          'Error al subir foto: $e')));
                                            }
                                          }
                                        },
                                  child: const SizedBox(
                                    width: 80,
                                    height: 80,
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

                  // ── Nombre ──────────────────────────────
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        hintText: 'Nombre *',
                        prefixIcon: Icon(Icons.pets)),
                  ),
                  const SizedBox(height: 10),

                  // ── Especie ──────────────────────────────
                  Row(
                    children: ['dog', 'cat', 'other'].map((s) {
                      final selected = species == s;
                      final label = s == 'dog'
                          ? 'Perro'
                          : s == 'cat' ? 'Gato' : 'Otro';
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _SelectBtn(
                            label: label,
                            selected: selected,
                            selectedColor: const Color(0xFFFF6B35),
                            onTap: saving ? null : () => setModal(() => species = s),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // ── Género ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _SelectBtn(
                          label: 'Macho',
                          selected: gender == 'male',
                          selectedColor: const Color(0xFF2196F3),
                          onTap: saving ? null : () => setModal(() => gender = 'male'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SelectBtn(
                          label: 'Hembra',
                          selected: gender == 'female',
                          selectedColor: const Color(0xFFE91E8C),
                          onTap: saving ? null : () => setModal(() => gender = 'female'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Raza y edad ──────────────────────────
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
                          decoration:
                              const InputDecoration(hintText: 'Edad (meses)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Descripción ──────────────────────────
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration:
                        const InputDecoration(hintText: 'Descripción'),
                  ),

                  // ── Error ────────────────────────────────
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.3)),
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

                  // ── Botón guardar ────────────────────────
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
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              pet == null ? 'Agregar mascota' : 'Guardar cambios',
                              style: const TextStyle(fontSize: 15),
                            ),
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

  Future<void> _toggleAdopted(Pet pet) async {
    try {
      await Supabase.instance.client
          .from('pets')
          .update({'is_adopted': !pet.isAdopted})
          .eq('id', pet.id);
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deletePet(Pet pet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar mascota'),
        content: Text('¿Eliminar a ${pet.name}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _petService.deletePet(pet.id);
        if (mounted) _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis mascotas'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showAdopted = !_showAdopted),
            icon: Icon(
              _showAdopted ? Icons.visibility : Icons.visibility_off,
              size: 18,
              color: AppTheme.secondary,
            ),
            label: Text(
              _showAdopted ? 'Todas' : 'Disponibles',
              style: const TextStyle(color: AppTheme.secondary, fontSize: 13),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPetDialog(),
        backgroundColor: const Color(0xFFFF6B35),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Agregar', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<List<Pet>>(
        future: _petsFuture,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 56, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Error al cargar mascotas',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('${snap.error}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          final allPets = snap.data ?? [];
          final pets = _showAdopted
              ? allPets
              : allPets.where((p) => !p.isAdopted).toList();
          if (pets.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aún no tienes mascotas registradas',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: pets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _PetManageCard(
              pet: pets[i],
              onEdit:          () => _showPetDialog(pet: pets[i]),
              onDelete:        () => _deletePet(pets[i]),
              onToggleAdopted: () => _toggleAdopted(pets[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PetManageCard extends StatelessWidget {
  final Pet pet;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleAdopted;

  const _PetManageCard({
    required this.pet,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAdopted,
  });

  @override
  Widget build(BuildContext context) {
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
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14)),
            child: SizedBox(
              width: 90,
              height: 90,
              child: pet.imageUrl != null
                  ? Image.network(pet.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(pet.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      if (pet.isAdopted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Adoptado',
                              style: TextStyle(
                                  color: AppTheme.secondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  Text('${pet.speciesEmoji} ${pet.breed ?? pet.species}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(pet.ageLabel,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  pet.isAdopted
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: pet.isAdopted
                      ? AppTheme.secondary
                      : Colors.grey,
                  size: 20,
                ),
                tooltip: pet.isAdopted
                    ? 'Marcar disponible'
                    : 'Marcar adoptado',
                onPressed: onToggleAdopted,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppTheme.primary, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
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
            child: Icon(Icons.pets, color: Colors.grey, size: 32)),
      );
}

// Botón de selección que usa InkWell en lugar de GestureDetector
// para evitar el error mouse_tracker en Flutter Web
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
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}