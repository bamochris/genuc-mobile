// La devise affichée vient du SERVEUR, plus du code.
//
// `formatMontant` retombait sur « USD » écrit en dur pour tout montant dont la
// charge utile ne portait pas de devise — seize appels sur vingt-deux, dont
// « Mes paiements », le flux TachPay, le bon de caisse et le solde du tableau
// de bord ; trois écrans concaténaient même « USD » à la main. L'entité
// `Universite` porte pourtant un champ `devise` (« USD », « CDF »,
// « USD/CDF »), que le portail web lit depuis toujours par `useDevise()`.
//
// Un établissement facturant en francs congolais annonçait donc des dollars à
// ses étudiants, sur ses écrans de paiement. Rien ne le signalait : un montant
// mal étiqueté s'affiche aussi bien qu'un montant juste.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/utils/formatters.dart';
import 'package:genuc_mobile/presentation/providers/devise_provider.dart';

void main() {
  // La devise de l'établissement est un état de session : chaque cas repart
  // d'une ardoise vierge, sinon l'ordre des tests changerait leur résultat.
  setUp(DeviseEtablissement.oublier);
  tearDown(DeviseEtablissement.oublier);

  group('Code de devise', () {
    test('« USD/CDF » retient la devise de référence', () {
      // Forme réellement saisie par des établissements qui acceptent les deux.
      expect(normaliserDevise('USD/CDF'), 'USD');
      expect(normaliserDevise('cdf / usd'), 'CDF');
    });

    test('vide ou absente vaut le repli déclaré', () {
      expect(normaliserDevise(null), deviseParDefaut);
      expect(normaliserDevise('   '), deviseParDefaut);
    });

    test('le franc congolais s\'affiche « FC »', () {
      // « CDF » est le code ISO ; « FC » est ce qui se lit sur un reçu en RDC.
      expect(etiquetteDevise('CDF'), 'FC');
      expect(etiquetteDevise('USD'), 'USD');
    });
  });

  group('Montants', () {
    test('les centimes ne perdent plus leur zéro de tête', () {
      // `((valeur - entier) * 100).round()` rendait « 420,5 » pour 420,05 et
      // « 420,100 » pour 420,999 : des montants faux sur un écran de paiement.
      expect(formatMontant(420.05, 'USD'), '420,05 USD');
      expect(formatMontant(420.999, 'USD'), '421,00 USD');
      expect(formatMontant(1234567.5, 'USD'), '1 234 567,50 USD');
    });

    test('le franc congolais ne se subdivise pas', () {
      expect(formatMontant(250000, 'CDF'), '250 000 FC');
    });

    test('un montant négatif garde son signe devant', () {
      expect(formatMontant(-1200, 'USD'), '-1 200,00 USD');
    });
  });

  group('Devise de l\'établissement', () {
    test('sans réponse du serveur, le repli déclaré s\'applique', () {
      // On ne rend pas un montant sans unité : c'est pire qu'un montant dans
      // la devise dominante. Même arbitrage que le portail web.
      expect(formatMontant(420), '420,00 USD');
    });

    test('elle sert de devise par défaut une fois lue', () {
      DeviseEtablissement.definir('CDF');
      expect(formatMontant(420), '420 FC');
    });

    test('la devise de la donnée l\'emporte sur celle de l\'établissement', () {
      // Un frais peut être libellé dans une autre devise que celle de
      // référence : c'est la ligne qui fait foi, jamais l'établissement.
      DeviseEtablissement.definir('CDF');
      expect(formatMontant(420, 'USD'), '420,00 USD');
    });

    test('une devise vide n\'efface pas la devise de l\'établissement', () {
      // `Paiement.devise` vaut « » quand `/situation` ne la sert pas : cela
      // veut dire « inconnue », pas « aucune ».
      DeviseEtablissement.definir('CDF');
      expect(formatMontant(420, ''), '420 FC');
    });
  });

  group('DeviseProvider', () {
    test('lit la devise au serveur pour l\'établissement de la session',
        () async {
      final demandes = <String>[];
      final provider = DeviseProvider.avecLecture((id) async {
        demandes.add(id);
        return 'CDF';
      });

      provider.suivreSession('7');
      await Future<void>.delayed(Duration.zero);

      expect(demandes, ['7']);
      expect(provider.devise, 'CDF');
      expect(provider.etiquette, 'FC');
      expect(provider.duServeur, isTrue);
      // Et la valeur est publiée pour les widgets sans contexte.
      expect(formatMontant(100), '100 FC');
    });

    test('un établissement sans devise déclarée garde le repli', () async {
      final provider = DeviseProvider.avecLecture((_) async => '');
      provider.suivreSession('7');
      await Future<void>.delayed(Duration.zero);

      expect(provider.devise, deviseParDefaut);
      expect(provider.duServeur, isFalse,
          reason: 'le repli ne doit pas se faire passer pour une déclaration');
    });

    test('un échec de lecture ne laisse pas un montant sans unité', () async {
      final provider = DeviseProvider.avecLecture(
        (_) async => throw Exception('réseau'),
      );
      provider.suivreSession('7');
      await Future<void>.delayed(Duration.zero);

      expect(provider.devise, deviseParDefaut);
      expect(provider.duServeur, isFalse);
    });

    test('changer de compte oublie la devise du précédent', () async {
      final provider = DeviseProvider.avecLecture(
        (id) async => id == '7' ? 'CDF' : 'USD',
      );

      provider.suivreSession('7');
      await Future<void>.delayed(Duration.zero);
      expect(formatMontant(100), '100 FC');

      // Poste partagé : sans cet oubli, le compte suivant lit ses montants
      // dans la devise du compte précédent, le temps de l'appel — et
      // indéfiniment si l'appel échoue.
      provider.suivreSession('9');
      expect(DeviseEtablissement.code, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(provider.devise, 'USD');
    });

    test('la déconnexion efface la devise', () async {
      final provider = DeviseProvider.avecLecture((_) async => 'CDF');
      provider.suivreSession('7');
      await Future<void>.delayed(Duration.zero);

      provider.suivreSession(null);
      expect(DeviseEtablissement.code, isNull);
      expect(provider.devise, deviseParDefaut);
    });

    test('une même session ne relit pas le serveur à chaque notification',
        () async {
      // Le proxy rappelle `suivreSession` à CHAQUE notification de
      // `AuthProvider` — rafraîchissement de profil, photo, second facteur.
      var appels = 0;
      final provider = DeviseProvider.avecLecture((_) async {
        appels++;
        return 'USD';
      });

      provider.suivreSession('7');
      provider.suivreSession('7');
      await Future<void>.delayed(Duration.zero);
      provider.suivreSession('7');
      await Future<void>.delayed(Duration.zero);

      expect(appels, 1);
    });

    test('une réponse en retard ne pose pas la devise d\'un compte quitté',
        () async {
      final lente = Completer<String>();
      final provider = DeviseProvider.avecLecture(
        (id) => id == '7' ? lente.future : Future.value('USD'),
      );

      provider.suivreSession('7');
      provider.suivreSession('9');
      await Future<void>.delayed(Duration.zero);
      lente.complete('CDF');
      await Future<void>.delayed(Duration.zero);

      expect(provider.devise, 'USD');
      expect(DeviseEtablissement.code, 'USD');
    });
  });
}
