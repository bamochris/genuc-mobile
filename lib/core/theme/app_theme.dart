import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF0B1F4A);
  static const Color primaryLight = Color(0xFF1a3a7a);
  static const Color primaryDark = Color(0xFF06132b);
  static const Color secondary = Color(0xFF1D9E75);
  static const Color secondaryLight = Color(0xFF4bc49a);
  static const Color secondaryDark = Color(0xFF0F6E56);
  static const Color accent = Color(0xFF185FA5);
  static const Color accentLight = Color(0xFF4a8fc7);
  static const Color accentDark = Color(0xFF0f4590);
  static const Color background = Color(0xFFffffff);
  static const Color surface = Color(0xFFffffff);
  static const Color error = Color(0xFFdc3545);
  static const Color success = Color(0xFF1D9E75);
  static const Color info = Color(0xFF0d6efd);
  static const Color warning = Color(0xFFf59e0b);
  static const Color textPrimary = Color(0xFF0B1F4A);
  static const Color textSecondary = Color(0xFF555555);
  static const Color textLight = Color(0xFF6b7280);
  static const Color textMuted = Color(0xFF9FB8E0);
  static const Color border = Color(0xFFe0e0e0);
  static const Color inputBackground = Color(0xFFfafbfc);
  static const Color errorBg = Color(0xFFfff0f0);
  static const Color errorBorder = Color(0xFFffcccc);
  static const Color errorText = Color(0xFFcc0000);

  // ─── Surfaces posées sur le fond de marque ───
  // Équivalent des surfaces translucides du portail web : le visuel de fond
  // transparaît sans nuire à la lisibilité du contenu.
  static const Color glassLight = Color(0xDBFFFFFF); // blanc 86 %
  static const Color glassDark = Color(0xDB1E293B); // ardoise 86 %
  static const Color borderDark = Color(0xFF334155);

  // ─── Texte en thème sombre ───
  // Pendants sombres des trois teintes de texte. Les constantes claires
  // (`textPrimary` = bleu nuit, `textSecondary` = gris 33 %) sont illisibles
  // sur une surface ardoise ; tout écran doit passer par les accesseurs
  // contextuels ci-dessous plutôt que par la constante.
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textMutedDark = Color(0xFF94A3B8);

  /// Rouge d'erreur du thème sombre.
  ///
  /// `#DC3545` ne rend que 3,4:1 sur l'ardoise : lisible de justesse, et ce
  /// sont précisément les messages qu'on ne peut pas se permettre de rater.
  /// Même teinte, clarté remontée — c'est le `--color-danger-text` du portail
  /// web, à l'identique.
  static const Color errorDark = Color(0xFFFCA5A5);

  static bool estSombre(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Rouge d'erreur adapté au thème courant. Les écrans ne doivent plus poser
  /// `AppTheme.error` en dur : il disparaît à moitié sur fond ardoise.
  static Color errorOf(BuildContext context) =>
      estSombre(context) ? errorDark : error;

  /// Surface translucide adaptée au thème courant.
  static Color glass(BuildContext context) =>
      estSombre(context) ? glassDark : glassLight;

  /// Bordure adaptée au thème courant.
  static Color borderOf(BuildContext context) =>
      estSombre(context) ? borderDark : border;

  /// Teinte des icônes de navigation. Le bleu nuit de marque disparaît sur les
  /// surfaces sombres : on bascule sur le vert secondaire.
  static Color iconAccent(BuildContext context) =>
      estSombre(context) ? secondaryLight : primary;

  // ─── Texte : toujours par le contexte ─────────────────────────────
  // `AppTheme.textSecondary` posé en dur rendait gris foncé sur ardoise en
  // thème sombre — le texte disparaissait. Ces trois accesseurs sont les
  // seuls autorisés dans les écrans.

  /// Texte principal (titres, valeurs).
  static Color textPrimaryOf(BuildContext context) =>
      estSombre(context) ? textPrimaryDark : textPrimary;

  /// Texte secondaire (descriptions, libellés de champ).
  static Color textSecondaryOf(BuildContext context) =>
      estSombre(context) ? textSecondaryDark : textSecondary;

  /// Texte atténué (métadonnées, horodatages, états vides).
  static Color textMutedOf(BuildContext context) =>
      estSombre(context) ? textMutedDark : textLight;

  /// Fond des zones « en creux » (filtres, en-têtes de tableau, alvéoles).
  static Color surfaceAlt(BuildContext context) =>
      estSombre(context) ? const Color(0xFF16233A) : const Color(0xFFF4F7FB);

  // ─── Lisibilité : on la CALCULE, on ne l'estime plus ──────────────
  //
  // `accentLisible` remontait la clarté à 0,62 en thème sombre, un chiffre
  // choisi à vue. Il tirait bien le bleu nuit hors de l'invisible, mais sans
  // rien garantir : mesuré sur l'arbre monté, le bleu d'accent rendait
  // `#5684E6` sur le fond de sa propre pastille, soit 3,2:1 — au-dessus du
  // seuil de l'invisible, en dessous du seuil de LECTURE. Une centaine de
  // pastilles du portail professeur étaient dans ce cas.
  //
  // La clarté n'est donc plus posée : elle est cherchée, jusqu'au rapport de
  // contraste demandé sur le fond RÉELLEMENT peint dessous. La teinte et la
  // saturation ne bougent pas — le vert reste le vert de la marque, le rouge
  // reste rouge —, seule la clarté se déplace, et du minimum nécessaire.

  /// Niveaux du WCAG 2.1, nommés pour que les appels se lisent.
  ///
  /// [ratioTexte] vaut pour tout ce qui se lit ; [ratioGraphique] pour ce qui
  /// s'identifie sans se lire — glyphes d'icône, jauges, bordures. Appliquer
  /// 4,5:1 à une icône de 40 px délaverait des teintes parfaitement nettes.
  static const double ratioTexte = 4.5;
  static const double ratioGraphique = 3.0;

  /// Rapport de contraste WCAG entre deux couleurs OPAQUES (1,0 à 21,0).
  static double contraste(Color a, Color b) {
    final la = _luminance(a);
    final lb = _luminance(b);
    return ((la > lb ? la : lb) + 0.05) / ((la < lb ? la : lb) + 0.05);
  }

  static double _luminance(Color c) =>
      Color.from(alpha: 1.0, red: c.r, green: c.g, blue: c.b).computeLuminance();

  /// [dessus] composé sur [dessous] — ce que l'œil voit d'une couche
  /// translucide.
  ///
  /// Les surfaces du portail sont translucides par principe (le visuel de
  /// marque doit transparaître) : raisonner sur `#1E293B` alors que l'écran
  /// peint `#1C2637` fausse tous les calculs qui suivent.
  static Color composer(Color dessus, Color dessous) {
    final a = dessus.a;
    if (a >= 1.0) return dessus;
    return Color.from(
      alpha: 1.0,
      red: dessus.r * a + dessous.r * (1 - a),
      green: dessus.g * a + dessous.g * (1 - a),
      blue: dessus.b * a + dessous.b * (1 - a),
    );
  }

  /// [couleur] déplacée en clarté jusqu'à atteindre [cible] sur [fond].
  ///
  /// La direction n'est pas décidée d'après le thème mais d'après le fond
  /// lui-même : on part du côté qui offre le plus de marge (blanc ou noir).
  /// C'est ce qui rend la fonction juste sur un fond inattendu — une pastille
  /// ambrée claire posée dans un écran sombre, par exemple, où « éclaircir
  /// parce qu'on est en thème sombre » irait exactement à l'envers.
  ///
  /// La recherche est dichotomique parce que la clarté HSL est monotone en
  /// luminance : le premier point qui satisfait le seuil est aussi celui qui
  /// dénature le moins la couleur d'origine.
  static Color lisibleSur(Color couleur, Color fond,
      {double cible = ratioTexte}) {
    final opaque = couleur.a >= 1.0 ? couleur : composer(couleur, fond);
    if (contraste(opaque, fond) >= cible) return couleur;

    final hsl = HSLColor.fromColor(opaque);
    // Vers le blanc ou vers le noir : on suit la marge, pas le thème.
    final extreme =
        contraste(const Color(0xFFFFFFFF), fond) >= contraste(const Color(0xFF000000), fond)
            ? 1.0
            : 0.0;
    final butoir = hsl.withLightness(extreme).toColor();
    // Même l'extrême n'y suffit pas (fond gris moyen) : on le rend quand même,
    // c'est le mieux que cette teinte puisse faire ici.
    if (contraste(butoir, fond) < cible) return butoir;

    var insuffisant = hsl.lightness;
    var suffisant = extreme;
    for (var i = 0; i < 16; i++) {
      final milieu = (insuffisant + suffisant) / 2;
      if (contraste(hsl.withLightness(milieu).toColor(), fond) >= cible) {
        suffisant = milieu;
      } else {
        insuffisant = milieu;
      }
    }
    return hsl.withLightness(suffisant).toColor();
  }

  /// [couleur] éclaircie ou assombrie jusqu'à atteindre [cible] sur CHACUN
  /// des [fonds].
  ///
  /// Un dégradé n'a pas un fond mais deux, et un glyphe posé dessus les
  /// traverse tous les deux. Résoudre sur le premier venu laissait l'autre
  /// bout sous le seuil — c'est ce qui arrivait aux plaques d'icône, dont le
  /// glyphe rendait 2,3:1 sur l'extrémité claire de leur propre dégradé.
  static Color lisibleSurToutes(Color couleur, List<Color> fonds,
      {double cible = ratioTexte}) {
    if (fonds.isEmpty) return couleur;
    double pire(Color c) =>
        fonds.map((f) => contraste(c, f)).reduce((a, b) => a < b ? a : b);
    if (pire(couleur) >= cible) return couleur;

    final hsl = HSLColor.fromColor(couleur);
    // La marge se juge sur le fond le plus DÉFAVORABLE : c'est lui qui décide
    // du sens, faute de quoi on s'éloignerait d'un fond en se rapprochant de
    // l'autre.
    final extreme = pire(const Color(0xFFFFFFFF)) >= pire(const Color(0xFF000000))
        ? 1.0
        : 0.0;
    final butoir = hsl.withLightness(extreme).toColor();
    if (pire(butoir) < cible) return butoir;

    var insuffisant = hsl.lightness;
    var suffisant = extreme;
    for (var i = 0; i < 16; i++) {
      final milieu = (insuffisant + suffisant) / 2;
      if (pire(hsl.withLightness(milieu).toColor()) >= cible) {
        suffisant = milieu;
      } else {
        insuffisant = milieu;
      }
    }
    return hsl.withLightness(suffisant).toColor();
  }

  /// Couleur RÉELLEMENT peinte par une carte du portail.
  ///
  /// `Theme.of(context).cardColor` rend `#1E293B` **à 86 %** : c'est une
  /// consigne de peinture, pas une couleur. Tout calcul de contraste doit
  /// partir de sa composition sur le fond du `Scaffold`.
  static Color surfaceCarte(BuildContext context) {
    final theme = Theme.of(context);
    return composer(theme.cardColor, theme.scaffoldBackgroundColor);
  }

  /// Teinte d'accent lisible en TEXTE sur la carte courante.
  ///
  /// Conserve le nom historique : c'est l'accesseur qu'appellent les écrans
  /// des deux portails. Seule sa promesse a changé — elle est désormais
  /// vérifiable, et vérifiée par `mode_sombre_donnees_test.dart`.
  static Color accentLisible(BuildContext context, Color couleur) =>
      lisibleSur(couleur, surfaceCarte(context));

  /// Même chose pour un tracé qui ne se lit pas : icône, jauge, filet.
  static Color accentGraphique(BuildContext context, Color couleur) =>
      lisibleSur(couleur, surfaceCarte(context), cible: ratioGraphique);

  /// Fond d'une pastille de statut, dérivé de sa couleur : les fonds pastel
  /// figés (`#E8F8F2`, `#FEF3C7`…) du web deviennent des aplats blancs en
  /// thème sombre.
  static Color fondPastille(BuildContext context, Color couleur) =>
      couleur.withValues(alpha: estSombre(context) ? 0.20 : 0.12);

  /// Fond opaque d'une pastille, tel qu'il est peint — le voile coloré
  /// composé sur la carte.
  static Color fondPastilleOpaque(BuildContext context, Color couleur) =>
      composer(fondPastille(context, couleur), surfaceCarte(context));

  /// Le couple (fond, premier plan) d'une pastille de statut.
  ///
  /// Les deux ensemble, parce qu'ils se déterminent l'un l'autre : le voile
  /// coloré éclaircit le fond, et c'est CE fond-là — pas la carte nue — que le
  /// texte doit franchir. Les calculer séparément, c'est ce qui laissait passer
  /// une centaine de pastilles à 3,2:1.
  ///
  /// Le fond rendu est **opaque**, et c'est délibéré. Une pastille translucide
  /// prend la couleur de ce qui se trouve dessous, qu'elle ne connaît pas :
  /// posée sur une ligne de notification non lue, elle-même teintée, la
  /// pastille « Nouveau » retombait à 3,9:1 alors que le calcul en promettait
  /// 4,5. Un aplat opaque rend la mesure exacte partout, et se distingue mieux
  /// de la surface qui l'accueille — ce qu'on attend précisément d'une
  /// étiquette.
  static (Color fond, Color texte) pastilleDe(
    BuildContext context,
    Color couleur, {
    double cible = ratioTexte,
  }) {
    final fond = fondPastilleOpaque(context, couleur);
    return (fond, lisibleSur(couleur, fond, cible: cible));
  }

  /// Texte atténué (métadonnée, mention secondaire) lisible sur [fond].
  ///
  /// `textMutedOf` est calibré pour la carte ; posé sur une alvéole teintée il
  /// perd un demi-point de contraste et passe sous le seuil. Ici la teinte
  /// grise de départ est conservée, sa clarté seule s'ajuste.
  static Color texteMuteSur(BuildContext context, Color fond) =>
      lisibleSur(textMutedOf(context), fond);

  // ─── Palette de statuts, commune aux deux portails ───
  // Reprise des constantes `C` du frontend web (MesCours.jsx et suivants).
  static const Color statutBleu = Color(0xFF185FA5);
  static const Color statutVert = Color(0xFF1D9E75);
  static const Color statutOrange = Color(0xFFC07A2B);
  static const Color statutRouge = Color(0xFFB91C1C);
  static const Color statutViolet = Color(0xFF6B21A8);
  static const Color statutNavy = Color(0xFF0B1F4A);

  /// Le vert de marque, assombri juste assez pour porter un libellé BLANC à
  /// 4,5:1.
  ///
  /// `#1D9E75` sous du blanc ne donne que 3,4:1 — sur le bouton d'action
  /// principal, c'est-à-dire sur le libellé le plus important de chaque écran,
  /// et dans les DEUX thèmes. Le défaut ne venait donc pas du mode sombre : il
  /// y était simplement plus visible. Même teinte, même saturation.
  static final Color secondaryLisible =
      lisibleSur(secondary, const Color(0xFFFFFFFF));

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        // Translucide comme la top-bar du portail : le fond de marque
        // transparaît sous la barre.
        backgroundColor: primary.withValues(alpha: 0.92),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Le bouton d'action flottant NE DÉCLARAIT AUCUNE COULEUR, et Material 3
      // la déduisait alors d'un `ColorScheme` que nous ne renseignons qu'en
      // partie. En thème sombre, la déduction tombait sur du NOIR posé sur le
      // bleu `#1A3A7A` : 1,93:1 de contraste, c'est-à-dire illégible. Le
      // défaut touchait d'un coup les seize écrans bâtis sur `EcranRessource`
      // — « Nouveau recours », « Demander un transfert », « Écrire »… :
      // l'action principale de chacun d'eux était le seul bouton illisible de
      // la page. On déclare donc les deux couleurs, plutôt que de les laisser
      // déduire : c'est le même vert que `ElevatedButton`, l'action première
      // ayant la même identité partout dans l'application.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondaryLisible,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // `secondaryLisible` et non `secondary` : cf. sa déclaration — le
          // blanc sur `#1D9E75` ne franchit pas 4,5:1, et c'est le libellé du
          // bouton principal de chaque écran.
          backgroundColor: secondaryLisible,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // Ici le vert est du TEXTE posé sur le fond clair : même exigence,
          // même teinte.
          foregroundColor: secondaryLisible,
          side: BorderSide(color: secondaryLisible),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: secondaryLisible),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: secondary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: textLight,
        ),
      ),
      textTheme: textTheme.copyWith(
        bodySmall: textTheme.bodySmall?.copyWith(
          fontFamily: 'Inter',
          color: textSecondary,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontFamily: 'Inter',
          color: textPrimary,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontFamily: 'Inter',
          color: textPrimary,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontFamily: 'Inter',
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          fontFamily: 'Inter',
          color: textSecondary,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          fontFamily: 'Inter',
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontFamily: 'Inter',
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontFamily: 'Inter',
          color: textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: const CardThemeData(
        color: glassLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: border),
        ),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: glassLight),
      dialogTheme: const DialogThemeData(backgroundColor: surface),
      // Sans ces trois blocs, les listes, onglets et pastilles retombent sur
      // les valeurs Material par défaut — grises identiques dans les deux
      // thèmes, donc invisibles dans l'un des deux.
      listTileTheme: const ListTileThemeData(
        iconColor: primary,
        textColor: textPrimary,
        subtitleTextStyle: TextStyle(color: textSecondary, fontSize: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF4F7FB),
        labelStyle: textTheme.labelMedium?.copyWith(color: textPrimary),
        side: const BorderSide(color: border),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textLight,
        indicatorColor: secondary,
      ),
      dividerTheme: const DividerThemeData(color: border, space: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: primary,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: secondary),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: primaryLight,
        secondary: secondaryLight,
        surface: Color(0xFF1e293b),
        // `errorDark`, pas `error` : cf. sa déclaration. Material peint avec
        // cette teinte les messages de validation des champs, qui étaient à
        // 3,4:1 sur le fond ardoise.
        error: errorDark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0f172a),
      appBarTheme: AppBarTheme(
        backgroundColor: glassDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Le bouton d'action flottant NE DÉCLARAIT AUCUNE COULEUR, et Material 3
      // la déduisait alors d'un `ColorScheme` que nous ne renseignons qu'en
      // partie. En thème sombre, la déduction tombait sur du NOIR posé sur le
      // bleu `#1A3A7A` : 1,93:1 de contraste, c'est-à-dire illégible. Le
      // défaut touchait d'un coup les seize écrans bâtis sur `EcranRessource`
      // — « Nouveau recours », « Demander un transfert », « Écrire »… :
      // l'action principale de chacun d'eux était le seul bouton illisible de
      // la page. On déclare donc les deux couleurs, plutôt que de les laisser
      // déduire : c'est le même vert que `ElevatedButton`, l'action première
      // ayant la même identité partout dans l'application.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        // Vert CLAIR et libellé FONCÉ — l'inversion habituelle des thèmes
        // sombres. Reprendre le vert du thème clair (`#1D9E75`) sous un
        // libellé blanc ne donnerait que 3,4:1, et le bouton lui-même se
        // détacherait mal du fond ardoise. Ici : 8,4:1 pour le libellé, et le
        // bouton reste la chose la plus visible de l'écran, ce qu'il doit être.
        backgroundColor: secondaryLight,
        foregroundColor: primaryDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Exactement le couple du bouton flottant ci-dessus, et pour la même
          // raison : vert CLAIR sous un libellé FONCÉ. Le vert de marque sous
          // du blanc ne rendait que 3,4:1 — le bouton principal de l'écran
          // était le texte le moins lisible de la page. Ici : 8,4:1.
          backgroundColor: secondaryLight,
          foregroundColor: primaryDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: secondaryLight),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: secondaryLight,
          side: const BorderSide(color: secondaryLight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0f172a),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: secondaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF94a3b8),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          // `#64748B` ne rendait que 3,8:1 sur le fond du champ. Un texte
          // indicatif se lit — c'est même souvent la seule consigne de saisie
          // affichée : il relève du seuil du texte, pas de celui d'un ornement.
          color: textMutedDark,
        ),
      ),
      textTheme: textTheme.copyWith(
        bodySmall: textTheme.bodySmall?.copyWith(
          fontFamily: 'Inter',
          color: textSecondaryDark,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontFamily: 'Inter',
          color: const Color(0xFFe2e8f0),
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontFamily: 'Inter',
          color: const Color(0xFFe2e8f0),
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontFamily: 'Inter',
          color: const Color(0xFFe2e8f0),
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          fontFamily: 'Inter',
          color: textSecondaryDark,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          fontFamily: 'Inter',
          color: textPrimaryDark,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontFamily: 'Inter',
          color: const Color(0xFFf1f5f9),
          fontWeight: FontWeight.w700,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontFamily: 'Inter',
          color: const Color(0xFFf1f5f9),
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: const CardThemeData(
        color: glassDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: borderDark),
        ),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: glassDark),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1e293b)),
      listTileTheme: const ListTileThemeData(
        iconColor: secondaryLight,
        textColor: textPrimaryDark,
        subtitleTextStyle: TextStyle(color: textSecondaryDark, fontSize: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF16233A),
        labelStyle: textTheme.labelMedium?.copyWith(color: textPrimaryDark),
        side: const BorderSide(color: borderDark),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: secondaryLight,
        unselectedLabelColor: textMutedDark,
        indicatorColor: secondaryLight,
      ),
      dividerTheme: const DividerThemeData(color: borderDark, space: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1e293b),
        contentTextStyle: TextStyle(color: textPrimaryDark),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: secondaryLight,
      ),
    );
  }
}
