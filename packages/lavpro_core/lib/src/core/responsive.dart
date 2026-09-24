import 'package:flutter/widgets.dart';

/// Points de rupture pour adapter l'interface à toutes les tailles d'écran.
class Breakpoints {
  static const tablet = 700.0;
  static const desktop = 1100.0;
}

extension ResponsiveX on BuildContext {
  double get width => MediaQuery.sizeOf(this).width;
  bool get isTablet => width >= Breakpoints.tablet;
  bool get isDesktop => width >= Breakpoints.desktop;

  /// Nombre de colonnes conseillé pour une grille de cartes.
  int columns({double minTileWidth = 320}) => (width / minTileWidth).floor().clamp(1, 4);

  double get pagePadding => isTablet ? 28 : 20;
}

/// Centre le contenu et limite sa largeur sur les grands écrans.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.maxWidth = 1100});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}
