import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mesure de lisibilité sur l'arbre réellement monté.
///
/// <h3>Pourquoi mesurer plutôt que relire le code</h3>
///
/// Une couleur illisible en thème sombre ne lève aucune erreur : le texte est
/// peint, simplement invisible. Et la relecture du code ne suffit pas — la
/// couleur d'un `Text` vient de son style, ou du `DefaultTextStyle`, ou du
/// thème ; celle du fond vient du `Scaffold`, d'un `Material`, d'un
/// `BoxDecoration` posé trois widgets plus haut. Seul l'arbre monté sait ce qui
/// se retrouve effectivement l'un sur l'autre.
///
/// On applique donc la formule de contraste du WCAG à ce que l'utilisateur voit :
/// la couleur composée du premier plan sur celle du fond opaque le plus proche.
class AuditContraste {
  /// Seuil du TEXTE : 4,5:1 — le niveau AA du WCAG pour le texte courant.
  ///
  /// Il valait 3,0:1 à l'origine, pour ne signaler que l'invisible. C'était
  /// suffisant tant qu'on cherchait les fautes grossières, mais trop laxiste
  /// pour ce qu'on veut garantir désormais : le bleu d'accent `#185FA5` passe
  /// à 2,3:1 sur l'ardoise et le rouge `#B91C1C` à 2,4:1 — tous deux
  /// signalés —, tandis que le bleu `#0d6efd` s'en tirait à 3,4:1 sans être
  /// pour autant confortable à lire. Le seuil AA tranche sans discussion.
  static const double seuilTexte = 4.5;

  /// Seuil des ICÔNES et éléments graphiques : 3,0:1, le minimum AA pour un
  /// objet non textuel. Une icône est une forme pleine de 16 à 64 pixels : la
  /// juger au seuil du corps de texte condamnerait des teintes parfaitement
  /// identifiables, et noierait les vrais défauts sous le bruit.
  static const double seuilIcone = 3.0;

  /// Audit de l'arbre actuellement monté.
  static RapportContraste auditer(WidgetTester tester) {
    final defauts = <DefautContraste>[];
    var examines = 0;

    for (final element in tester.allElements) {
      final widget = element.widget;

      if (widget is Text) {
        final texte = widget.data;
        if (texte == null || texte.trim().isEmpty) continue;
        final style = DefaultTextStyle.of(element).style.merge(widget.style);
        final premierPlan = style.color;
        if (premierPlan == null) continue;
        if (_examiner(defauts, element, premierPlan, 'texte « $texte »',
            seuilTexte)) {
          examines++;
        }
      }

      if (widget is Icon) {
        final premierPlan = widget.color ?? IconTheme.of(element).color;
        if (premierPlan == null) continue;
        if (_examiner(defauts, element, premierPlan, 'icône ${widget.icon}',
            seuilIcone)) {
          examines++;
        }
      }
    }
    // Dédoublonné : une couleur fautive dans une liste de vingt lignes est UN
    // défaut à corriger, pas vingt.
    final uniques = {for (final d in defauts) d.cle: d}.values.toList()
      ..sort((a, b) => a.rapport.compareTo(b.rapport));
    return RapportContraste(defauts: uniques, examines: examines);
  }

  /// @return `true` si l'élément a pu être MESURÉ — c'est ce compte qui dit si
  ///         l'audit a fait son travail ou s'il est passé à côté de tout.
  static bool _examiner(List<DefautContraste> defauts, Element element,
      Color premierPlan, String quoi, double seuil) {
    // Un élément entièrement transparent n'est pas un défaut de contraste :
    // c'est une animation en cours, ou un widget délibérément masqué.
    if (premierPlan.a == 0) return false;
    // Ni un contrôle désactivé : Material l'atténue EXPRÈS, c'est ainsi qu'il
    // dit « indisponible ». Le signaler ferait passer pour un défaut le seul
    // endroit où le faible contraste porte du sens.
    if (_attenueVolontairement(element)) return false;

    final fond = _fondDerriere(element);
    if (fond == null) return false;

    final rapport = contraste(_composer(premierPlan, fond), fond);
    if (rapport < seuil) {
      defauts.add(DefautContraste(
        quoi: quoi,
        premierPlan: premierPlan,
        fond: fond,
        rapport: rapport,
        seuil: seuil,
        chemin: _cheminEcran(element),
        ancetres: _traceAncetres(element),
      ));
    }
    return true;
  }

  /// Un ancêtre atténue-t-il délibérément cet élément ?
  static bool _attenueVolontairement(Element element) {
    var attenue = false;
    element.visitAncestorElements((ancetre) {
      final widget = ancetre.widget;
      if (widget is ButtonStyleButton && !widget.enabled) {
        attenue = true;
        return false;
      }
      if (widget is IconButton && widget.onPressed == null) {
        attenue = true;
        return false;
      }
      if (widget is Opacity && widget.opacity < 1.0) {
        attenue = true;
        return false;
      }
      // `DropdownButton` est générique et n'a aucun supertype non générique :
      // un `is` demanderait de connaître son paramètre de type. On le
      // reconnaît donc par son nom — sa flèche désactivée est peinte à dix
      // pour cent, ce qui est l'intention de Material et non un défaut.
      if (widget.runtimeType.toString().startsWith('DropdownButton') &&
          _estDesactive(widget)) {
        attenue = true;
        return false;
      }
      return true;
    });
    return attenue;
  }

  /// Les widgets « intéressants » au-dessus de l'élément fautif.
  ///
  /// Sans cette trace, un rapport comme « icône U+0E098 illisible » n'aide
  /// personne : il faut ouvrir l'écran et deviner de quel widget il s'agit. La
  /// chaîne le nomme.
  static String _traceAncetres(Element element) {
    final noms = <String>[];
    element.visitAncestorElements((ancetre) {
      final nom = ancetre.widget.runtimeType.toString();
      // On écarte la plomberie de Flutter, qui noierait le signal.
      const bruit = {
        'Padding', 'Center', 'Align', 'SizedBox', 'Expanded', 'Flexible',
        'Column', 'Row', 'Stack', 'Positioned', 'Container', 'DecoratedBox',
        'ConstrainedBox', 'LimitedBox', 'RepaintBoundary', 'Semantics',
        'MediaQuery', 'Builder', 'DefaultTextStyle', 'IconTheme', 'Directionality',
      };
      if (!bruit.contains(nom) && !nom.startsWith('_') && !noms.contains(nom)) {
        noms.add(nom);
      }
      return noms.length < 8;
    });
    return noms.join(' < ');
  }

  /// Un dropdown que Flutter tient pour désactivé.
  ///
  /// Deux conditions, et la seconde est celle qui compte ici : un dropdown
  /// **sans options** est désactivé tout autant qu'un dropdown sans
  /// `onChanged`. C'est le cas de tous les sélecteurs de cet audit, dont les
  /// listes viennent du serveur et restent vides réseau coupé — leur flèche
  /// grisée est un artefact du test, pas un défaut de l'application.
  static bool _estDesactive(Widget widget) {
    try {
      final dynamique = widget as dynamic;
      if (dynamique.onChanged == null) return true;
      final items = dynamique.items;
      return items == null || (items as List).isEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Premier fond OPAQUE au-dessus de [element], les couches translucides
  /// rencontrées en chemin étant composées dessus.
  static Color? _fondDerriere(Element element) {
    final couches = <Color>[];
    Color? opaque;

    element.visitAncestorElements((ancetre) {
      final couleur = _couleurDeFond(ancetre.widget);
      if (couleur == null || couleur.a == 0) return true;
      if (couleur.a >= 1.0) {
        opaque = couleur;
        return false; // inutile de remonter plus haut
      }
      couches.add(couleur);
      return true;
    });

    // Aucun fond opaque au-dessus : c'est le cas NORMAL des écrans bâtis sur
    // le fond de marque, dont toutes les surfaces sont translucides. Le fond
    // ultime est alors celui du `Scaffold`, qui peint toujours quelque chose.
    //
    // Sans ce repli, l'audit abandonnait ces écrans en silence et les rendait
    // « sans défaut » — sept d'entre eux passaient ainsi au vert sans qu'une
    // seule couleur ait été mesurée.
    opaque ??= Theme.of(element).scaffoldBackgroundColor;
    if (opaque!.a < 1.0) return null;
    // De la couche la plus haute vers la plus basse : chacune se pose sur le
    // résultat des précédentes, exactement comme au rendu.
    Color resultat = opaque!;
    for (final couche in couches.reversed) {
      resultat = _composer(couche, resultat);
    }
    return resultat;
  }

  static Color? _couleurDeFond(Widget widget) {
    if (widget is ColoredBox) return widget.color;
    if (widget is Material) return widget.color;
    if (widget is Card) return widget.color;
    if (widget is Container && widget.color != null) return widget.color;
    if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) {
        // Un dégradé n'a pas UNE couleur : on retient la plus sombre de ses
        // arrêts, c'est-à-dire le pire cas pour un premier plan clair.
        final gradient = decoration.gradient;
        if (gradient is LinearGradient && gradient.colors.isNotEmpty) {
          return gradient.colors.reduce(
              (a, b) => _luminance(a) <= _luminance(b) ? a : b);
        }
        return decoration.color;
      }
    }
    return null;
  }

  /// Nom de l'écran qui porte cet élément — de quoi retrouver le défaut.
  static String _cheminEcran(Element element) {
    String? ecran;
    element.visitAncestorElements((ancetre) {
      final nom = ancetre.widget.runtimeType.toString();
      if (nom.endsWith('Screen') || nom.endsWith('Shell')) {
        ecran = nom;
        return false;
      }
      return true;
    });
    return ecran ?? 'écran inconnu';
  }

  /// [dessus] posé sur [dessous], en tenant compte de l'alpha.
  static Color _composer(Color dessus, Color dessous) {
    final a = dessus.a;
    if (a >= 1.0) return dessus;
    return Color.from(
      alpha: 1.0,
      red: dessus.r * a + dessous.r * (1 - a),
      green: dessus.g * a + dessous.g * (1 - a),
      blue: dessus.b * a + dessous.b * (1 - a),
    );
  }

  /// Rapport de contraste WCAG 2.1 — de 1,0 (identiques) à 21,0 (noir/blanc).
  static double contraste(Color a, Color b) {
    final la = _luminance(a);
    final lb = _luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  static double _luminance(Color c) => Color.from(
        alpha: 1.0, red: c.r, green: c.g, blue: c.b,
      ).computeLuminance();
}

class DefautContraste {
  final String quoi;
  final Color premierPlan;
  final Color fond;
  final double rapport;

  /// Le seuil que ce défaut n'atteint pas — 4,5 pour du texte, 3,0 pour une
  /// icône. Sans lui, deux lignes du rapport à « 3,20:1 » sembleraient
  /// contradictoires, l'une signalée et l'autre non.
  final double seuil;
  final String chemin;
  final String ancetres;

  const DefautContraste({
    required this.quoi,
    required this.premierPlan,
    required this.fond,
    required this.rapport,
    required this.seuil,
    required this.chemin,
    this.ancetres = '',
  });

  /// Identité d'un défaut, pour ne le compter qu'une fois par écran même si le
  /// widget est reconstruit ou répété dans une liste.
  String get cle => '$chemin|$quoi|${_hex(premierPlan)}|${_hex(fond)}';

  @override
  String toString() {
    final base = '$chemin — $quoi : ${_hex(premierPlan)} sur ${_hex(fond)} '
        '(contraste ${rapport.toStringAsFixed(2)}:1, '
        'exigé ${seuil.toStringAsFixed(1)}:1)';
    if (ancetres.isEmpty) return base;
    return '$base\n      dans $ancetres';
  }

  static String _hex(Color c) {
    String deux(double v) =>
        (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final hexa = '#${deux(c.r)}${deux(c.g)}${deux(c.b)}'.toUpperCase();
    // L'alpha est DIT, sans quoi « #FFFFFF à 1,37:1 » passe pour une erreur de
    // calcul alors que c'est un blanc à six pour cent.
    return c.a >= 1.0 ? hexa : '$hexa à ${(c.a * 100).round()} %';
  }
}

/// Ce que l'audit a trouvé, ET ce qu'il a pu regarder.
///
/// [examines] n'est pas une statistique : c'est la garantie que le résultat
/// veut dire quelque chose. Un audit qui ne mesure rien rend « aucun défaut »,
/// exactement comme un audit qui passe — et le test resterait vert en ne
/// protégeant plus rien. On l'exige donc non nul.
class RapportContraste {
  final List<DefautContraste> defauts;
  final int examines;

  const RapportContraste({required this.defauts, required this.examines});
}
