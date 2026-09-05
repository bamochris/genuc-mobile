import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/data/models/etudiant/cours.dart';

/// La barre de progression mesure ce que le PROFESSEUR a ouvert.
///
/// ── La règle ──────────────────────────────────────────────────────────────
///
/// Le professeur avance un curseur : « ouvert jusqu'à la leçon N ». Ce qui est
/// au-delà reste lisible — l'étudiant peut prendre de l'avance — mais ne compte
/// ni au numérateur ni au dénominateur.
///
/// ── Pourquoi ce test ──────────────────────────────────────────────────────
///
/// L'écran affichait « Leçons (2/12) » : le dénominateur était la totalité du
/// cours. Un étudiant ayant fait tout ce qu'on lui demandait se croyait en
/// retard de dix leçons. Le défaut ne lève rien — c'est un compte juste sur le
/// mauvais ensemble.
///
/// Le même calcul est verrouillé côté serveur par
/// `ProgressionSurLeconsOuvertesTest` : les deux doivent dire le même chiffre,
/// sinon la barre saute d'un écran à l'autre.
void main() {
  Map<String, dynamic> lecon(int ordre, {bool ouverte = true, bool faite = false}) => {
        'id': ordre,
        'titre': 'Leçon $ordre',
        'type': 'TEXTE',
        'ordre': ordre,
        'ouverte': ouverte,
        'estCompletee': faite,
      };

  /// Charge utile de `GET /api/etudiant/portal/{id}/cours/{coursId}`.
  CoursDetail detail({
    required int total,
    required int ouvertesJusquA,
    required Set<int> faites,
    int? leconsOuvertes,
  }) {
    return CoursDetail.fromJson({
      'cours': {'id': 8, 'titre': 'Algorithmique'},
      'progression': 0,
      if (leconsOuvertes != null) 'leconsOuvertes': leconsOuvertes,
      'lecons': [
        for (var i = 1; i <= total; i++)
          lecon(i, ouverte: i <= ouvertesJusquA, faite: faites.contains(i)),
      ],
    });
  }

  test('le dénominateur est ce que le professeur a ouvert', () {
    final d = detail(total: 12, ouvertesJusquA: 2, faites: {1, 2}, leconsOuvertes: 2);
    expect(d.leconsOuvertes, 2);
    expect(d.leconsCompletees, 2);
    expect(d.totalLecons, 12, reason: 'le cours entier reste consultable');
  });

  test('ce qui est lu en avance ne compte pas', () {
    // Il a fait les deux ouvertes ET trois leçons en avance : le compte reste
    // 2/2. La barre ne récompense pas l'avance, et surtout ne la reproche pas.
    final d = detail(
      total: 12,
      ouvertesJusquA: 2,
      faites: {1, 2, 5, 6, 7},
      leconsOuvertes: 2,
    );
    expect(d.leconsCompletees, 2);
    expect(d.leconsOuvertes, 2);
  });

  test('sans le compte du serveur, il se déduit des leçons ouvertes', () {
    // Repli : un serveur qui ne renvoie pas encore `leconsOuvertes` ne doit pas
    // faire retomber l'écran sur « tout le cours ».
    final d = detail(total: 12, ouvertesJusquA: 4, faites: {1});
    expect(d.leconsOuvertes, 4);
    expect(d.leconsCompletees, 1);
  });

  test('une réponse sans `ouverte` vaut tout ouvert', () {
    // Serveur pas encore à jour : on n'invente pas une restriction qu'il n'a
    // pas exprimée, sinon l'écran fermerait un cours que rien ne ferme.
    final d = CoursDetail.fromJson({
      'cours': {'id': 8, 'titre': 'Algorithmique'},
      'progression': 50,
      'lecons': [
        {'id': 1, 'titre': 'A', 'type': 'TEXTE', 'ordre': 1, 'estCompletee': true},
        {'id': 2, 'titre': 'B', 'type': 'TEXTE', 'ordre': 2, 'estCompletee': false},
      ],
    });
    expect(d.leconsOuvertes, 2);
    expect(d.leconsCompletees, 1);
  });
}
