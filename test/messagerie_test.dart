// Messagerie mobile alignée sur le portail web (17/09/2026).
//
// Le serveur a changé de fonctionnement : supprimer ne retire le message que de
// la boîte de l'appelant, le personnel a une boîte d'envoi, « lu » est réservé
// au destinataire, une réponse est un vrai message. L'écran devait suivre :
// reçus / envoyés, lu / non lu, réponse proposée seulement quand quelqu'un peut
// la recevoir, et une liste de destinataires qui n'envoie plus l'identifiant
// d'un SERVICE là où le serveur attend celui d'un compte.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/theme/app_theme.dart';
import 'package:genuc_mobile/core/utils/dio_client.dart';
import 'package:genuc_mobile/data/services/appel_api.dart';
import 'package:genuc_mobile/presentation/config/destinations.dart';
import 'package:genuc_mobile/presentation/screens/commun/messagerie_screen.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/montage_portail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    MontagePortail.simulerStockageSecurise();
    DioClient.reset();
  });

  tearDown(DioClient.reset);

  group('Règles pures', () {
    test('les services déclarés (identifiant de SERVICE) sont écartés des destinataires', () {
      final joignables = contactsJoignables(const [
        Fiche({'id': 'scolarite', 'nom': 'Service de Scolarité', 'type': 'SCOLARITE'}),
        Fiche({'id': '7', 'nom': 'Bibliothèque centrale', 'type': 'BIBLIOTHEQUE'}),
        Fiche({'id': '42', 'nom': 'Prof. Kasongo', 'type': 'PROFESSEUR'}),
        Fiche({'nom': 'Sans identifiant'}),
      ]);
      expect(joignables.map((c) => c.id), ['scolarite', '42']);
    });

    test('état de lecture d’un envoi, individuel ou groupé', () {
      expect(etatLectureEnvoi(const Fiche({'lu': true})), 'Lu');
      expect(etatLectureEnvoi(const Fiche({'lu': false})), 'Non lu');
      expect(etatLectureEnvoi(const Fiche({'nbDestinataires': 12, 'nbLus': 3})), '3/12 lus');
    });

    test('le sens rendu par le serveur prime sur le sens par défaut', () {
      expect(avecSens(const Fiche({'id': 1}), 'RECU').texte('sens'), 'RECU');
      expect(avecSens(const Fiche({'id': 1, 'sens': 'ENVOYE'}), 'RECU').texte('sens'), 'ENVOYE');
    });

    test('la recherche ignore accents et casse, et exige tous les mots', () {
      const m = Fiche({'sujet': 'Réunion pédagogique', 'expediteurNom': 'Direction'});
      expect(correspondRecherche(m, 'PEDAGOGIQUE direction'), isTrue);
      expect(correspondRecherche(m, 'pedagogique caisse'), isFalse);
      expect(correspondRecherche(m, '  '), isTrue);
    });
  });

  group('Écran — personnel', () {
    late _Faux serveur;

    setUp(() {
      serveur = _Faux({
        'GET /api/messagerie/admin/1': [
          {
            'id': 5, 'sens': 'RECU', 'sujet': 'Réunion pédagogique', 'contenu': 'Lundi 9 h.',
            'expediteurNom': 'Direction', 'destinataireNom': 'Utilisateur Test',
            'lu': false, 'repondable': true, 'dateEnvoi': '2026-09-17T08:00:00',
          },
        ],
        // Route récente : enveloppe ApiResponse, que le service déballe.
        'GET /api/messagerie/envoyes/1': {
          'success': true, 'status': 200, 'timestamp': 1,
          'data': [
            {
              'id': 9, 'sens': 'ENVOYE', 'sujet': 'Convocation', 'contenu': 'Grand amphi.',
              'expediteurNom': 'Utilisateur Test', 'destinataireNom': '12 destinataires',
              'lu': false, 'repondable': false, 'nbDestinataires': 12, 'nbLus': 3,
              'dateEnvoi': '2026-09-16T08:00:00',
            },
          ],
        },
        'GET /api/messagerie/contacts/1': [
          {'id': 'scolarite', 'nom': 'Service de Scolarité', 'type': 'SCOLARITE'},
        ],
      });
    });

    Future<void> monter(WidgetTester tester) => MontagePortail.monter(
          tester,
          MenuPortail.destination('/professeur/messagerie')!,
          'PROFESSEUR',
          theme: AppTheme.lightTheme,
          adaptateur: serveur,
        );

    testWidgets('reçus et envoyés, avec leurs actions', (tester) async {
      await monter(tester);

      expect(find.text('Reçus (1 · 1 non lu)'), findsOneWidget);
      expect(find.text('Réunion pédagogique'), findsOneWidget);
      expect(find.text('De : Direction'), findsOneWidget);
      expect(find.text('Nouveau'), findsOneWidget);
      expect(find.byTooltip('Marquer lu'), findsOneWidget);
      expect(find.byTooltip('Supprimer'), findsOneWidget);

      await tester.tap(find.text('Envoyés (1)'));
      await tester.pump();

      expect(find.text('Convocation'), findsOneWidget);
      expect(find.text('À : 12 destinataires'), findsOneWidget);
      expect(find.text('3/12 lus'), findsOneWidget);
      expect(find.byTooltip('Marquer lu'), findsNothing,
          reason: '« lu » décrit ici le destinataire, pas l’expéditeur');
      expect(find.text('Réunion pédagogique'), findsNothing);
    });

    testWidgets('ouvrir un message reçu le marque lu ; la feuille propose réponse et « non lu »',
        (tester) async {
      await monter(tester);

      await tester.tap(find.text('Réunion pédagogique'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(serveur.appels['PATCH /api/messagerie/5/lu'], 1);
      expect(find.text('Nouveau'), findsNothing, reason: 'la carte suit la lecture sans recharger');
      expect(find.text('Répondre à Direction'), findsOneWidget);
      expect(find.text('Marquer non lu'), findsOneWidget);
      expect(find.text('Envoyer'), findsOneWidget);
    });

    testWidgets('supprimer demande confirmation puis retire la carte', (tester) async {
      await monter(tester);

      await tester.tap(find.byTooltip('Supprimer'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('L\'expéditeur le conserve'), findsOneWidget);

      // `ElevatedButton.icon` n'est pas du type exact `ElevatedButton` : on
      // vise le libellé dans la boîte de confirmation.
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Supprimer')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(serveur.appels['DELETE /api/messagerie/5'], 1);
      expect(find.text('Réunion pédagogique'), findsNothing);
      expect(find.text('Message supprimé.'), findsOneWidget);
    });

    testWidgets('marquer non lu depuis la carte', (tester) async {
      serveur.reponses['GET /api/messagerie/admin/1'] = [
        {
          'id': 6, 'sens': 'RECU', 'sujet': 'Relevé', 'contenu': 'Prêt.',
          'expediteurNom': 'Secrétariat', 'lu': true, 'repondable': true,
          'dateEnvoi': '2026-09-17T08:00:00',
        },
      ];
      await monter(tester);

      await tester.tap(find.byTooltip('Marquer non lu'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(serveur.appels['PATCH /api/messagerie/6/non-lu'], 1);
      expect(find.text('Nouveau'), findsOneWidget);
    });
  });

  group('Écran — étudiant', () {
    testWidgets('une seule route, deux dossiers ; un message automatique ne propose pas de réponse',
        (tester) async {
      final serveur = _Faux({
        'GET /api/messagerie/etudiant/1': [
          {
            'id': 1, 'sens': 'RECU', 'sujet': 'Relevé disponible', 'contenu': 'Votre relevé est prêt.',
            'lu': true, 'repondable': false, 'dateEnvoi': '2026-09-17T08:00:00',
          },
          {
            'id': 2, 'sens': 'ENVOYE', 'sujet': 'Demande d’attestation', 'contenu': 'Bonjour.',
            'destinataireNom': 'Service de Scolarité', 'lu': false, 'repondable': true,
            'dateEnvoi': '2026-09-16T08:00:00',
          },
        ],
        'GET /api/messagerie/contacts/1': const [],
      });
      await MontagePortail.monter(
        tester,
        MenuPortail.destination('/etudiant/messagerie')!,
        'ETUDIANT',
        theme: AppTheme.lightTheme,
        adaptateur: serveur,
      );

      expect(find.text('Reçus (1)'), findsOneWidget);
      expect(find.text('Envoyés (1)'), findsOneWidget);
      expect(find.text('Demande d’attestation'), findsNothing);
      expect(serveur.appels.keys.where((k) => k.contains('/envoyes/')), isEmpty,
          reason: 'la boîte étudiante rend déjà les envois');

      await tester.tap(find.text('Relevé disponible'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Message automatique'), findsOneWidget);
      expect(find.text('Envoyer'), findsNothing);
      expect(serveur.appels['PATCH /api/messagerie/1/lu'], isNull,
          reason: 'déjà lu : aucune écriture');
    });
  });
}

/// Serveur de substitution : répond selon « MÉTHODE chemin », 200 `{}` sinon.
class _Faux implements HttpClientAdapter {
  final Map<String, Object> reponses;
  final Map<String, int> appels = {};

  _Faux(Map<String, Object> reponses) : reponses = Map.of(reponses);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final cle = '${options.method.toUpperCase()} ${options.uri.path}';
    appels.update(cle, (n) => n + 1, ifAbsent: () => 1);
    final corps = reponses[cle] ?? <String, Object>{};
    return ResponseBody.fromString(jsonEncode(corps), 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }
}
