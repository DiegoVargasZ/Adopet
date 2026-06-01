// lib/presentation/widgets/app_shell.dart
//
// Shell responsivo:
//   ≥ 720 px → NavigationRail compacto en la izquierda
//   ≥ 1100 px → NavigationRail extendido (con texto)
//   < 720 px  → NavigationBar en la parte inferior

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final String location;

  const AppShell({
    super.key,
    required this.child,
    required this.location,
  });

  // ── Destinos de navegación ─────────────────────────────────────
  static const _items = [
    _NavItem('/home',     Icons.home_outlined,      Icons.home,         'Inicio'),
    _NavItem('/pets',     Icons.pets_outlined,       Icons.pets,         'Mascotas'),
    _NavItem('/shelters', Icons.home_work_outlined,  Icons.home_work,    'Refugios'),
    _NavItem('/map',      Icons.map_outlined,        Icons.map,          'Mapa'),
    _NavItem('/chats',    Icons.chat_bubble_outline, Icons.chat_bubble,  'Mensajes'),
  ];

  int get _selectedIndex {
    for (var i = 0; i < _items.length; i++) {
      final path = _items[i].path;
      if (location == path || location.startsWith('$path/')) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.sizeOf(context).width;
    final isWide   = w >= 720;
    final extended = w >= 1100;
    final idx      = _selectedIndex;

    if (isWide) {
      // ── Desktop / Tablet ──────────────────────────────────────
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended:      extended,
              selectedIndex: idx,
              onDestinationSelected: (i) => context.go(_items[i].path),
              backgroundColor: AppTheme.bg,
              indicatorColor: AppTheme.primary.withOpacity(0.13),
              selectedIconTheme: const IconThemeData(color: AppTheme.primary),
              unselectedIconTheme: const IconThemeData(
                  color: AppTheme.textSub, size: 22),
              selectedLabelTextStyle: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: AppTheme.textSub,
                fontSize: 12,
              ),
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              // Logo como leading del rail
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                child: extended
                    ? Row(
                        children: const [
                          SizedBox(width: 8),
                          Icon(Icons.pets, color: AppTheme.primary, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'AdoptaPet',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMain,
                              fontSize: 16,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      )
                    : const Icon(Icons.pets,
                        color: AppTheme.primary, size: 24),
              ),
              destinations: _items
                  .map((n) => NavigationRailDestination(
                        icon:         Icon(n.icon),
                        selectedIcon: Icon(n.selectedIcon),
                        label:        Text(n.label),
                      ))
                  .toList(),
            ),
            VerticalDivider(
                width: 1, thickness: 1, color: AppTheme.border),
            Expanded(child: child),
          ],
        ),
      );
    }

    // ── Móvil ─────────────────────────────────────────────────────
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_items[i].path),
        backgroundColor:    AppTheme.bg,
        surfaceTintColor:   Colors.transparent,
        indicatorColor:     AppTheme.primary.withOpacity(0.13),
        height:             60,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _items
            .map((n) => NavigationDestination(
                  icon:         Icon(n.icon, size: 22),
                  selectedIcon: Icon(n.selectedIcon,
                      size: 22, color: AppTheme.primary),
                  label: n.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final String   path;
  final IconData icon;
  final IconData selectedIcon;
  final String   label;

  const _NavItem(this.path, this.icon, this.selectedIcon, this.label);
}
