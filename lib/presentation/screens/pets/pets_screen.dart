// lib/presentation/screens/pets/pets_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/pet_filter_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/pet.dart';
import '../../../data/models/pet_filter.dart';
import '../../../data/services/pet_service.dart';
import '../../widgets/pet_card.dart';

class PetsScreen extends ConsumerStatefulWidget {
  const PetsScreen({super.key});
  @override
  ConsumerState<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends ConsumerState<PetsScreen> {
  final _petService  = PetService();
  final _searchCtrl  = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _search = '';
  late Future<List<Pet>> _petsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() {
    final filter = ref.read(petFilterProvider);
    setState(() {
      _petsFuture = _petService.getPets(filter: filter, search: _search);
    });
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value);
    _load();
  }

  void _openFilters() => _scaffoldKey.currentState?.openEndDrawer();

  @override
  Widget build(BuildContext context) {
    final filter  = ref.watch(petFilterProvider);
    final isWide  = R.isWide(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Mascotas en adopción'),
        actions: [
          // Botón de filtros solo en móvil (en desktop el panel es visible)
          if (!isWide)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: _openFilters,
                  tooltip: 'Filtros',
                ),
                if (filter.activeCount > 0)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary, shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${filter.activeCount}',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),

      // Drawer de filtros (solo en móvil)
      endDrawer: isWide
          ? null
          : _FilterDrawer(onApply: () { Navigator.pop(context); _load(); }),

      body: isWide
          ? _desktopBody(context, filter)
          : _mobileBody(context, filter),
    );
  }

  // ── Layout desktop: sidebar de filtros + grid ─────────────────
  Widget _desktopBody(BuildContext context, PetFilter filter) {
    return Row(
      children: [
        // Panel de filtros fijo
        Container(
          width: 240,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: AppTheme.border, width: 1),
            ),
          ),
          child: _FilterPanel(
            onApply: _load,
            showApplyButton: true,
          ),
        ),
        // Contenido principal
        Expanded(
          child: Column(
            children: [
              _searchBar(filter),
              _activeChips(filter),
              const SizedBox(height: 4),
              Expanded(child: _petGrid()),
            ],
          ),
        ),
      ],
    );
  }

  // ── Layout móvil: barra de búsqueda + chips + grid ────────────
  Widget _mobileBody(BuildContext context, PetFilter filter) {
    return Column(
      children: [
        _searchBar(filter),
        _activeChips(filter),
        const SizedBox(height: 4),
        Expanded(child: _petGrid()),
      ],
    );
  }

  Widget _searchBar(PetFilter filter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Buscar por nombre...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _activeChips(PetFilter filter) {
    if (filter.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: [
          if (filter.species != null)
            _ActiveChip(
              label: _speciesLabel(filter.species!),
              onRemove: () {
                ref.read(petFilterProvider.notifier).setSpecies(null);
                _load();
              },
            ),
          if (filter.gender != null)
            _ActiveChip(
              label: _genderLabel(filter.gender!),
              onRemove: () {
                ref.read(petFilterProvider.notifier).setGender(null);
                _load();
              },
            ),
          if (filter.ageRange != null)
            _ActiveChip(
              label: _ageLabel(filter.ageRange!),
              onRemove: () {
                ref.read(petFilterProvider.notifier).setAgeRange(null);
                _load();
              },
            ),
          TextButton(
            onPressed: () {
              ref.read(petFilterProvider.notifier).clearAll();
              _load();
            },
            child: const Text(
              'Limpiar todo',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _petGrid() {
    return FutureBuilder<List<Pet>>(
      future: _petsFuture,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final pets   = snap.data ?? [];
        final filter = ref.read(petFilterProvider);

        if (pets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('Sin resultados',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  filter.isEmpty && _search.isEmpty
                      ? 'No hay mascotas disponibles'
                      : 'Prueba con otros filtros',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (!filter.isEmpty || _search.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(petFilterProvider.notifier).clearAll();
                      _searchCtrl.clear();
                      setState(() => _search = '');
                      _load();
                    },
                    icon:  const Icon(Icons.refresh),
                    label: const Text('Limpiar filtros'),
                  ),
                ],
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   R.petCols(context),
            childAspectRatio: 0.72,
            crossAxisSpacing: 12,
            mainAxisSpacing:  12,
          ),
          itemCount: pets.length,
          itemBuilder: (_, i) => PetCard(
            pet: pets[i],
            onTap: () => context.push('/pets/detail', extra: pets[i]),
          ),
        );
      },
    );
  }

  String _speciesLabel(String s) =>
      s == 'dog' ? 'Perro' : s == 'cat' ? 'Gato' : 'Otro';
  String _genderLabel(String g) => g == 'male' ? 'Macho' : 'Hembra';
  String _ageLabel(String a) =>
      a == 'cachorro' ? 'Cachorro' : a == 'joven' ? 'Joven' : 'Adulto';
}

// ── Panel de filtros (sidebar en desktop, drawer en móvil) ────────

class _FilterPanel extends ConsumerWidget {
  final VoidCallback onApply;
  final bool showApplyButton;

  const _FilterPanel({
    required this.onApply,
    this.showApplyButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter   = ref.watch(petFilterProvider);
    final notifier = ref.read(petFilterProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
          child: Row(
            children: [
              const Icon(Icons.tune, color: AppTheme.primary),
              const SizedBox(width: 10),
              const Text('Filtros',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (!filter.isEmpty)
                TextButton(
                  onPressed: () {
                    notifier.clearAll();
                    onApply();
                  },
                  child: const Text('Limpiar',
                      style: TextStyle(color: Colors.grey)),
                ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FilterSection(
                  title: 'Especie',
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _FilterOption(
                        label: 'Perro',
                        selected: filter.species == 'dog',
                        onTap: () {
                          notifier.setSpecies(
                              filter.species == 'dog' ? null : 'dog');
                          onApply();
                        },
                      ),
                      _FilterOption(
                        label: 'Gato',
                        selected: filter.species == 'cat',
                        onTap: () {
                          notifier.setSpecies(
                              filter.species == 'cat' ? null : 'cat');
                          onApply();
                        },
                      ),
                      _FilterOption(
                        label: 'Otro',
                        selected: filter.species == 'other',
                        onTap: () {
                          notifier.setSpecies(
                              filter.species == 'other' ? null : 'other');
                          onApply();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _FilterSection(
                  title: 'Género',
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _FilterOption(
                        label: 'Macho',
                        selected: filter.gender == 'male',
                        color: const Color(0xFF2196F3),
                        onTap: () {
                          notifier.setGender(
                              filter.gender == 'male' ? null : 'male');
                          onApply();
                        },
                      ),
                      _FilterOption(
                        label: 'Hembra',
                        selected: filter.gender == 'female',
                        color: const Color(0xFFE91E8C),
                        onTap: () {
                          notifier.setGender(
                              filter.gender == 'female' ? null : 'female');
                          onApply();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _FilterSection(
                  title: 'Edad',
                  subtitle: 'Cachorro < 1 año · Joven 1–3 · Adulto > 3',
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _FilterOption(
                        label: 'Cachorro',
                        selected: filter.ageRange == 'cachorro',
                        onTap: () {
                          notifier.setAgeRange(
                              filter.ageRange == 'cachorro' ? null : 'cachorro');
                          onApply();
                        },
                      ),
                      _FilterOption(
                        label: 'Joven',
                        selected: filter.ageRange == 'joven',
                        onTap: () {
                          notifier.setAgeRange(
                              filter.ageRange == 'joven' ? null : 'joven');
                          onApply();
                        },
                      ),
                      _FilterOption(
                        label: 'Adulto',
                        selected: filter.ageRange == 'adulto',
                        onTap: () {
                          notifier.setAgeRange(
                              filter.ageRange == 'adulto' ? null : 'adulto');
                          onApply();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showApplyButton)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: onApply,
              icon:  const Icon(Icons.check),
              label: Text(
                filter.isEmpty
                    ? 'Ver todas'
                    : 'Aplicar ${filter.activeCount} filtro${filter.activeCount > 1 ? "s" : ""}',
              ),
            ),
          ),
      ],
    );
  }
}

// Drawer de filtros para móvil
class _FilterDrawer extends ConsumerWidget {
  final VoidCallback onApply;
  const _FilterDrawer({required this.onApply});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      child: SafeArea(
        child: _FilterPanel(onApply: onApply),
      ),
    );
  }
}

// ── Widgets de filtros ────────────────────────────────────────────

class _FilterSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _FilterSection({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterOption({
    required this.label,
    required this.selected,
    this.color = AppTheme.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 16, color: AppTheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
