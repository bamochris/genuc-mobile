import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/data/services/appel_api.dart';
import 'package:genuc_mobile/presentation/screens/etudiant/demarches/demarches_screens.dart';

/// Garde-fous posés en alignant le mobile sur les correctifs du portail web
/// des 27 et 28/08/2026 (`genuc-app`, commits `1340856` et `c25f15d`).
///
/// Les trois défauts fermés ici ont ceci de commun qu'ILS NE SE VOYAIENT PAS :
/// une clé JSON mal nommée rend une chaîne vide, une enveloppe non déballée
/// rend un objet sans le champ demandé, un statut inconnu retombe sur son nom
/// interne. Aucun n'a jamais levé d'erreur — d'où ces vérifications, qui
/// portent sur les charges utiles réelles du serveur.
void main() {
  group('Emploi du temps — HoraireResponse', () {
    /// Charge utile de `GET /api/horaires/etudiant/{inscriptionId}`, telle que
    /// `HoraireResponse.fromEntity` la construit.
    const creneau = {
      'id': 12,
      'jour': 'MONDAY',
      'heureDebut': '08:00:00',
      'heureFin': '10:00:00',
      'type': 'COURS',
      'promotionLibelle': 'L1',
      'semestre': 'S1',
      'coursId': 44,
      'coursCode': 'INFO101',
      'coursTitre': 'Algorithmique',
      'professeurId': 7,
      'professeurNom': 'Mbuyi Kalala',
      'salleId': 3,
      'salleNom': 'Amphi B',
      'salleBatiment': 'Bloc pédagogique',
      'vacationId': 1,
      'vacationNom': 'Jour',
    };

    test('la salle et l\'enseignant se lisent sur les noms servis', () {
      // L'écran lisait `salle` et `professeur`, qui n'existent dans aucune
      // réponse : les deux lignes étaient simplement omises, sans erreur.
      final fiche = Fiche.depuis(creneau);
      expect(fiche.texte('salleNom', alias: const ['salle']), 'Amphi B');
      expect(
        fiche.texte('professeurNom', alias: const ['professeur']),
        'Mbuyi Kalala',
      );
    });

    test('les noms courts restent acceptés — /planning les sert ainsi', () {
      // `GET /api/professeur/planning/{id}` construit ses séances à la main et
      // nomme bien la salle `salle`. Les alias couvrent les deux routes.
      final fiche = Fiche.depuis(const {'salle': 'Labo 2', 'titre': 'TP'});
      expect(fiche.texte('salleNom', alias: const ['salle']), 'Labo 2');
    });

    test('le semestre est lu, et absent il ne vaut rien', () {
      expect(Fiche.depuis(creneau).texte('semestre'), 'S1');
      // Les créneaux antérieurs à la V66 n'en portent pas : afficher « Annuel »
      // par défaut affirmerait un découpage jamais déclaré.
      final ancien = Map<String, dynamic>.from(creneau)..remove('semestre');
      expect(Fiche.depuis(ancien).texte('semestre'), isEmpty);
    });
  });

  group('Transferts — vocabulaire du circuit', () {
    test('BOUCHE s\'affiche « Brouillon »', () {
      // Le nom interne est une coquille, mais son sens est établi par le code :
      // `TransfertService` le pose à la création en journalisant « Demande
      // créée en brouillon ». L'écran affichait « Bouche ».
      expect(statutTransfert('BOUCHE')?.$1, 'Brouillon');
    });

    test('les statuts du circuit ne retombent pas sur leur nom interne', () {
      // Ces statuts sont ceux de `TransfertDemande.StatutTransfert` : aucun
      // n'existe dans le circuit des demandes académiques, auquel l'écran les
      // soumettait.
      for (final code in const [
        'SOUMIS',
        'EN_VERIFICATION_ORIGINE',
        'QUITUS_DELIVRE',
        'QUITUS_REFUSE',
        'EN_EXAMEN_DESTINATION',
        'EQUIVALENCES_EN_COURS',
        'DECISION_FINALE',
        'ACCEPTE',
        'ACCEPTE_SOUS_CONDITION',
        'REFUSE',
        'ESCALADE_MINISTERIELLE',
        'CLOTURE',
      ]) {
        final libelle = statutTransfert(code)?.$1;
        expect(libelle, isNotNull, reason: '$code n\'a pas de libellé.');
        expect(
          libelle,
          isNot(code.replaceAll('_', ' ')),
          reason: '$code retombe sur le repli « code brut ».',
        );
      }
    });

    test('un statut vide ne produit aucune pastille', () {
      expect(statutTransfert(''), isNull);
    });
  });

  group('Transferts — titre de la liste de suivi', () {
    test('la filière d\'accueil passe devant l\'établissement', () {
      // Le titre ne portait que l'établissement. Un inter-filière n'en change
      // pas : toutes les demandes de ce type — le cas courant — s'affichaient
      // sous le nom du même établissement, indiscernables les unes des autres.
      expect(
        titreTransfert(Fiche.depuis(const {
          'filiereDestinationNom': 'Sciences économiques',
          'universiteDestinationNom': 'Université de Kinshasa',
        })),
        'Sciences économiques — Université de Kinshasa',
      );
    });

    test('deux demandes vers le même établissement se distinguent', () {
      const etablissement = 'Université de Kinshasa';
      String titre(String filiere) => titreTransfert(Fiche.depuis({
            'filiereDestinationNom': filiere,
            'universiteDestinationNom': etablissement,
          }));
      expect(titre('Droit privé'), isNot(titre('Sciences économiques')));
    });

    test('chaque niveau absent fait replier le titre, jamais échouer', () {
      // `verifierCoherenceDestination` ne vérifie que la cohérence des niveaux
      // ENTRE EUX : le serveur accepte qu'ils soient nuls pour rester capable
      // de relire les dossiers antérieurs à la cascade.
      expect(
        titreTransfert(Fiche.depuis(const {
          'universiteDestinationNom': 'Université de Lubumbashi',
        })),
        'Université de Lubumbashi',
      );
      expect(
        titreTransfert(Fiche.depuis(const {
          'filiereDestinationNom': 'Droit privé',
        })),
        'Droit privé',
      );
      expect(
        titreTransfert(Fiche.depuis(const {'id': 9})),
        'Demande de transfert',
      );
    });

    test('un champ nul ou « null » ne devient pas le titre', () {
      // Jackson omet les champs nuls, mais les charges utiles relayées par
      // d'autres couches les rendent parfois explicitement.
      expect(
        titreTransfert(Fiche.depuis(const {
          'filiereDestinationNom': null,
          'universiteDestinationNom': 'null',
        })),
        'Demande de transfert',
      );
    });
  });

  group('Transferts — le type inter-vacation est fermé', () {
    test('il n\'est plus proposé à la création', () {
      // Le serveur le refuse désormais (« TYPE_FERME ») et c'était la valeur
      // PAR DÉFAUT du formulaire : l'étudiant envoyait une demande
      // inexploitable sans avoir rien choisi.
      expect(typesTransfertProposes.containsKey('INTER_VACATION'), isFalse);
      expect(
        typesTransfertProposes.keys,
        containsAll(const ['INTER_FILIERE', 'INTER_UNIVERSITAIRE']),
      );
    });

    test('il reste LISIBLE : des demandes anciennes le portent', () {
      // Le retirer des libellés afficherait « INTER VACATION » brut dans
      // l'historique d'un dossier archivé.
      expect(libelleTypeTransfert('INTER_VACATION'), 'Inter-vacation');
    });
  });

  group('Déballage des réponses serveur', () {
    test('un tableau nu passe tel quel', () {
      expect(extraireListe([
        {'id': 1},
        {'id': 2},
      ]).length, 2);
    });

    test('la page Spring enveloppée dans ApiResponse est déballée', () {
      // Forme exacte de `GET /api/transfert/demandes/mon-dossier` :
      // `ApiResponse.ok(Page<TransfertDemandeDTO>)`.
      final fiches = extraireListe({
        'success': true,
        'status': 200,
        'data': {
          'content': [
            {'id': 9, 'numeroDemande': 'TR-2026-000009'},
          ],
          'totalElements': 1,
        },
        'timestamp': 1756000000000,
      });
      expect(fiches.length, 1);
      expect(fiches.first.texte('numeroDemande'), 'TR-2026-000009');
    });

    test('une enveloppe PORTANT un message est déballée elle aussi', () {
      // `ApiResponse.ok(dto, "Demande de transfert créée")` fait CINQ clés. Le
      // seuil de quatre les laissait passer telles quelles : l'appelant
      // recevait l'enveloppe, où `id` n'existe pas, et lisait un objet vide.
      final fiche = Fiche.depuis(deballerReponse({
        'success': true,
        'status': 200,
        'message': 'Demande de transfert créée',
        'data': {'id': 42, 'statut': 'BOUCHE'},
        'timestamp': 1756000000000,
      }));
      expect(fiche.id, '42');
      expect(fiche.texte('statut'), 'BOUCHE');
    });

    test('un objet métier portant un champ « data » n\'est pas déballé', () {
      // La précaution qui justifie le seuil : sans elle, on renverrait le
      // contenu du champ au lieu de l'objet qui le porte.
      final objet = {
        'id': 5,
        'nom': 'Rapport',
        'data': {'x': 1},
        'auteur': 'Kabeya',
        'creeLe': '2026-08-28',
        'taille': 12,
      };
      expect(deballerReponse(objet), same(objet));
    });
  });
}
