/// M7 : protège contre les NaN/Infinity dans les champs numériques
/// qui proviennent du backend (division par zéro, JSON null).
double _safeDouble(dynamic v) {
  if (v == null) return 0.0;
  final d = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
  if (d.isNaN || d.isInfinite) return 0.0;
  return d;
}

/// Modèle de données pour les paiements.
///
/// Correspond aux réponses de `FraisEtudiantService` :
/// - `getSituationFinanciere` → `{inscriptionId, matricule, etudiant,
///   totalAttendu, totalPaye, totalReste, pourcentage, estSolde, dettes,
///   paiements}` ;
/// - `getFraisAPayer` → liste de dettes `{id, fraisId, code, libelle,
///   montant, reste, paye, statut, dateEcheance, estEnRetard, type}` ;
/// - `getHistoriquePaiements` → liste `{id, reference, montant, devise,
///   datePaiement, dateValidation, modePaiement, type, statut, operateur,
///   numeroTransaction}`.
class Paiement {
  final int id;
  final String reference;
  final String type;
  final double montant;
  final String devise;
  final String datePaiement;
  final String statut; // VALIDE, EN_ATTENTE, REJETE, REMBOURSE...
  final String? modePaiement; // VODACOM, ORANGE, AIRTEL, CARTE, ESPECES...
  final String? operateur;
  final String? numeroTransaction;
  final String? description;

  Paiement({
    required this.id,
    required this.reference,
    required this.type,
    required this.montant,
    required this.devise,
    required this.datePaiement,
    required this.statut,
    this.modePaiement,
    this.operateur,
    this.numeroTransaction,
    this.description,
  });

  factory Paiement.fromJson(Map<String, dynamic> json) {
    return Paiement(
      id: json['id'] ?? 0,
      reference: json['reference'] ?? '',
      type: json['type'] ?? '',
      montant: _safeDouble(json['montant']),
      devise: json['devise'] ?? 'USD',
      datePaiement: json['datePaiement'] ?? json['date'] ?? '',
      statut: json['statut'] ?? 'EN_ATTENTE',
      modePaiement: json['modePaiement'] ?? json['methode'],
      operateur: json['operateur'],
      numeroTransaction: json['numeroTransaction'],
      description: json['description'],
    );
  }

  bool get estValide => statut == 'VALIDE';
  bool get estEnAttente => statut == 'EN_ATTENTE' || statut == 'PENDING';
  bool get estRejete => statut == 'REJETE';
  bool get estRembourse => statut == 'REMBOURSE';

  String get libelleStatut {
    switch (statut) {
      case 'VALIDE':
        return 'Validé';
      case 'EN_ATTENTE':
      case 'PENDING':
        return 'En attente';
      case 'REJETE':
        return 'Rejeté';
      case 'REMBOURSE':
        return 'Remboursé';
      default:
        return statut.replaceAll('_', ' ');
    }
  }

  String get libelleMode {
    if (modePaiement == null || modePaiement!.isEmpty) return '—';
    return modePaiement!.replaceAll('_', ' ');
  }
}

/// Un frais attribué à l'étudiant (dette). Correspond à un élément des listes
/// `dettes` (situation) ou `getFraisAPayer`.
class FraisAcademique {
  final int id;
  final String code;
  final String libelle;
  final double montant;
  final double montantPaye;
  final double reste;
  final String dateEcheance;
  final bool estEnRetard;
  final String statut; // EN_ATTENTE, PARTIEL, PAYE, ANNULE
  final String? type;

  FraisAcademique({
    required this.id,
    required this.code,
    required this.libelle,
    required this.montant,
    required this.montantPaye,
    required this.reste,
    required this.dateEcheance,
    required this.estEnRetard,
    required this.statut,
    this.type,
  });

  factory FraisAcademique.fromJson(Map<String, dynamic> json) {
    return FraisAcademique(
      id: json['id'] ?? 0,
      code: json['code'] ?? json['fraisCode'] ?? '',
      libelle: json['libelle'] ?? json['fraisLibelle'] ?? '',
      montant: _safeDouble(json['montant']),
      montantPaye: _safeDouble(json['paye'] ?? json['montantPaye']),
      reste: _safeDouble(json['reste']),
      dateEcheance: json['dateEcheance'] ?? '',
      estEnRetard: json['estEnRetard'] ?? false,
      statut: json['statut'] ?? 'EN_ATTENTE',
      type: json['type'],
    );
  }

  // M7 CORRIGÉ : protection contre la division par zéro et les NaN
  double get pourcentagePaye {
    if (montant <= 0) return 0.0;
    final ratio = montantPaye / montant;
    if (ratio.isNaN || ratio.isInfinite) return 0.0;
    return (ratio * 100).clamp(0.0, 100.0);
  }

  bool get estSolde => reste <= 0;
  bool get estPartiel => statut == 'PARTIEL';
}

/// Situation financière complète. Correspond à
/// `GET /api/etudiant/frais/situation` (`FraisEtudiantService.getSituationFinanciere`).
class SituationFinanciere {
  final int inscriptionId;
  final String matricule;
  final String etudiant;
  final double totalAttendu;
  final double totalPaye;
  final double totalReste;
  final double pourcentage;
  final bool estSolde;
  final List<FraisAcademique> dettes;
  final List<Paiement> paiements;

  SituationFinanciere({
    required this.inscriptionId,
    required this.matricule,
    required this.etudiant,
    required this.totalAttendu,
    required this.totalPaye,
    required this.totalReste,
    required this.pourcentage,
    required this.estSolde,
    required this.dettes,
    required this.paiements,
  });

  factory SituationFinanciere.fromJson(Map<String, dynamic> json) {
    // Tolérance pour les anciennes formes (`montantTotal`, `frais`...) : le
    // backend actuel renvoie `totalAttendu`/`dettes`, mais garder des
    // dégradations propres évite une régression si un proxy ou un cache
    // intermédiaire sert une forme plus ancienne.
    final dettes = (json['dettes'] as List?)
            ?.map((e) => FraisAcademique.fromJson(e as Map<String, dynamic>))
            .toList() ??
        (json['frais'] as List?)
            ?.map((e) => FraisAcademique.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final paiements = (json['paiements'] as List?)
            ?.map((e) => Paiement.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final attendu = _safeDouble(json['totalAttendu'] ?? json['montantTotal']);
    final paye = _safeDouble(json['totalPaye'] ?? json['montantPaye']);
    final reste = _safeDouble(json['totalReste'] ?? json['soldeRestant']);

    return SituationFinanciere(
      inscriptionId: (json['inscriptionId'] ?? 0).toInt(),
      matricule: json['matricule'] ?? '',
      etudiant: json['etudiant'] ?? '',
      totalAttendu: attendu,
      totalPaye: paye,
      totalReste: reste,
      pourcentage: _safeDouble(json['pourcentage']),
      estSolde: json['estSolde'] ?? reste <= 0,
      dettes: dettes,
      paiements: paiements,
    );
  }

  List<FraisAcademique> get fraisEnRetard =>
      dettes.where((f) => f.estEnRetard).toList();
}
