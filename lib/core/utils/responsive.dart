// lib/core/utils/responsive.dart

import 'package:flutter/widgets.dart';

/// Breakpoints y helpers de layout responsivo.
///
/// Breakpoints:
///   mobile  < 720 px
///   tablet  720 – 1099 px
///   desktop ≥ 1100 px
class R {
  R._();

  static const double _wide    = 720;
  static const double _desktop = 1100;

  /// Ancho máximo del contenido principal (centrado en pantallas muy anchas).
  static const double maxContent = 1200.0;

  /// Ancho máximo para formularios (login, solicitudes, etc.).
  static const double maxForm = 520.0;

  // ── Detección ──────────────────────────────────────────────────
  static double width(BuildContext ctx)   => MediaQuery.sizeOf(ctx).width;
  static bool isMobile(BuildContext ctx)  => width(ctx) < _wide;
  static bool isWide(BuildContext ctx)    => width(ctx) >= _wide;
  static bool isDesktop(BuildContext ctx) => width(ctx) >= _desktop;

  // ── Columnas del grid de mascotas ──────────────────────────────
  static int petCols(BuildContext ctx) {
    final w = width(ctx);
    if (w >= 1400) return 5;
    if (w >= 1100) return 4;
    if (w >= 800)  return 3;
    if (w >= 580)  return 3;
    return 2;
  }

  // ── Columnas del grid de refugios ──────────────────────────────
  static int shelterCols(BuildContext ctx) {
    final w = width(ctx);
    if (w >= 1100) return 3;
    if (w >= 720)  return 2;
    return 1;
  }

  // ── Columnas del menú de Inicio ────────────────────────────────
  static int homeCols(BuildContext ctx) => isWide(ctx) ? 4 : 2;

  // ── Wrapper que centra y limita el ancho ───────────────────────
  static Widget constrain(Widget child, {double maxWidth = maxContent}) =>
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
