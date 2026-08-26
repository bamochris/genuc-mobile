import 'dart:async';

/// Cache en mémoire avec TTL (Time-To-Live) pour les données fréquentes.
///
/// M3 CORRIGÉ : le mobile n'avait aucun cache local. Chaque ouverture
/// rechargeait tout depuis le serveur, rendant l'inutilisable en cas de
/// mauvaise connexion (fréquent en RDC). Ce service met en cache les
/// réponses API pendant une durée configurable.
///
/// Usage :
/// ```dart
/// final cache = CacheService();
/// final data = await cache.getOrFetch(
///   key: 'emploi_du_temps_$inscriptionId',
///   ttl: const Duration(minutes: 30),
///   fetch: () => apiService.getHoraire(inscriptionId),
/// );
/// ```
class CacheService {
  final Map<String, _CacheEntry> _store = {};
  Timer? _cleanupTimer;

  CacheService() {
    // Nettoyage automatique des entrées expirées toutes les 5 minutes
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) => _cleanup());
  }

  /// Récupère une valeur du cache, ou la charge via [fetch] si absente/expirée.
  Future<T> getOrFetch<T>({
    required String key,
    required Duration ttl,
    required Future<T> Function() fetch,
  }) async {
    final entry = _store[key];
    if (entry != null && !entry.isExpired) {
      return entry.value as T;
    }

    final value = await fetch();
    _store[key] = _CacheEntry(value: value, expiresAt: DateTime.now().add(ttl));
    return value;
  }

  /// Met en cache une valeur directement.
  void put<T>(String key, T value, Duration ttl) {
    _store[key] = _CacheEntry(value: value, expiresAt: DateTime.now().add(ttl));
  }

  /// Récupère une valeur du cache (null si absente ou expirée).
  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null || entry.isExpired) return null;
    return entry.value as T;
  }

  /// Invalide une entrée spécifique.
  void invalidate(String key) {
    _store.remove(key);
  }

  /// Invalide toutes les entrées dont le préfixe correspond.
  void invalidatePrefix(String prefix) {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Vide tout le cache.
  void clear() {
    _store.clear();
  }

  void _cleanup() {
    _store.removeWhere((_, entry) => entry.isExpired);
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _store.clear();
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  _CacheEntry({required this.value, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// TTL prédéfinis pour les différents types de données.
class CacheTTL {
  static const Duration emploiDuTemps = Duration(minutes: 30);
  static const Duration cours = Duration(minutes: 15);
  static const Duration notes = Duration(minutes: 10);
  static const Duration notifications = Duration(minutes: 2);
  static const Duration profil = Duration(hours: 1);
  static const Duration situationFinanciere = Duration(minutes: 5);
  static const Duration Referentiel = Duration(hours: 6);
  static const Duration notificationsCount = Duration(seconds: 30);
}
