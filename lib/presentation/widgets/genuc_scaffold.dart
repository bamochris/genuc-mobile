import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Scaffold posé sur le fond de marque GENUC.
///
/// Transpose la règle du portail web (`body::before` en couche fixe, surfaces
/// par-dessus en transparent ou translucide) : les mêmes visuels
/// `bg-universites-*.svg` sont utilisés, en version claire ou sombre selon le
/// thème. Tout écran de l'application doit passer par ici plutôt que par un
/// `Scaffold` nu, sans quoi l'identité visuelle s'arrête à la connexion.
class GenucScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  const GenucScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.drawer,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: BrandBackground()),
        Scaffold(
          // Transparent : laisse voir le fond de marque.
          backgroundColor: Colors.transparent,
          appBar: appBar,
          drawer: drawer,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
          body: body,
        ),
      ],
    );
  }
}

class BrandBackground extends StatelessWidget {
  const BrandBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final estSombre = Theme.of(context).brightness == Brightness.dark;
    final asset = estSombre
        ? 'assets/background/bg-universites-dark.svg'
        : 'assets/background/bg-universites-clair.svg';

    return SvgPicture.asset(
      asset,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      // Couleur tenue pendant le décodage du SVG, pour éviter un flash blanc
      // au lancement en mode sombre.
      placeholderBuilder: (_) => ColoredBox(
        color: estSombre ? const Color(0xFF0f172a) : const Color(0xFFf2ede4),
        child: const SizedBox.expand(),
      ),
    );
  }
}
