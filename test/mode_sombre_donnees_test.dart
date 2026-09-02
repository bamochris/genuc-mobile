import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/theme/app_theme.dart';
import 'package:genuc_mobile/core/utils/dio_client.dart';
import 'package:genuc_mobile/presentation/config/destinations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/audit_contraste.dart';
import 'support/montage_portail.dart';
import 'support/serveur_simule.dart';

/// Lisibilité en thème sombre **une fois les données arrivées**.
///
/// <h3>Le trou que cette suite bouche</h3>
///
/// `mode_sombre_test.dart` coupe le réseau : les écrans y montrent leur état
/// d'erreur, quatre lignes de texte gris, et c'est tout ce qui était mesuré.
/// Les soixante-dix-sept cas passaient donc au vert pendant que le portail
/// professeur restait illisible sur le terrain — parce que TOUT ce qui porte
/// une couleur de marque ne s'affiche qu'avec des données : les cartes de
/// statistiques, les pastilles de statut, les grilles horaires, les tableaux
/// de notes, les alertes.
///
/// La même mesure est donc rejouée ici, mais servie par [ServeurSimule]. Ce
/// n'est pas une variante cosmétique de l'autre suite : c'est là que se
/// trouvaient les défauts.
///
/// <h3>Et le thème clair ?</h3>
///
/// Il est audité lui aussi, dans le même mouvement. Éclaircir une couleur pour
/// le fond ardoise se paie facilement d'un texte délavé sur le fond blanc ;
/// mesurer les deux thèmes est la seule façon de savoir qu'on n'a pas déplacé
/// le problème.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // `AppTheme` construit ses styles avec `GoogleFonts.interTextTheme()`, qui
    // va CHERCHER la police sur fonts.gstatic.com. Hors ligne, l'exception
    // remonte en « did not complete » sur les cent-vingt cas d'un coup. La
    // police de repli n'a d'incidence que sur le dessin des glyphes : l'audit
    // mesure des couleurs, que le choix de fonte ne touche pas.
    GoogleFonts.config.allowRuntimeFetching = false;
    MontagePortail.simulerStockageSecurise();
    DioClient.reset();
  });

  tearDown(DioClient.reset);

  void verifier(RapportContraste rapport, String ou) {
    expect(rapport.examines, greaterThan(0),
        reason: 'Aucun texte ni icône mesurable sur « $ou » : '
            "l'écran ne s'est pas monté, l'audit ne prouve rien.");
    expect(
      rapport.defauts,
      isEmpty,
      reason: 'Contraste insuffisant sur « $ou » :\n  '
          '${rapport.defauts.join('\n  ')}',
    );
  }

  // Les thèmes sont passés en FABRIQUE, pas en valeur : les construire ici,
  // dans le corps de `main`, les bâtirait hors de toute zone de test — et
  // `GoogleFonts` y lève « There is no current invoker », avant même le premier
  // cas.
  for (final (nomTheme, theme) in <(String, ThemeData Function())>[
    ('sombre', () => AppTheme.darkTheme),
    ('clair', () => AppTheme.lightTheme),
  ]) {
    for (final role in const ['PROFESSEUR', 'ETUDIANT']) {
      group('Thème $nomTheme avec données — portail ${role.toLowerCase()}', () {
        for (final destination in MenuPortail.toutes(role)) {
          testWidgets('${destination.libelle} est lisible', (tester) async {
            await MontagePortail.monter(
              tester,
              destination,
              role,
              theme: theme(),
              adaptateur: ServeurSimule(),
            );
            verifier(AuditContraste.auditer(tester),
                '${destination.libelle} (${destination.chemin}) — $nomTheme');
          });
        }
      });
    }

    group('Thème $nomTheme avec données — coque et écrans hors menu', () {
      for (final role in const ['PROFESSEUR', 'ETUDIANT']) {
        testWidgets('la coque ${role.toLowerCase()} est lisible',
            (tester) async {
          await MontagePortail.monter(
            tester,
            MontagePortail.coqueComme(role),
            role,
            theme: theme(),
            adaptateur: ServeurSimule(),
          );
          verifier(AuditContraste.auditer(tester), 'coque $role — $nomTheme');
        });

        testWidgets('le tiroir ${role.toLowerCase()} est lisible',
            (tester) async {
          await MontagePortail.monter(
            tester,
            MontagePortail.coqueComme(role),
            role,
            theme: theme(),
            adaptateur: ServeurSimule(),
          );
          await tester.tap(find.byTooltip('Open navigation menu'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          verifier(AuditContraste.auditer(tester), 'tiroir $role — $nomTheme');
        });
      }

      for (final destination in MenuPortail.horsMenu) {
        testWidgets('${destination.libelle} est lisible', (tester) async {
          await MontagePortail.monter(
            tester,
            destination,
            'ETUDIANT',
            theme: theme(),
            adaptateur: ServeurSimule(),
          );
          verifier(AuditContraste.auditer(tester),
              '${destination.libelle} (${destination.chemin}) — $nomTheme');
        });
      }
    });
  }
}
