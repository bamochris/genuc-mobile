/// Formatage des montants et des dates, aligné sur `utils/montant.js` du
/// portail web.
library;

/// Devise employée quand ni la donnée ni l'établissement n'en portent.
///
/// C'est un repli DÉCLARÉ, pas une supposition : le dollar est la devise de
/// facturation dominante dans l'enseignement supérieur congolais. Même valeur
/// et même raison que `DEVISE_PAR_DEFAUT` du portail web.
const String deviseParDefaut = 'USD';

/// Symboles d'usage — le franc congolais s'écrit « FC » et non « CDF ».
const Map<String, String> _symbolesDevise = {
  'USD': 'USD',
  'CDF': 'FC',
  'EUR': 'EUR',
};

/// Décimales usuelles. Le franc congolais ne se subdivise pas en pratique.
const Map<String, int> _decimalesDevise = {'USD': 2, 'EUR': 2, 'CDF': 0};

/// Devise de facturation de l'établissement connecté, **telle que le serveur
/// la donne** (`GET /api/universites/public/{id}` → `devise`).
///
/// ─── Pourquoi ce relais existe ──────────────────────────────────────────────
///
/// `formatMontant` écrivait « USD » en dur pour tout montant dont la donnée ne
/// portait pas de devise — soit seize écrans sur vingt-deux, dont « Mes
/// paiements », le flux TachPay et le bon de caisse. Un établissement qui
/// facture en francs congolais annonçait donc « 420 000 USD » à ses étudiants.
/// L'entité `Universite` porte pourtant un champ `devise` (« USD », « CDF »,
/// « USD/CDF »), que le portail web lit depuis toujours via `useDevise()`.
///
/// Le portail web résout la devise écran par écran, avec un hook. Le mobile
/// appelle `formatMontant` depuis des widgets sans contexte : la devise de
/// l'établissement est donc déposée ICI, en un seul endroit, par
/// `DeviseProvider` — et par lui seul. Les écrans qui ont la devise dans leur
/// charge utile (`paiement.devise`, `frais.devise`) continuent de la passer :
/// c'est elle qui fait foi, un frais pouvant être libellé dans une autre
/// devise que celle de référence.
class DeviseEtablissement {
  DeviseEtablissement._();

  static String? _code;

  /// Devise résolue, ou `null` tant que le serveur n'a pas répondu.
  static String? get code => _code;

  /// Réservé à `DeviseProvider`. Une valeur vide efface, elle ne pose pas
  /// le repli : « pas encore connue » et « USD » ne se lisent pas pareil.
  static void definir(String? devise) {
    final propre = (devise ?? '').trim();
    _code = propre.isEmpty ? null : normaliserDevise(propre);
  }

  /// Oublie la devise — changement d'établissement ou fin de session.
  static void oublier() => _code = null;
}

/// Code de devise normalisé (majuscules, repli si vide).
///
/// Certains établissements renseignent « USD/CDF » pour dire qu'ils acceptent
/// les deux : on retient la première, qui est la devise de référence.
String normaliserDevise(String? devise) {
  final code = (devise ?? '').trim().toUpperCase();
  if (code.isEmpty) return deviseParDefaut;
  final premiere = code.split(RegExp(r'[/,\s]+')).firstWhere(
        (p) => p.isNotEmpty,
        orElse: () => deviseParDefaut,
      );
  return premiere;
}

/// Étiquette affichée pour une devise (symbole d'usage).
String etiquetteDevise(String? devise) {
  final code = normaliserDevise(devise);
  return _symbolesDevise[code] ?? code;
}

/// Formate un montant avec séparateur de milliers et devise.
///
/// Exemple : `1234567.5` + `USD` → `1 234 567,50 USD` ; `250000` + `CDF` →
/// `250 000 FC`.
///
/// [devise] absente ou vide : la devise de l'établissement
/// ([DeviseEtablissement]) si le serveur l'a donnée, sinon [deviseParDefaut].
/// Ne jamais écrire un code de devise en dur à l'appel.
String formatMontant(num montant, [String? devise]) {
  final code = normaliserDevise(
    (devise ?? '').trim().isNotEmpty ? devise : DeviseEtablissement.code,
  );
  final nbDecimales = _decimalesDevise[code] ?? 2;

  // `toStringAsFixed` arrondit et complète : « 420,05 » et non « 420,5 », que
  // l'ancien calcul `((valeur - entier) * 100).round()` produisait — il perdait
  // le zéro de tête des centimes, et rendait « 420,100 » pour 420,999.
  final fixe = montant.toDouble().abs().toStringAsFixed(nbDecimales);
  final parties = fixe.split('.');
  final entiere = parties.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]} ',
  );

  final signe = montant < 0 ? '-' : '';
  final corps = parties.length > 1 ? '$signe$entiere,${parties[1]}' : '$signe$entiere';
  return '$corps ${etiquetteDevise(code)}';
}

/// Formate une date ISO (`2026-08-10` ou `2026-08-10T14:30:00`) en français.
String formatDate(String? iso, {bool avecHeure = false}) {
  if (iso == null || iso.isEmpty) return '—';
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;

  final jour = date.day.toString().padLeft(2, '0');
  final mois = date.month.toString().padLeft(2, '0');
  final base = '$jour/$mois/${date.year}';
  if (!avecHeure) return base;

  final heure = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$base à $heure:$minute';
}

/// Formate une date déjà décodée. Pendant de [formatDate] pour les valeurs
/// tirées de `Fiche.date(...)`.
String formatDateObjet(DateTime? date, {bool avecHeure = false}) {
  if (date == null) return '—';
  final jour = date.day.toString().padLeft(2, '0');
  final mois = date.month.toString().padLeft(2, '0');
  final base = '$jour/$mois/${date.year}';
  if (!avecHeure) return base;

  final heure = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$base à $heure:$minute';
}

/// Date du jour au format attendu par les contrôleurs (`LocalDate`).
String dateIsoDuJour() => DateTime.now().toIso8601String().substring(0, 10);

// `anneeAcademiqueCourante()` a été RETIRÉE (09/09/2026).
//
// Elle déduisait l'année académique de l'horloge de l'appareil, et six écrans
// du portail enseignant la posaient telle quelle dans l'URL de leurs appels.
// Or l'année d'un établissement est une LIGNE de `annee_academique`, qu'il
// ouvre et ferme lui-même : deux établissements peuvent en avoir deux
// différentes le même jour, et aucun n'est tenu de nommer la sienne comme le
// calendrier le suppose. Un libellé calculé qui ne correspond à rien ne
// provoque pas d'erreur — il rend « aucune note », des rapports à zéro, et des
// enregistrements rattachés à un exercice que personne n'a ouvert.
//
// La source de vérité est `AnneesAcademiquesProvider`
// (`presentation/providers/annees_academiques_provider.dart`), qui lit le
// référentiel et n'utilise le calendrier qu'en dernier repli, sans jamais
// prétendre qu'une année est « en cours ».

/// Libellé lisible d'une mention, aligné sur `constants/mentions.js`.
String libelleMention(String? mention) {
  if (mention == null || mention.isEmpty) return '—';
  switch (mention.toUpperCase()) {
    case 'EXCELLENCE':
      return 'Excellence';
    case 'GRANDE_DISTINCTION':
    case 'GRANDE DISTINCTION':
      return 'Grande distinction';
    case 'DISTINCTION':
      return 'Distinction';
    case 'SATISFACTION':
      return 'Satisfaction';
    case 'PASSABLE':
      return 'Passable';
    case 'AJOURNE':
      return 'Ajourné';
    case 'ECHEC':
      return 'Échec';
    case 'SANS_MENTION':
      return 'Sans mention';
    default:
      return mention.replaceAll('_', ' ');
  }
}

/// Toute mention sauf AJOURNE est une réussite (règle du portail web).
bool estAjourne(String? mention) =>
    mention != null && mention.toUpperCase() == 'AJOURNE';
