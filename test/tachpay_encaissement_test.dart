// TachPay — le parcours va jusqu'à la confirmation, et ce qu'il affiche est vrai.
//
// Quatre défauts fermés ici, tous invisibles à la compilation :
//
//   1. Le bandeau « Total dû » montrait un NOMBRE DE LIGNES. Le serveur pose
//      `total = frais.size()` et met la somme dans `montantTotal` ; le client
//      lisait `total`. Un étudiant devant trois frais de 850 USD lisait « 3 ».
//   2. Le NUMÉRO D'ENCAISSEMENT était jeté à la lecture, alors que c'est lui
//      qu'un étudiant recopie pour verser.
//   3. Sans compte d'encaissement publié, le serveur rend une liste d'opérateurs
//      VIDE. L'écran affichait « Aucun opérateur configuré » et plus rien
//      n'était cochable : le bouton « Confirmer et payer » répondait
//      « Choisissez un opérateur » indéfiniment. Impasse — alors que le refus
//      doit venir du serveur, à la confirmation.
//   4. Le bon de paiement se demandait pour les frais dont `reste <= 0`, relus
//      dans le checkout. Or ce contexte ne liste que les dettes ACTIVES : un
//      frais soldé en disparaît. La liste était donc toujours vide, et le reçu
//      n'arrivait jamais.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/data/services/tachpay_service.dart';
import 'package:genuc_mobile/presentation/screens/etudiant/paiements/tachpay_flow.dart';

void main() {
  group('Contexte de checkout', () {
    test('le total affiché est un MONTANT, jamais le nombre de frais', () async {
      final service = _service(_Faux({
        '/api/tachpay/etudiant/checkout-context': {
          'data': {'inscriptionId': 7, 'matricule': 'HEC001', 'nom': 'Kabeya', 'prenom': 'Jean'},
          // Le serveur renvoie les deux : `total` compte les lignes,
          // `montantTotal` porte la somme.
          'total': 3,
          'montantTotal': 850.0,
          'frais': [
            {'id': 1, 'libelle': 'Minerval', 'montant': 500, 'reste': 500},
            {'id': 2, 'libelle': 'Laboratoire', 'montant': 200, 'reste': 200},
            {'id': 3, 'libelle': 'Bibliothèque', 'montant': 150, 'reste': 150},
          ],
        },
      }));

      final ctx = await service.checkoutContext();
      expect(ctx.total, 850.0, reason: 'le compte (3) ne doit jamais passer pour un montant');
      expect(ctx.frais.length, 3);
    });

    test('sans montantTotal, la somme des restes fait foi — toujours pas le compte', () async {
      final service = _service(_Faux({
        '/api/tachpay/etudiant/checkout-context': {
          'data': {'inscriptionId': 7},
          'total': 2,
          'frais': [
            {'id': 1, 'libelle': 'Minerval', 'montant': 500, 'reste': 300},
            {'id': 2, 'libelle': 'Laboratoire', 'montant': 200, 'reste': 200},
          ],
        },
      }));

      final ctx = await service.checkoutContext();
      expect(ctx.total, 500.0);
    });
  });

  group('Moyens de paiement', () {
    test('le numéro d’encaissement et l’état de configuration remontent', () async {
      final service = _service(_Faux({
        '/api/universites/42/moyens-paiement': {
          'configure': true,
          'paiementEnLigneActif': true,
          'operateurs': [
            {'code': 'VODACOM', 'libelle': 'M-Pesa (Vodacom)', 'numero': '+243810000000'},
            {'code': 'ORANGE', 'libelle': 'Orange Money'},
          ],
        },
      }));

      final moyens = await service.moyensPaiement('42');
      expect(moyens.configure, isTrue);
      expect(moyens.paiementEnLigneActif, isTrue);
      expect(moyens.operateurs.first.numero, '+243810000000');
      expect(moyens.operateurs.first.aUnNumeroDEncaissement, isTrue);
      // Un opérateur listé sans numéro n'est pas un compte d'encaissement.
      expect(moyens.operateurs.last.aUnNumeroDEncaissement, isFalse);
      expect(moyens.sansNumeroDEncaissement, isFalse);
    });

    test('liste vide = aucun compte publié, et ce n’est pas une panne', () async {
      final service = _service(_Faux({
        '/api/universites/42/moyens-paiement': {
          'configure': false,
          'paiementEnLigneActif': false,
          'message': 'Coordonnées de versement non encore configurées par l’université.',
          'operateurs': <dynamic>[],
        },
      }));

      final moyens = await service.moyensPaiement('42');
      expect(moyens.operateurs, isEmpty);
      expect(moyens.sansNumeroDEncaissement, isTrue);
      expect(moyens.configure, isFalse);
    });
  });

  group('L’écran de paiement ne se ferme jamais avant la confirmation', () {
    TachPayEcranPaiement ecranAvec(MoyensPaiement moyens) => TachPayEcranPaiement(
          service: _service(_Faux(const {})),
          contexte: CheckoutContext(
            inscriptionId: 7, matricule: 'HEC001', nomComplet: 'Jean Kabeya',
            universiteId: '42', universiteNom: 'HEC', frais: const [], total: 850,
          ),
          affectationIds: const [1, 2],
          total: 850,
          moyens: moyens,
        );

    test('aucun opérateur publié : on propose quand même les quatre connus', () {
      final ecran = ecranAvec(const MoyensPaiement.aucun());
      // Sans cela, plus rien n'était cochable et le parcours s'arrêtait là.
      expect(ecran.operateursProposes, isNotEmpty);
      expect(ecran.operateursProposes.map((o) => o.code),
          containsAll(<String>['VODACOM', 'ORANGE', 'AIRTEL', 'AFRIMONEY']));
      // Les codes doivent être ceux que l'initiation accepte, sinon le serveur
      // répond « OPERATEUR_INCONNU » au lieu du vrai motif.
      for (final o in ecran.operateursProposes) {
        expect(o.code, equals(o.code.toUpperCase()));
      }
    });

    test('opérateurs publiés : ce sont eux qui sont proposés, pas le repli', () {
      final ecran = ecranAvec(const MoyensPaiement(
        operateurs: [OperateurMobile(code: 'ORANGE', libelle: 'Orange Money', numero: '+243890000000')],
        configure: true,
        paiementEnLigneActif: true,
      ));
      expect(ecran.operateursProposes.length, 1);
      expect(ecran.operateursProposes.single.numero, '+243890000000');
    });
  });

  group('Bon de paiement', () {
    test('il se demande pour les affectations PAYÉES, transmises par l’écran', () async {
      final faux = _Faux({
        '/api/tachpay/etudiant/bon-paiement': [
          {'numero': 'BON-2026-001', 'montant': 850, 'dateGeneration': '2026-09-13'},
        ],
      });
      final service = _service(faux);

      final bons = await service.genererBon([11, 12]);

      // Le corps porte les IDs du paiement. Les relire dans le checkout ne
      // marche pas : soldés, ils n'y figurent plus.
      expect(faux.dernierCorps, [11, 12]);
      expect(bons.single.numero, 'BON-2026-001');
    });
  });
}

TachPayService _service(_Faux faux) {
  // Un Dio nu : ni `DioClient` ni `Dependencies` — le second arme un
  // `Timer.periodic` dans `CacheService` qui survivrait au test
  // (cf. portail_shell_test.dart).
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
    ..httpClientAdapter = faux;
  return TachPayService(dio);
}

/// Serveur de substitution : rend la réponse déclarée pour le chemin appelé.
class _Faux implements HttpClientAdapter {
  final Map<String, Object> reponses;
  dynamic dernierCorps;

  _Faux(this.reponses);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    dernierCorps =
        options.data is String ? jsonDecode(options.data as String) : options.data;
    final corps = reponses[options.uri.path];
    if (corps == null) {
      return ResponseBody.fromString('{"erreur":"chemin non prévu par le test"}', 404,
          headers: {Headers.contentTypeHeader: ['application/json']});
    }
    return ResponseBody.fromString(jsonEncode(corps), 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }
}
