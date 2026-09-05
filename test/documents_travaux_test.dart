import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/di/dependencies.dart';
import 'package:genuc_mobile/data/services/appel_api.dart';
import 'package:genuc_mobile/data/services/etudiant_academique_service.dart';
import 'package:genuc_mobile/data/services/fichiers_prives.dart';

import 'support/montage_portail.dart';

/// Garde-fous posés en réparant « Travaux et devoirs » et « Documents » du
/// portail étudiant mobile (04/09/2026).
///
/// Les quatre défauts fermés ici ne levaient AUCUNE erreur : une enveloppe non
/// reconnue rend une liste vide, une clé mal nommée rend une chaîne vide, un
/// verbe HTTP faux rend une erreur générique, et un chemin de stockage passé à
/// `launchUrl` rend un `false` que personne ne lit. Chacun se présentait donc
/// comme un écran normal — simplement vide, ou muet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(MontagePortail.simulerStockageSecurise);

  group('Travaux — l\'enveloppe du serveur', () {
    /// Charge utile de `GET /api/etudiant/portal/{id}/travaux`, telle que
    /// `TravauxService.mesTravaux` la construit : un OBJET à deux clés.
    const charge = {
      'travaux': [
        {
          'id': 3,
          'titre': 'Devoir 3 — arbres équilibrés',
          'cours': 'Algorithmique',
          'statut': 'CORRIGE',
          'note': 15.5,
          'urlConsignes': '/uploads/travaux/consignes-3.pdf',
          'urlCorrection': '/uploads/travaux/correction-3.pdf',
        },
      ],
      'coursList': [
        {'id': 1, 'code': 'INFO-201', 'titre': 'Algorithmique'},
      ],
    };

    test('la clé `travaux` n\'est PAS une enveloppe que `listeDe` reconnaît',
        () {
      // C'est tout le défaut : `extraireListe` cherche `content`, `items`,
      // `resultats` et `liste`. Aucune ne figure ici, et il rend donc une liste
      // vide. L'écran a annoncé « aucun travail demandé » à tout le monde.
      expect(extraireListe(charge), isEmpty);
    });

    test('lue comme une fiche, la liste des travaux est là', () {
      final travaux = Fiche.depuis(charge).liste('travaux');
      expect(travaux, hasLength(1));
      expect(travaux.single.texte('titre'), 'Devoir 3 — arbres équilibrés');
    });

    test('la copie corrigée est servie, et l\'écran doit la proposer', () {
      // Elle n'existait que sur le web : l'étudiant mobile voyait sa note et le
      // commentaire, jamais le document sur lequel ils portent.
      final travail = Fiche.depuis(charge).liste('travaux').single;
      expect(travail.texte('urlCorrection'), isNotEmpty);
      expect(travail.texte('urlConsignes'), isNotEmpty);
    });
  });

  group('Documents officiels — les clés réellement servies', () {
    /// Une ligne de `DocumentsOfficielsService.mapperDocument`.
    const document = {
      'type': 'RELEVE_NOTES',
      'label': 'Relevé de notes officiel',
      'description': 'Document officiel délivré par l\'établissement.',
      'typeSource': 'RELEVE',
      'fraisCodeRequis': 'FRAIS_DOC',
      'statut': 'PAIEMENT_REQUIS',
      'canDownload': false,
      'canRequest': false,
      'motif': 'Paiement du frais documentaire requis avant téléchargement.',
    };

    test('le titre se lit sur `label` — `libelle` n\'existe pas', () {
      // L'écran lisait `libelle`, `numero` et `dateEmission` : trois clés
      // absentes de toute réponse. Le titre retombait sur l'alias `type`,
      // c'est-à-dire le CODE brut affiché à l'étudiant.
      final fiche = Fiche.depuis(document);
      expect(fiche.donnees.containsKey('libelle'), isFalse);
      expect(fiche.donnees.containsKey('numero'), isFalse);
      expect(fiche.donnees.containsKey('dateEmission'), isFalse);
      expect(
        fiche.texte('label', alias: const ['libelle'], defaut: 'Document'),
        'Relevé de notes officiel',
      );
    });

    test('un document non disponible ne propose ni téléchargement ni demande',
        () {
      // « Télécharger » était offert sur toutes les lignes, y compris celles en
      // attente de paiement : un bouton qui ne pouvait que rendre une erreur.
      final fiche = Fiche.depuis(document);
      expect(fiche.donnees['canDownload'], isFalse);
      expect(fiche.donnees['canRequest'], isFalse);
      expect(fiche.texte('motif'), isNotEmpty);
    });
  });

  group('Génération d\'un document officiel', () {
    test('part en POST, le type dans le corps', () async {
      // La route n'existe qu'en POST avec `{type}` dans le corps. L'appel
      // partait en GET avec le type en paramètre d'URL : 405 à chaque fois,
      // sous le libellé générique « Téléchargement impossible ».
      final espion = _AdaptateurEspion(reponse: [37, 80, 68, 70]);
      final service = _service(espion);

      final octets = await service.genererDocument('42', 'RELEVE_NOTES');

      expect(espion.methode, 'POST');
      expect(
        espion.chemin,
        '/api/etudiant/portal/42/documents/generer',
      );
      expect(espion.corps, {'type': 'RELEVE_NOTES'});
      expect(octets, isNotEmpty);
    });
  });

  group('Ouverture d\'un fichier privé', () {
    test('un chemin de stockage devient une route de l\'API', () {
      expect(
        cheminApiFichier('/uploads/documents/12-diplome.pdf'),
        '/api/fichiers/documents/12-diplome.pdf',
      );
    });

    test('un chemin déjà servi par l\'API n\'est pas préfixé deux fois', () {
      // « /api/fichiers/api/cours/… » serait un 404.
      expect(
        cheminApiFichier('/api/cours/supports/7/fichier'),
        '/api/cours/supports/7/fichier',
      );
    });

    test('le nom écrit sur le téléphone garde l\'extension du chemin', () {
      // Sans extension, aucun lecteur Android ne sait quoi ouvrir.
      expect(
        nomFichierDepuisChemin(
          '/uploads/travaux/correction-3.pdf',
          nomPropose: 'correction_Devoir 3',
        ),
        'correction_Devoir 3.pdf',
      );
      expect(
        nomFichierDepuisChemin('/uploads/documents/12-diplome.pdf'),
        '12-diplome.pdf',
      );
    });

    test('les caractères interdits par le système de fichiers sont neutralisés',
        () {
      expect(
        nomFichierDepuisChemin('/uploads/travaux/a.pdf',
            nomPropose: 'TP 1/2 : "final"'),
        'TP 1_2 _ _final_.pdf',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Les pièces exigées viennent de l'établissement, pas de l'écran
  // ───────────────────────────────────────────────────────────────────────

  group('Pièces exigées', () {
    /// Charge utile de `GET /api/etudiant/documents-requis`, telle que
    /// `DocumentRequisConfigService.apercu` la construit — enveloppée dans
    /// `ApiResponse`.
    final charge = {
      'success': true,
      'data': [
        {
          'cle': 'urlDiplomeEtat',
          'libelle': 'Diplôme d\'État',
          'groupe': 'Titres et notes',
          'accept': 'image/*,application/pdf',
          'obligatoire': true,
          'depose': false,
          'typeEtudiant': 'DIPLOME_ETAT',
        },
        {
          'cle': 'urlAttestationPhysique',
          'libelle': 'Attestation d\'aptitude physique',
          'groupe': 'Dossier administratif',
          'accept': 'image/*,application/pdf',
          'obligatoire': false,
          'depose': false,
          'typeEtudiant': 'ATTESTATION_PHYSIQUE',
        },
      ],
    };

    test('la liste se lit malgré l\'enveloppe ApiResponse', () {
      final fiches = extraireListe(charge);
      expect(fiches, hasLength(2));
      expect(fiches.first.texte('libelle'), 'Diplôme d\'État');
    });

    test('le serveur dit sous quelle nature déposer', () {
      // C'est le point qui évite un quatrième vocabulaire : l'application ne
      // redéduit pas la correspondance clé → nature, elle la lit.
      final fiches = extraireListe(charge);
      expect(fiches[0].texte('typeEtudiant'), 'DIPLOME_ETAT');
      expect(fiches[1].texte('typeEtudiant'), 'ATTESTATION_PHYSIQUE');
    });

    test('les natures proposées existent toutes côté serveur', () {
      // Le sélecteur écrivait `DIPLOME` et `PHOTO`, absents de
      // `DocumentEtudiant.TypeDocument` : `valueOf` levait et le dépôt
      // repartait en 400. Téléverser son diplôme ou sa photo depuis le
      // téléphone n'a jamais fonctionné. Les natures venant maintenant du
      // serveur, aucune ne peut être inventée.
      const enumerationServeur = {
        'PHOTO_IDENTITE', 'DIPLOME_ETAT', 'RELEVE_NOTES', 'ATTESTATION_CONDUITE',
        'ATTESTATION_PHYSIQUE', 'ACTE_NAISSANCE', 'CARTE_IDENTITE', 'PASSEPORT',
        'AUTRE', 'PHOTO_PASSEPORT', 'ATTESTATION_NATIONALITE',
        'ATTESTATION_REUSSITE', 'RELEVE_NOTES_UNIVERSITAIRES', 'DIPLOME_LICENCE',
        'EQUIVALENCE_DIPLOME', 'PROGRAMME_ETUDES', 'ATTESTATION_FREQUENTATION',
        'LETTRE_RECOMMANDATION', 'LETTRE_DEMANDE', 'PREUVE_PAIEMENT',
      };
      for (final f in extraireListe(charge)) {
        expect(enumerationServeur, contains(f.texte('typeEtudiant')));
      }
      // Et les deux natures que l'écran inventait n'en font pas partie.
      expect(enumerationServeur, isNot(contains('DIPLOME')));
      expect(enumerationServeur, isNot(contains('PHOTO')));
    });

    test('le caractère obligatoire se lit comme un booléen', () {
      final fiches = extraireListe(charge);
      expect(fiches[0].booleen('obligatoire'), isTrue);
      expect(fiches[1].booleen('obligatoire'), isFalse);
    });

    test('la liste est demandée sans identifiant dans le chemin', () async {
      // Le périmètre vient du jeton : passer une inscription en paramètre, puis
      // la comparer au propriétaire, ne protège rien.
      final espion = _AdaptateurEspion(reponse: utf8.encode(jsonEncode(charge)));
      await _service(espion).piecesExigees();
      expect(espion.chemin, '/api/etudiant/documents-requis');
      expect(espion.methode, 'GET');
    });
  });
}

EtudiantAcademiqueService _service(HttpClientAdapter adaptateur) {
  final dependencies = Dependencies.creer();
  // Cf. `portail_shell_test.dart` : le minuteur de purge du cache survivrait au
  // test et le ferait échouer bien après son déroulement.
  dependencies.cacheService.dispose();
  dependencies.dioClient.dio.httpClientAdapter = adaptateur;
  return EtudiantAcademiqueService(dependencies.dioClient);
}

/// Retient la requête telle qu'elle part sur le réseau.
class _AdaptateurEspion implements HttpClientAdapter {
  final List<int> reponse;

  String? methode;
  String? chemin;
  dynamic corps;

  _AdaptateurEspion({required this.reponse});

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methode = options.method;
    chemin = options.uri.path;
    corps = options.data is String ? jsonDecode(options.data as String) : options.data;
    return ResponseBody.fromBytes(
      reponse,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/pdf'],
      },
    );
  }
}
