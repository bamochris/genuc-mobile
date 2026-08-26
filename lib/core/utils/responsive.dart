import 'package:flutter/material.dart';

/// Règles de mise en page adaptative du portail mobile.
///
/// Le portail web pose ses grilles en `repeat(auto-fit, minmax(Npx, 1fr))` et
/// centre son contenu sur `max-width: 1200px`. Flutter n'a pas d'équivalent
/// déclaratif : sans ces règles, les mêmes écrans s'étirent sur toute la
/// largeur d'une tablette ou d'une fenêtre de bureau (une carte de 900 px de
/// large pour trois mots), et les grilles à nombre de colonnes figé débordent
/// sur un téléphone étroit.
///
/// Les seuils reprennent ceux du frontend (`theme-premium.css`) :
/// 600 (téléphone large) · 900 (tablette) · 1200 (bureau).
class Responsive {
  Responsive._();

  static const double seuilTelephone = 600;
  static const double seuilTablette = 900;
  static const double seuilBureau = 1200;

  /// Largeur au-delà de laquelle le contenu est centré plutôt qu'étiré,
  /// comme le `max-width: 1200px` des pages web.
  static const double largeurContenuMax = 1100;

  static double largeur(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool estTelephone(BuildContext context) =>
      largeur(context) < seuilTelephone;

  static bool estTablette(BuildContext context) {
    final l = largeur(context);
    return l >= seuilTelephone && l < seuilBureau;
  }

  static bool estBureau(BuildContext context) => largeur(context) >= seuilBureau;

  /// Marge intérieure de page, croissante avec la largeur disponible.
  static EdgeInsets margePage(BuildContext context) {
    final l = largeur(context);
    if (l < seuilTelephone) return const EdgeInsets.all(16);
    if (l < seuilTablette) return const EdgeInsets.all(20);
    return const EdgeInsets.symmetric(horizontal: 28, vertical: 24);
  }

  /// Nombre de colonnes pour une grille dont chaque tuile veut au moins
  /// [largeurMinTuile] — transposition de `minmax(Npx, 1fr)`.
  ///
  /// [largeurDisponible] doit venir d'un `LayoutBuilder` quand la grille n'est
  /// pas pleine largeur (colonne d'un écran scindé) ; sinon la largeur de
  /// l'écran suffit.
  static int colonnes(
    BuildContext context, {
    required double largeurMinTuile,
    double? largeurDisponible,
    int maxColonnes = 4,
  }) {
    final dispo = largeurDisponible ??
        (largeur(context) - margePage(context).horizontal)
            .clamp(0.0, largeurContenuMax);
    if (dispo <= 0) return 1;
    final n = (dispo / largeurMinTuile).floor();
    return n.clamp(1, maxColonnes);
  }

  /// Facteur d'échelle du texte plafonné : au-delà de 1,4 les cartes du
  /// portail tronquent leurs libellés (réglage d'accessibilité poussé au
  /// maximum sur Android).
  static double echelleTextePlafonnee(BuildContext context) {
    final echelle = MediaQuery.textScalerOf(context).scale(1.0);
    return echelle.clamp(1.0, 1.4);
  }
}

/// Centre son enfant et lui impose une largeur maximale sur grand écran.
///
/// Équivalent du `max-width: 1200px; margin: 0 auto` que porte chaque page du
/// portail web.
class ContenuCentre extends StatelessWidget {
  final Widget child;
  final double largeurMax;

  const ContenuCentre({
    super.key,
    required this.child,
    this.largeurMax = Responsive.largeurContenuMax,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largeurMax),
        child: child,
      ),
    );
  }
}

/// Grille dont le nombre de colonnes se déduit de la largeur réelle, comme
/// `repeat(auto-fit, minmax(...))`.
///
/// Utilise `shrinkWrap` + `NeverScrollableScrollPhysics` : ces grilles vivent
/// à l'intérieur d'une page qui défile déjà.
class GrilleAdaptative extends StatelessWidget {
  final List<Widget> enfants;
  final double largeurMinTuile;
  final double ratio;
  final double espacement;
  final int maxColonnes;

  const GrilleAdaptative({
    super.key,
    required this.enfants,
    this.largeurMinTuile = 180,
    this.ratio = 1.6,
    this.espacement = 12,
    this.maxColonnes = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (enfants.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, contraintes) {
        final nb = Responsive.colonnes(
          context,
          largeurMinTuile: largeurMinTuile,
          largeurDisponible: contraintes.maxWidth,
          maxColonnes: maxColonnes,
        );
        // Le ratio est corrigé par l'échelle du texte : à 140 %, une tuile
        // calculée pour 100 % rogne sa dernière ligne.
        final ratioCorrige = ratio / Responsive.echelleTextePlafonnee(context);

        return GridView.count(
          crossAxisCount: nb,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: espacement,
          mainAxisSpacing: espacement,
          childAspectRatio: ratioCorrige,
          children: enfants,
        );
      },
    );
  }
}

/// Dispose ses enfants en ligne quand la largeur le permet, en colonne sinon.
///
/// Remplace les `Row` figées qui débordaient sur téléphone étroit (barres de
/// filtres, en-têtes titre + action).
class LigneOuColonne extends StatelessWidget {
  final List<Widget> enfants;
  final double seuil;
  final double espacement;
  final CrossAxisAlignment alignementColonne;

  const LigneOuColonne({
    super.key,
    required this.enfants,
    this.seuil = Responsive.seuilTelephone,
    this.espacement = 12,
    this.alignementColonne = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        if (contraintes.maxWidth >= seuil) {
          return Row(
            children: [
              for (var i = 0; i < enfants.length; i++) ...[
                if (i > 0) SizedBox(width: espacement),
                Expanded(child: enfants[i]),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: alignementColonne,
          children: [
            for (var i = 0; i < enfants.length; i++) ...[
              if (i > 0) SizedBox(height: espacement),
              enfants[i],
            ],
          ],
        );
      },
    );
  }
}
