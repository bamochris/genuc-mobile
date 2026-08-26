import 'package:dio/dio.dart';

import '../../core/errors/api_exception.dart';
import '../../core/utils/dio_client.dart';

/// Enregistrement JSON générique, avec lecture tolérante.
///
/// Les portails web consomment la plupart des listes du backend sans DTO
/// dédié (`res.data.map(p => p.titre)`) : les créer tous en Dart aurait
/// multiplié par trois le volume de code sans rien garantir de plus — le
/// serveur n'a pas de schéma figé sur ces routes. [Fiche] rend cet accès sûr :
/// un champ absent ou d'un autre type ne fait pas planter l'écran, il rend une
/// valeur vide, exactement comme `undefined` côté React.
class Fiche {
  final Map<String, dynamic> donnees;

  const Fiche(this.donnees);

  factory Fiche.depuis(dynamic json) {
    if (json is Map<String, dynamic>) return Fiche(json);
    if (json is Map) return Fiche(Map<String, dynamic>.from(json));
    return const Fiche({});
  }

  dynamic operator [](String cle) => donnees[cle];

  bool contient(String cle) => donnees.containsKey(cle);

  /// Première valeur non vide parmi [cles] : le backend nomme le même champ
  /// `titre` ou `nom` selon la route.
  String texte(String cle, {String defaut = '', List<String> alias = const []}) {
    for (final c in [cle, ...alias]) {
      final v = donnees[c];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty && s != 'null') return s;
    }
    return defaut;
  }

  String? texteOuNul(String cle, {List<String> alias = const []}) {
    final v = texte(cle, alias: alias);
    return v.isEmpty ? null : v;
  }

  int entier(String cle, {int defaut = 0, List<String> alias = const []}) {
    for (final c in [cle, ...alias]) {
      final v = donnees[c];
      if (v is int) return v;
      if (v is num) return v.round();
      if (v is String) {
        final n = int.tryParse(v) ?? double.tryParse(v)?.round();
        if (n != null) return n;
      }
    }
    return defaut;
  }

  double decimal(String cle,
      {double defaut = 0, List<String> alias = const []}) {
    for (final c in [cle, ...alias]) {
      final v = donnees[c];
      if (v is num) return v.toDouble();
      if (v is String) {
        final n = double.tryParse(v.replaceAll(',', '.'));
        if (n != null) return n;
      }
    }
    return defaut;
  }

  double? decimalOuNul(String cle, {List<String> alias = const []}) {
    for (final c in [cle, ...alias]) {
      final v = donnees[c];
      if (v is num) return v.toDouble();
      if (v is String && v.trim().isNotEmpty) {
        final n = double.tryParse(v.replaceAll(',', '.'));
        if (n != null) return n;
      }
    }
    return null;
  }

  bool booleen(String cle, {bool defaut = false, List<String> alias = const []}) {
    for (final c in [cle, ...alias]) {
      final v = donnees[c];
      if (v is bool) return v;
      if (v is String) {
        if (v.toLowerCase() == 'true') return true;
        if (v.toLowerCase() == 'false') return false;
      }
      if (v is num) return v != 0;
    }
    return defaut;
  }

  DateTime? date(String cle, {List<String> alias = const []}) {
    for (final c in [cle, ...alias]) {
      final v = donnees[c];
      if (v is String && v.isNotEmpty) {
        final d = DateTime.tryParse(v);
        if (d != null) return d;
      }
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    }
    return null;
  }

  /// Identifiant, quel que soit son type d'origine (int côté JPA, String
  /// côté UUID).
  String get id => texte('id', alias: const ['identifiant', 'uuid']);

  Fiche sousFiche(String cle) => Fiche.depuis(donnees[cle]);

  List<Fiche> liste(String cle) {
    final v = donnees[cle];
    if (v is List) return v.map(Fiche.depuis).toList();
    return const [];
  }

  List<String> listeTextes(String cle) {
    final v = donnees[cle];
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }
}

/// Socle des services : centralise l'appel HTTP et la conversion d'erreur.
///
/// Sans lui, chaque méthode répétait douze lignes de `try / statusCode /
/// ApiException` — et l'une d'elles finissait toujours par oublier le `catch`,
/// laissant remonter une `DioException` brute jusqu'à l'écran.
abstract class ServiceApi {
  final Dio dio;

  ServiceApi(DioClient client) : dio = client.dio;

  Future<T> _executer<T>(
    Future<Response<dynamic>> Function() appel,
    T Function(dynamic donnees) transformer,
    String contexte,
  ) async {
    try {
      final reponse = await appel();
      final code = reponse.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        return transformer(reponse.data);
      }
      throw ApiException(contexte, statusCode: code);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Liste de fiches. Accepte aussi bien `[...]` que
  /// `{content: [...]}` (pagination Spring) ou `{data: [...]}` (ApiResponse).
  Future<List<Fiche>> listeDe(
    String chemin, {
    Map<String, dynamic>? parametres,
    String contexte = 'Chargement impossible',
  }) {
    return _executer(
      () => dio.get(chemin, queryParameters: parametres),
      _extraireListe,
      contexte,
    );
  }

  Future<Fiche> ficheDe(
    String chemin, {
    Map<String, dynamic>? parametres,
    String contexte = 'Chargement impossible',
  }) {
    return _executer(
      () => dio.get(chemin, queryParameters: parametres),
      (d) => Fiche.depuis(_deballer(d)),
      contexte,
    );
  }

  Future<Fiche> poster(
    String chemin, {
    dynamic corps,
    Map<String, dynamic>? parametres,
    String contexte = 'Enregistrement impossible',
  }) {
    return _executer(
      () => dio.post(chemin, data: corps, queryParameters: parametres),
      (d) => Fiche.depuis(_deballer(d)),
      contexte,
    );
  }

  Future<Fiche> mettreAJour(
    String chemin, {
    dynamic corps,
    Map<String, dynamic>? parametres,
    String contexte = 'Mise à jour impossible',
  }) {
    return _executer(
      () => dio.put(chemin, data: corps, queryParameters: parametres),
      (d) => Fiche.depuis(_deballer(d)),
      contexte,
    );
  }

  Future<Fiche> corriger(
    String chemin, {
    dynamic corps,
    Map<String, dynamic>? parametres,
    String contexte = 'Mise à jour impossible',
  }) {
    return _executer(
      () => dio.patch(chemin, data: corps, queryParameters: parametres),
      (d) => Fiche.depuis(_deballer(d)),
      contexte,
    );
  }

  Future<void> supprimer(
    String chemin, {
    Map<String, dynamic>? parametres,
    String contexte = 'Suppression impossible',
  }) {
    return _executer(
      () => dio.delete(chemin, queryParameters: parametres),
      (_) {},
      contexte,
    );
  }

  /// Télécharge un fichier en mémoire (PDF, Excel) pour l'ouvrir ou le
  /// partager ensuite.
  Future<List<int>> octetsDe(
    String chemin, {
    Map<String, dynamic>? parametres,
    String contexte = 'Téléchargement impossible',
  }) {
    return _executer(
      () => dio.get<List<int>>(
        chemin,
        queryParameters: parametres,
        options: Options(responseType: ResponseType.bytes),
      ),
      (d) => (d as List).cast<int>(),
      contexte,
    );
  }

  /// Les routes récentes répondent `ApiResponse{success, data}` tandis que les
  /// anciennes rendent l'objet nu : les deux formes coexistent dans le backend
  /// (voir `dto/ApiResponse.java`).
  static dynamic _deballer(dynamic donnees) {
    if (donnees is Map && donnees.containsKey('data') && donnees.length <= 4) {
      final interne = donnees['data'];
      if (interne is Map || interne is List) return interne;
    }
    return donnees;
  }

  static List<Fiche> _extraireListe(dynamic donnees) {
    final utile = _deballer(donnees);
    if (utile is List) return utile.map(Fiche.depuis).toList();
    if (utile is Map) {
      for (final cle in ['content', 'items', 'resultats', 'liste']) {
        final v = utile[cle];
        if (v is List) return v.map(Fiche.depuis).toList();
      }
    }
    return const [];
  }
}
