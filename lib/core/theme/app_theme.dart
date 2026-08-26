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

  static bool estSombre(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

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

  /// Teinte d'accent lisible sur les deux fonds pour une couleur de marque
  /// donnée. Le bleu nuit et le rouge foncé passent sous le seuil de contraste
  /// sur ardoise : on les éclaircit plutôt que de les laisser tels quels.
  static Color accentLisible(BuildContext context, Color couleur) {
    if (!estSombre(context)) return couleur;
    final hsl = HSLColor.fromColor(couleur);
    // Remonte la clarté au minimum requis sans dénaturer la teinte.
    return hsl.withLightness(hsl.lightness.clamp(0.62, 1.0)).toColor();
  }

  /// Fond d'une pastille de statut, dérivé de sa couleur : les fonds pastel
  /// figés (`#E8F8F2`, `#FEF3C7`…) du web deviennent des aplats blancs en
  /// thème sombre.
  static Color fondPastille(BuildContext context, Color couleur) =>
      couleur.withValues(alpha: estSombre(context) ? 0.20 : 0.12);

  // ─── Palette de statuts, commune aux deux portails ───
  // Reprise des constantes `C` du frontend web (MesCours.jsx et suivants).
  static const Color statutBleu = Color(0xFF185FA5);
  static const Color statutVert = Color(0xFF1D9E75);
  static const Color statutOrange = Color(0xFFC07A2B);
  static const Color statutRouge = Color(0xFFB91C1C);
  static const Color statutViolet = Color(0xFF6B21A8);
  static const Color statutNavy = Color(0xFF0B1F4A);

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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondary,
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
          foregroundColor: secondary,
          side: const BorderSide(color: secondary),
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
        error: error,
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondary,
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
          color: const Color(0xFF64748b),
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
