import 'package:flutter/material.dart';
import 'farm_themes.dart';

/// Shared farm-material widgets and text styles.
///
/// Physical-material look: wooden frames, soil plots with inner shadow,
/// grass backdrop. No neon, no gradients-heavy glass — just warm farm craft.
class Farm {
  static TextStyle display(double size, {required FarmThemeDef theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: theme.text,
        letterSpacing: 0.5,
      );

  static TextStyle title(double size, {required FarmThemeDef theme}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: theme.text,
      );

  static TextStyle body(double size, {required FarmThemeDef theme}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: theme.text,
      );

  static TextStyle muted(double size, {required FarmThemeDef theme}) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w500, color: theme.muted);
}

/// A wooden-framed card: deep wood border, cream surface, soft drop shadow.
class WoodCard extends StatelessWidget {
  final FarmThemeDef theme;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const WoodCard({
    super.key,
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.wood,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: theme.woodDeep.withValues(alpha: 0.55),
            offset: const Offset(0, 5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(radius - 6),
          border: Border.all(
            color: theme.woodLight.withValues(alpha: 0.7),
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A soil plot cell: tilled earth with inner top shadow (concave),
/// the physical bed every crop sits in.
class PlotCell extends StatelessWidget {
  final FarmThemeDef theme;
  final Widget? child;
  final bool selected;
  final double radius;

  const PlotCell({
    super.key,
    required this.theme,
    this.child,
    this.selected = false,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        // Tilled soil: darker rim, lighter center — reads as a dug plot.
        border: Border.all(
          color: selected ? theme.gold : theme.soilDark,
          width: selected ? 3 : 2,
        ),
        boxShadow: [
          // inner-shadow illusion: light rim below, dark above
          BoxShadow(
            color: theme.soilDark.withValues(alpha: 0.85),
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
          if (selected)
            BoxShadow(
              color: theme.gold.withValues(alpha: 0.55),
              offset: const Offset(0, 0),
              blurRadius: 10,
            ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.soilDark, theme.soilLight],
        ),
      ),
      child: child,
    );
  }
}

/// A chunky farm button: wooden plank with cream label.
class FarmButton extends StatelessWidget {
  final FarmThemeDef theme;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final double fontSize;

  const FarmButton({
    super.key,
    required this.theme,
    required this.label,
    required this.onTap,
    this.primary = true,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: primary ? theme.wood : theme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primary ? theme.woodDeep : theme.wood,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.woodDeep.withValues(alpha: 0.5),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: primary ? theme.surface : theme.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small stat chip (coins, level, …): cream pill on wood.
class FarmChip extends StatelessWidget {
  final FarmThemeDef theme;
  final String text;

  const FarmChip({super.key, required this.theme, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.wood, width: 2),
        boxShadow: [
          BoxShadow(
            color: theme.woodDeep.withValues(alpha: 0.35),
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.text,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}
