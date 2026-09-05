import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/presentation/config/destinations.dart';

/// Vérifications de la table de routes des portails.
///
/// Le défaut que ces tests ferment est celui qui a motivé la refonte : le menu
/// affichait des entrées dont l'écran n'était relié à rien, et l'utilisateur
/// recevait « écran à venir » sur des pages pourtant écrites. Un lien de menu
/// sans destination résoluble est donc une erreur, pas un état transitoire.
void main() {
  group('Table de routes', () {
    test('chaque entrée de menu résout vers un écran', () {
      for (final role in ['ETUDIANT', 'PROFESSEUR', 'CAISSIER']) {
        for (final destination in MenuPortail.toutes(role)) {
          expect(
            MenuPortail.destination(destination.chemin),
            isNotNull,
            reason: 'Le chemin « ${destination.chemin} » du menu $role '
                'ne résout vers aucun écran.',
          );
        }
      }
    });

    test('les chemins sont uniques dans un même rôle', () {
      for (final role in ['ETUDIANT', 'PROFESSEUR']) {
        final chemins = MenuPortail.toutes(role).map((d) => d.chemin).toList();
        expect(
          chemins.toSet().length,
          chemins.length,
          reason: 'Deux entrées du menu $role partagent un chemin : '
              'la seconde serait inatteignable.',
        );
      }
    });

    test('la barre basse ne vise que des destinations connues', () {
      for (final role in ['ETUDIANT', 'PROFESSEUR']) {
        final barre = MenuPortail.barreBasse(role);
        expect(barre, isNotEmpty, reason: 'Barre basse vide pour $role.');
        for (final (destination, _) in barre) {
          expect(
            MenuPortail.destination(destination.chemin),
            isNotNull,
            reason: 'La barre basse de $role vise « ${destination.chemin} », '
                'qui ne résout vers aucun écran.',
          );
        }
      }
    });

    test('la racine de la barre basse préfixe bien sa destination', () {
      // C'est ce qui garde l'onglet allumé quand on passe d'un volet du module
      // à l'autre : une racine qui ne préfixe pas éteint l'onglet à la
      // première navigation.
      for (final role in ['ETUDIANT', 'PROFESSEUR']) {
        for (final (destination, racine) in MenuPortail.barreBasse(role)) {
          expect(
            destination.chemin == racine ||
                destination.chemin.startsWith('$racine/'),
            isTrue,
            reason: '« ${destination.chemin} » n\'est pas sous « $racine ».',
          );
        }
      }
    });

    test('chaque rôle a un accueil résoluble', () {
      for (final role in ['ETUDIANT', 'PROFESSEUR', 'DOYEN', '']) {
        final accueil = MenuPortail.accueil(role);
        expect(
          MenuPortail.destination(accueil),
          isNotNull,
          reason: 'L\'accueil de « $role » ($accueil) ne résout pas.',
        );
      }
    });

    test('un module retrouve les chemins de ses volets', () {
      final module = MenuPortail.moduleDe('ETUDIANT', '/etudiant/bulletins');
      expect(module, isNotNull);
      expect(module!.cle, 'resultats');
      expect(
        module.destinations.map((d) => d.chemin),
        contains('/etudiant/parcours'),
      );

      // Un lien simple n'appartient à aucun module : pas de pastilles à
      // afficher au-dessus de lui.
      expect(MenuPortail.moduleDe('ETUDIANT', '/etudiant/horaire'), isNull);
    });
  });

  group('Filtrage par modulesActifs', () {
    test('une carte vide laisse tout le menu', () {
      final entrees = MenuPortail.pourRole('ETUDIANT');
      expect(MenuPortail.filtrer(entrees, const {}).length, entrees.length);
    });

    test('un module absent de la carte reste actif', () {
      // Compatibilité ascendante du web : seul un `false` explicite ferme.
      // L'inverser viderait le menu de tout établissement n'ayant jamais
      // touché à ce réglage.
      expect(
        MenuPortail.destinationActive(
          '/etudiant/bibliotheque',
          const {'stages': false},
        ),
        isTrue,
      );
    });

    test('un module fermé retire le lien correspondant', () {
      final filtre = MenuPortail.filtrer(
        MenuPortail.pourRole('ETUDIANT'),
        const {'bibliotheque': false},
      );
      final chemins = [
        for (final entree in filtre)
          switch (entree) {
            EntreeSimple(:final destination) => [destination.chemin],
            EntreeModule(:final module) =>
              module.destinations.map((d) => d.chemin).toList(),
          },
      ].expand((c) => c);

      expect(chemins, isNot(contains('/etudiant/bibliotheque')));
      // Le reste du menu ne bouge pas.
      expect(chemins, contains('/etudiant/mes-cours'));
    });

    test('un module dont tous les volets sont fermés disparaît', () {
      // « Mes travaux » contient le stage : fermer le module `stages` doit
      // laisser le module debout avec ses autres volets, pas le supprimer.
      final filtre = MenuPortail.filtrer(
        MenuPortail.pourRole('ETUDIANT'),
        const {'stages': false},
      );
      final travaux = filtre
          .whereType<EntreeModule>()
          .where((e) => e.module.cle == 'travaux')
          .toList();

      expect(travaux, hasLength(1));
      expect(
        travaux.single.module.destinations.map((d) => d.chemin),
        isNot(contains('/etudiant/stages')),
      );
      expect(
        travaux.single.module.destinations.map((d) => d.chemin),
        contains('/etudiant/travaux'),
      );
    });

    test('le filtrage ne mutile pas la table d\'origine', () {
      // `filtrer` reconstruit les modules ; s'il modifiait les listes en
      // place, un établissement ayant fermé un module l'aurait fermé pour
      // toute la session, y compris après reconnexion sur un autre compte.
      final avant = MenuPortail.toutes('ETUDIANT').length;
      MenuPortail.filtrer(
        MenuPortail.pourRole('ETUDIANT'),
        const {'bibliotheque': false, 'stages': false},
      );
      expect(MenuPortail.toutes('ETUDIANT').length, avant);
    });
  });

  group('Parité avec le portail web', () {
    // Chemins déclarés dans `LIENS_PAR_ROLE` (`components/Navbar.jsx`), hors
    // entrée `action: 'password'` qui n'est pas une page.
    const cheminsWebEtudiant = [
      '/etudiant/dashboard',
      '/etudiant/mes-cours',
      // Les supports déposés par les enseignants. Ajouté au web et au mobile
      // le 04/09/2026 : le dépôt existait côté professeur, aucune entrée n'y
      // menait côté étudiant.
      '/etudiant/supports',
      '/etudiant/horaire',
      '/etudiant/presences',
      '/etudiant/presences/scanner',
      '/etudiant/presences/marquer',
      '/etudiant/resultats',
      '/etudiant/bulletins',
      '/etudiant/parcours',
      '/etudiant/recours',
      '/etudiant/frais',
      '/etudiant/dossier-social',
      '/etudiant/transfert',
      '/etudiant/demande-changement-filiere',
      '/etudiant/demande-changement-vacation',
      '/etudiant/demandes-academiques',
      '/etudiant/attestations',
      '/etudiant/equivalences-diplomes',
      '/etudiant/bibliotheque',
      '/etudiant/messagerie',
      '/etudiant/profil',
      '/etudiant/profil/documents',
      '/etudiant/parametres',
    ];

    const cheminsWebProfesseur = [
      '/professeur/dashboard',
      '/professeur/mes-cours',
      // Ajouté au web et au mobile le 05/09/2026 : publier un travail, joindre
      // ses consignes et corriger les copies n'avait d'écran nulle part.
      '/professeur/mes-cours/travaux',
      '/professeur/mes-cours/supports',
      '/professeur/mes-cours/planning',
      '/professeur/mes-etudiants',
      '/professeur/presences/smart',
      '/professeur/presences/qrcode',
      '/professeur/presences/saisie',
      '/professeur/presences/historique',
      '/professeur/presences/statistiques',
      '/professeur/notes/saisie',
      '/professeur/notes/import',
      '/professeur/notes/export',
      '/professeur/notes/calculs',
      '/professeur/notes/historique',
      '/professeur/evaluations/interrogations',
      '/professeur/evaluations/tp-td',
      '/professeur/evaluations/examens',
      '/professeur/evaluations/baremes',
      '/professeur/tfc/sujets',
      '/professeur/tfc/encadrements',
      '/professeur/tfc/suivi',
      '/professeur/stages/validation',
      '/professeur/stages/suivi',
      '/professeur/stages/rapports',
      '/professeur/deliberation',
      '/professeur/recherche/publications',
      '/professeur/recherche/projets',
      '/professeur/recherche/conferences',
      '/professeur/recherche/laboratoires',
      '/professeur/rapports/reussite',
      '/professeur/rapports/presences',
      '/professeur/rapports/notes',
      '/professeur/calendrier',
      '/professeur/messagerie',
      '/professeur/bibliotheque',
      '/professeur/parametres',
      '/professeur/documents/contrats',
      '/professeur/mon-evaluation',
    ];

    test('le portail étudiant couvre tous les chemins du web', () {
      final mobiles = MenuPortail.toutes('ETUDIANT').map((d) => d.chemin).toSet();
      for (final chemin in cheminsWebEtudiant) {
        expect(mobiles, contains(chemin), reason: 'Manquant : $chemin');
      }
    });

    test('le portail enseignant couvre tous les chemins du web', () {
      final mobiles =
          MenuPortail.toutes('PROFESSEUR').map((d) => d.chemin).toSet();
      for (final chemin in cheminsWebProfesseur) {
        expect(mobiles, contains(chemin), reason: 'Manquant : $chemin');
      }
    });
  });
}
