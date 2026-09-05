import '../../services/appel_api.dart';

/// Jusqu'ou l'enseignant est alle dans un support, en PAGES.
///
/// Le professeur depose son PDF une fois, puis avance seance apres seance :
/// « aujourd'hui, jusqu'a la page 28 ». L'etudiant voit cette borne et lit tout
/// le document — lire en avance ne transforme pas une page en page enseignee.
///
/// Le serveur renvoie l'objet `seance` sur chaque support ; il vaut `null` tant
/// qu'aucune borne n'a ete posee, et c'est l'etat de tous les supports deja en
/// ligne. Aucune restriction retroactive.
class SeanceSupport {
  /// Premiere page de la seance en cours.
  final int debut;

  /// Derniere page enseignee.
  final int fin;

  /// Total du document. `null` quand il est inconnu (non-PDF, comptage rate) :
  /// on affiche alors la borne sans pourcentage, jamais un chiffre invente.
  final int? nombrePages;

  /// Part enseignee, plafonnee a 100. `null` si le total est inconnu.
  final int? pourcentage;

  const SeanceSupport({
    required this.debut,
    required this.fin,
    this.nombrePages,
    this.pourcentage,
  });

  /// Lit la seance d'un support, ou rend `null` s'il n'y en a pas.
  ///
  /// `fin` absente ou nulle vaut « aucune seance delimitee » : c'est le seul
  /// champ qui decide, les autres ne sont que du detail d'affichage.
  static SeanceSupport? depuis(Fiche support) {
    final brut = support['seance'];
    if (brut is! Map) return null;
    final s = Fiche.depuis(brut);
    final fin = s.donnees['fin'];
    if (fin is! num || fin <= 0) return null;

    final total = s.donnees['nombrePages'];
    final pct = s.donnees['pourcentage'];
    final debut = s.donnees['debut'];
    return SeanceSupport(
      // Une borne sans debut connu commence a la premiere page : c'est le seul
      // repli qui ne ment pas.
      debut: debut is num ? debut.toInt() : 1,
      fin: fin.toInt(),
      nombrePages: total is num ? total.toInt() : null,
      pourcentage: pct is num ? pct.toInt().clamp(0, 100) : null,
    );
  }
}
