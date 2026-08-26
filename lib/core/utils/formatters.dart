/// Formatage des montants et des dates, aligné sur `utils/montant.js` du
/// portail web.
library;

/// Formate un montant avec séparateur de milliers et devise.
///
/// Exemple : `1234567.5` + `USD` → `1 234 567,50 USD`.
String formatMontant(num montant, [String devise = 'USD']) {
  final valeur = montant.toDouble();
  final entier = valeur.truncate();
  final decimales = ((valeur - entier) * 100).round();
  final partieEntiere = entier
      .toString()
      .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]} ',
      );

  final corps = decimales > 0 ? '$partieEntiere,$decimales' : partieEntiere;
  return devise.isNotEmpty ? '$corps $devise' : corps;
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

/// Année académique en cours, déduite de la date : le portail bascule en
/// septembre, comme le calendrier universitaire congolais.
String anneeAcademiqueCourante() {
  final maintenant = DateTime.now();
  final debut = maintenant.month >= 9 ? maintenant.year : maintenant.year - 1;
  return '$debut-${debut + 1}';
}

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
