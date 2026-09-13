// src: lib/data/services/tachpay_service.dart
//
// Service TachPay — paiement mobile money côté étudiant.
//
// Consomme les endpoints existants du backend (TachPayController) : aucun
// mapping nouveau. Le flux complet :
//   1. checkoutContext()  → étudiant + frais à payer + total (1 appel)
//   2. moyensPaiement()   → opérateurs de l'université, leur numéro
//                          d'encaissement et l'état de la configuration
//   3. payerMobile()      → initie le paiement (statut PENDING, USSD poussé)
//   4. statutPaiement()   → polling jusqu'à SUCCESS/FAILED
//   5. genererBon()/telechargerBonPdf() → reçu officiel
//
// Le mode pilote du backend répond 503 sur les écritures tant que les
// opérateurs ne sont pas contractualisés : ApiException(503) est remontée
// telle quelle pour que l'UI affiche « paiements bientôt disponibles ».

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/api_endpoints.dart';
import 'appel_api.dart' show deballerReponse;


class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.message, {this.statusCode});

  /// Vrai si le backend tourne en mode pilote (paiements refusés).
  bool get estModePilote => statusCode == 503;

  @override
  String toString() => message;
}

/// Un frais dû, tel que renvoyé par le checkout context.
class FraisDu {
  final int affectationId;
  final String libelle;
  final double montant;
  final double reste;
  final String? dateEcheance;

  FraisDu({
    required this.affectationId,
    required this.libelle,
    required this.montant,
    required this.reste,
    this.dateEcheance,
  });

  factory FraisDu.fromJson(Map<String, dynamic> j) => FraisDu(
        // L'id d'affectation porte plusieurs noms selon la source
        // (`id`, `affectationId`, `affectation_id`) : tout accepter évite
        // une sélection silencieuse vide au paiement.
        affectationId: _entier(j['affectationId'] ?? j['id'] ?? j['affectation_id']),
        libelle: (j['libelle'] ?? j['fraisLibelle'] ?? j['designation'] ?? 'Frais') .toString(),
        montant: _reel(j['montant']),
        reste: _reel(j['reste'] ?? j['montantReste'] ?? j['montant']),
        dateEcheance: j['dateEcheance']?.toString() ?? j['dateLimite']?.toString(),
      );

  static int _entier(Object? v) =>
      v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);

  static double _reel(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

/// Contexte de checkout : qui paie, quoi, et combien.
class CheckoutContext {
  final int inscriptionId;
  final String matricule;
  final String nomComplet;
  final String? telephone;
  final String universiteId;
  final String universiteNom;
  final List<FraisDu> frais;
  final double total;

  CheckoutContext({
    required this.inscriptionId,
    required this.matricule,
    required this.nomComplet,
    this.telephone,
    required this.universiteId,
    required this.universiteNom,
    required this.frais,
    required this.total,
  });
}

/// Un opérateur mobile money de l'université.
///
/// `numero` est le NUMÉRO D'ENCAISSEMENT : le compte marchand sur lequel
/// l'argent de cet établissement arrive. Il était jeté à la lecture, alors que
/// le serveur le renvoie et qu'il est fait pour être communiqué — c'est lui
/// qu'un étudiant recopie pour verser depuis son téléphone.
class OperateurMobile {
  final String code;
  final String libelle;
  final String? numero;

  const OperateurMobile({required this.code, required this.libelle, this.numero});

  /// L'établissement a-t-il publié le compte sur lequel il encaisse ?
  bool get aUnNumeroDEncaissement => (numero ?? '').trim().isNotEmpty;

  factory OperateurMobile.fromJson(Map<String, dynamic> j) {
    final numero = (j['numero'] ?? j['numeroCompte'] ?? '').toString().trim();
    return OperateurMobile(
      code: (j['code'] ?? '').toString(),
      libelle: (j['libelle'] ?? j['code'] ?? '').toString(),
      numero: numero.isEmpty ? null : numero,
    );
  }

  /// Les quatre opérateurs que le serveur sait initier.
  ///
  /// Recopiés de `MoyensPaiementService.operateursDe` et du `switch` de
  /// `ResolveurCompteEncaissement` : ce sont les seuls codes qu'une initiation
  /// accepte, tout autre valant « OPERATEUR_INCONNU ». Ils servent quand
  /// l'établissement n'a encore rien publié — l'écran reste alors parcourable
  /// jusqu'au bout, et c'est le serveur qui prononce le refus.
  static const List<OperateurMobile> connus = [
    OperateurMobile(code: 'VODACOM', libelle: 'M-Pesa (Vodacom)'),
    OperateurMobile(code: 'ORANGE', libelle: 'Orange Money'),
    OperateurMobile(code: 'AIRTEL', libelle: 'Airtel Money'),
    OperateurMobile(code: 'AFRIMONEY', libelle: 'AfriMoney'),
  ];
}

/// Les moyens de paiement d'un établissement, et leur état réel.
///
/// ── Pourquoi cette classe existe ──────────────────────────────────────────
///
/// Le service ne rendait qu'une liste d'opérateurs, en jetant les deux champs
/// qui disent si l'on peut payer : `configure` (l'établissement a-t-il
/// enregistré ses coordonnées) et `paiementEnLigneActif` (l'initiation directe
/// chez l'opérateur est-elle ouverte). Sans eux, l'écran ne pouvait pas
/// distinguer « aucun opérateur » de « opérateurs connus mais encaissement pas
/// encore ouvert », et affichait la même impasse dans les deux cas.
class MoyensPaiement {
  final List<OperateurMobile> operateurs;
  final bool configure;
  final bool paiementEnLigneActif;

  const MoyensPaiement({
    required this.operateurs,
    required this.configure,
    required this.paiementEnLigneActif,
  });

  const MoyensPaiement.aucun()
      : operateurs = const [],
        configure = false,
        paiementEnLigneActif = false;

  /// Aucun compte d'encaissement publié : le paiement sera refusé au serveur.
  bool get sansNumeroDEncaissement =>
      !operateurs.any((o) => o.aUnNumeroDEncaissement);
}

/// Résultat de l'initiation d'un paiement.
class PaiementInitie {
  final int paiementId;
  final String reference;
  final double montant;
  final String status;
  final String message;
  PaiementInitie({
    required this.paiementId,
    required this.reference,
    required this.montant,
    required this.status,
    required this.message,
  });

  bool get enAttente => status.toUpperCase() == 'PENDING'
      || status.toUpperCase() == 'EN_ATTENTE'
      || status.toUpperCase() == 'INITIE';
  bool get succes => status.toUpperCase() == 'SUCCESS'
      || status.toUpperCase() == 'SUCCES';
  bool get echoue => status.toUpperCase() == 'FAILED'
      || status.toUpperCase() == 'ECHEC'
      || status.toUpperCase() == 'ANNULE';
}

/// Bon de paiement généré.
class BonDePaiementInfo {
  final String numero;
  final double montant;
  final String dateGeneration;
  BonDePaiementInfo({
    required this.numero,
    required this.montant,
    required this.dateGeneration,
  });

  factory BonDePaiementInfo.fromJson(Map<String, dynamic> j) => BonDePaiementInfo(
        numero: (j['numero'] ?? j['numeroBon'] ?? '').toString(),
        montant: FraisDu._reel(j['montant']),
        dateGeneration: (j['dateGeneration'] ?? j['date'] ?? '').toString(),
      );
}

class TachPayService {
  final Dio dio;
  TachPayService(this.dio);

  /// Corps de la réponse, après contrôle du motif d'erreur.
  ///
  /// Ne déballe RIEN : le déballage est le geste de `_deballer`, et il ne
  /// convient pas à toutes les réponses — voir `checkoutContext`.
  dynamic _corps(Response res) {
    final body = res.data;
    if (body is Map && body['erreur'] != null) {
      throw ApiException(body['erreur'].toString(), statusCode: res.statusCode);
    }
    return body;
  }

  /// Corps utile d'une réponse enveloppée dans `ApiResponse`.
  ///
  /// ⚠ La règle locale était « s'il y a une clé `data`, c'est l'enveloppe » —
  /// et elle a fait disparaître la liste des frais. Le contexte de checkout
  /// porte en effet un MEMBRE `data` (l'identité de l'étudiant) À CÔTÉ de
  /// `frais`, `total` et `inscriptionId` : déballer sur ce seul indice rendait
  /// l'identité et jetait tout le reste. L'écran s'ouvrait alors sur
  /// « Sélectionnez les frais à payer » avec RIEN à cocher, un total de 0, et
  /// le bouton « Continuer » désactivé — le parcours mourait à son premier
  /// écran, sans message. On s'aligne donc sur `deballerReponse`, qui exige
  /// `success` ou une enveloppe courte (cf. `appel_api.dart`).
  dynamic _deballer(Response res) => deballerReponse(_corps(res));

  Never _erreurDio(DioException e) {
    final code = e.response?.statusCode;
    final msg = e.response?.data is Map
        ? (e.response!.data['erreur']?.toString() ??
            e.response!.data['message']?.toString() ??
            'Erreur serveur')
        : 'Serveur injoignable — vérifiez votre connexion';
    throw ApiException(msg, statusCode: code);
  }

  /// Contexte complet : étudiant + liste des frais + total.
  Future<CheckoutContext> checkoutContext() async {
    try {
      final res = await dio.get(ApiEndpoints.tachpayCheckoutContext);
      // Pas de déballage ici : `data` est un membre de cette réponse, pas une
      // enveloppe. Le lire comme telle vidait l'écran (voir `_deballer`).
      final data = Map<String, dynamic>.from(_corps(res) as Map);
      final detail = (data['data'] as Map<String, dynamic>?) ?? data;
      final listeBrute = (data['frais'] as List?) ?? const [];
      final fraisDus =
          listeBrute.map((j) => FraisDu.fromJson(j as Map<String, dynamic>)).toList();

      return CheckoutContext(
        inscriptionId: FraisDu._entier(detail['inscriptionId']),
        matricule: (detail['matricule'] ?? '').toString(),
        nomComplet: '${detail['prenom'] ?? ''} ${detail['nom'] ?? ''}'.trim(),
        telephone: detail['telephone']?.toString(),
        universiteId: (detail['universiteId'] ?? '').toString(),
        universiteNom: (detail['universiteNom'] ?? '').toString(),
        frais: fraisDus,
        total: _montantDu(data, fraisDus),
      );
    } on DioException catch (e) {
      throw _erreurDio(e);
    }
  }

  /// Montant réellement dû.
  ///
  /// ⚠ `total` du serveur est un NOMBRE DE LIGNES, pas une somme
  /// (`getFraisAPayer` pose `total = frais.size()`). Le lire comme un montant
  /// affichait « 3 USD » à un étudiant qui devait trois frais de plusieurs
  /// centaines de dollars — et cela sur le bandeau « Total dû », en tête de
  /// l'écran de paiement. On prend `montantTotal` quand le serveur l'expose, et
  /// sinon on additionne les restes : jamais `total`.
  static double _montantDu(Map<String, dynamic> data, List<FraisDu> frais) {
    final montant = data['montantTotal'];
    if (montant != null) return FraisDu._reel(montant);
    return frais.fold<double>(0, (somme, f) => somme + f.reste);
  }

  /// Moyens de paiement de l'université de l'étudiant, et leur état réel.
  ///
  /// Le serveur ne liste un opérateur que si un numéro OU un code marchand lui
  /// est connu (`MoyensPaiementService.operateursDe`). Une liste vide veut donc
  /// dire « cet établissement n'a encore publié aucun compte d'encaissement » —
  /// ce n'est pas une panne, et l'écran ne doit pas le présenter comme telle.
  Future<MoyensPaiement> moyensPaiement(String universiteId) async {
    try {
      final res = await dio.get(ApiEndpoints.moyensPaiementUniversite(universiteId));
      final data = _deballer(res);
      final carte = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final ops = (carte['operateurs'] as List?) ?? const [];
      return MoyensPaiement(
        operateurs: ops
            .whereType<Map>()
            .map((j) => OperateurMobile.fromJson(Map<String, dynamic>.from(j)))
            .toList(),
        configure: carte['configure'] == true,
        paiementEnLigneActif: carte['paiementEnLigneActif'] == true,
      );
    } on DioException catch (e) {
      throw _erreurDio(e);
    }
  }

  /// Initie un paiement mobile money pour les affectations cochées.
  Future<PaiementInitie> payerMobile({
    required List<int> affectationIds,
    required String telephone,
    required String operateur,
  }) async {
    try {
      final res = await dio.post(ApiEndpoints.tachpayPayerMobile, data: {
        'affectationIds': affectationIds,
        'telephone': telephone,
        'operateur': operateur,
      });
      final data = _deballer(res) as Map<String, dynamic>;
      return PaiementInitie(
        paiementId: FraisDu._entier(data['paiementId']),
        reference: (data['reference'] ?? '').toString(),
        montant: FraisDu._reel(data['montant']),
        status: (data['status'] ?? 'PENDING').toString(),
        message: (data['message'] ?? 'Paiement initié').toString(),
      );
    } on DioException catch (e) {
      throw _erreurDio(e);
    }
  }

  /// Statut courant d'un paiement (à appeler en polling).
  Future<PaiementInitie> statutPaiement(String reference) async {
    try {
      final res = await dio.get(ApiEndpoints.tachpayStatutPaiement(reference));
      final data = _deballer(res) as Map<String, dynamic>;
      return PaiementInitie(
        paiementId: FraisDu._entier(data['paiementId']),
        reference: reference,
        montant: FraisDu._reel(data['montant']),
        status: (data['status'] ?? data['statut'] ?? '').toString(),
        message: (data['message'] ?? '').toString(),
      );
    } on DioException catch (e) {
      throw _erreurDio(e);
    }
  }

  /// Génère un bon de paiement pour les affectations réglées et renvoie
  /// ses métadonnées (numéro notamment).
  Future<List<BonDePaiementInfo>> genererBon(List<int> affectationIds) async {
    try {
      final res = await dio.post(ApiEndpoints.tachpayBonPaiement, data: affectationIds);
      final data = _deballer(res);
      final liste = data is List ? data : ((data as Map)['bons'] as List? ?? const []);
      return liste
          .whereType<Map>()
          .map((j) => BonDePaiementInfo.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } on DioException catch (e) {
      throw _erreurDio(e);
    }
  }

  /// Télécharge le PDF d'un bon (octets bruts, à écrire dans un fichier).
  Future<List<int>> telechargerBonPdf(String numero) async {
    try {
      final res = await dio.get(ApiEndpoints.tachpayBonPdf(numero),
          options: Options(responseType: ResponseType.bytes));
      return (res.data as List).cast<int>();
    } on DioException catch (e) {
      throw _erreurDio(e);
    }
  }

  // ── helpers ──────────────────────────────────────────────────
  static void debugLog(String m) => debugPrint('[TachPay] $m');
}
