// src: lib/data/services/tachpay_service.dart
//
// Service TachPay — paiement mobile money côté étudiant.
//
// Consomme les endpoints existants du backend (TachPayController) : aucun
// mapping nouveau. Le flux complet :
//   1. checkoutContext()  → étudiant + frais à payer + total (1 appel)
//   2. operateurs()       → moyens mobile money ACTIFS de l'université
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

/// Un opérateur mobile money actif de l'université.
class OperateurMobile {
  final String code;
  final String libelle;
  OperateurMobile({required this.code, required this.libelle});

  factory OperateurMobile.fromJson(Map<String, dynamic> j) => OperateurMobile(
        code: (j['code'] ?? '').toString(),
        libelle: (j['libelle'] ?? j['code'] ?? '').toString(),
      );
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

  dynamic _deballer(Response res) {
    final body = res.data;
    if (body is Map && body['erreur'] != null) {
      throw ApiException(body['erreur'].toString(), statusCode: res.statusCode);
    }
    return body is Map && body.containsKey('data') ? body['data'] : body;
  }

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
      final data = _deballer(res) as Map<String, dynamic>;
      final detail = (data['data'] as Map<String, dynamic>?) ?? data;
      final listeBrute = (data['frais'] as List?) ?? const [];

      return CheckoutContext(
        inscriptionId: FraisDu._entier(detail['inscriptionId']),
        matricule: (detail['matricule'] ?? '').toString(),
        nomComplet: '${detail['prenom'] ?? ''} ${detail['nom'] ?? ''}'.trim(),
        telephone: detail['telephone']?.toString(),
        universiteId: (detail['universiteId'] ?? '').toString(),
        universiteNom: (detail['universiteNom'] ?? '').toString(),
        frais: listeBrute.map((j) => FraisDu.fromJson(j as Map<String, dynamic>)).toList(),
        total: FraisDu._reel(data['total']),
      );
    } on DioException catch (e) {
      throw _erreurDio(e);
    }
  }

  /// Opérateurs mobile money actifs de l'université de l'étudiant.
  Future<List<OperateurMobile>> operateurs(String universiteId) async {
    try {
      final res = await dio.get(ApiEndpoints.moyensPaiementUniversite(universiteId));
      final data = _deballer(res);
      final ops = (data is Map ? data['operateurs'] : data) as List? ?? const [];
      return ops
          .whereType<Map>()
          .map((j) => OperateurMobile.fromJson(Map<String, dynamic>.from(j)))
          // Seuls les opérateurs avec un numéro configuré sont réellement
          // utilisables ; le backend peut en lister davantage.
          .toList();
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
