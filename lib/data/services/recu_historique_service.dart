// lib/data/services/recu_historique_service.dart
//
// Service de persistance locale pour l'historique des reçus/bons de paiement.
// Utilise shared_preferences pour stocker les métadonnées (pas les PDF eux-mêmes).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/formatters.dart';

/// Métadonnées d'un reçu/bon de paiement stocké localement.
class RecuHistorique {
  final String numero;
  final double montant;
  final String dateGeneration;
  final String type; // 'bon' ou 'recu'
  final String? referencePaiement;
  final List<int> affectationIds;
  final DateTime dateAjout;

  RecuHistorique({
    required this.numero,
    required this.montant,
    required this.dateGeneration,
    required this.type,
    this.referencePaiement,
    required this.affectationIds,
    required this.dateAjout,
  });

  factory RecuHistorique.fromJson(Map<String, dynamic> json) => RecuHistorique(
        numero: json['numero'] as String,
        montant: (json['montant'] as num).toDouble(),
        dateGeneration: json['dateGeneration'] as String,
        type: json['type'] as String,
        referencePaiement: json['referencePaiement'] as String?,
        affectationIds: (json['affectationIds'] as List?)
                ?.map((e) => e as int)
                .toList() ??
            const [],
        dateAjout: DateTime.parse(json['dateAjout'] as String),
      );

  Map<String, dynamic> toJson() => {
        'numero': numero,
        'montant': montant,
        'dateGeneration': dateGeneration,
        'type': type,
        'referencePaiement': referencePaiement,
        'affectationIds': affectationIds,
        'dateAjout': dateAjout.toIso8601String(),
      };

  String get montantFormate => formatMontant(montant);
  String get dateAjoutFormate => formatDate(dateAjout.toIso8601String());
  String get libelleType => type == 'bon' ? 'Bon de caisse' : 'Reçu de paiement';
  String get iconeType => type == 'bon' ? '📄' : '✅';
}

class RecuHistoriqueService {
  static const String _clePrefs = 'recu_historique';
  static const int _maxElements = 100; // Limite pour éviter que le storage grossisse trop

  /// Ajoute un reçu/bon à l'historique local.
  static Future<void> ajouter(RecuHistorique recu) async {
    final prefs = await SharedPreferences.getInstance();
    final liste = await _chargerListe(prefs);

    // Évite les doublons (même numéro)
    liste.removeWhere((r) => r.numero == recu.numero);

    // Ajoute en tête (plus récent en premier)
    liste.insert(0, recu);

    // Tronque si trop d'éléments
    if (liste.length > _maxElements) {
      liste.removeRange(_maxElements, liste.length);
    }

    await _sauvegarderListe(prefs, liste);
  }

  /// Récupère tout l'historique (plus récent en premier).
  static Future<List<RecuHistorique>> obtenirTous() async {
    final prefs = await SharedPreferences.getInstance();
    return _chargerListe(prefs);
  }

  /// Récupère un reçu par son numéro.
  static Future<RecuHistorique?> obtenirParNumero(String numero) async {
    final liste = await obtenirTous();
    try {
      return liste.firstWhere((r) => r.numero == numero);
    } catch (_) {
      return null;
    }
  }

  /// Supprime un reçu de l'historique.
  static Future<void> supprimer(String numero) async {
    final prefs = await SharedPreferences.getInstance();
    final liste = await _chargerListe(prefs);
    liste.removeWhere((r) => r.numero == numero);
    await _sauvegarderListe(prefs, liste);
  }

  /// Vide tout l'historique.
  static Future<void> toutSupprimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clePrefs);
  }

  static Future<List<RecuHistorique>> _chargerListe(SharedPreferences prefs) async {
    final jsonString = prefs.getString(_clePrefs);
    if (jsonString == null || jsonString.isEmpty) return const [];

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RecuHistorique.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _sauvegarderListe(
    SharedPreferences prefs,
    List<RecuHistorique> liste,
  ) async {
    final jsonString = jsonEncode(liste.map((r) => r.toJson()).toList());
    await prefs.setString(_clePrefs, jsonString);
  }
}