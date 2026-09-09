import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/utils/cache_service.dart';
import '../models/smart_presence/attendance_models.dart';

class ApiService {
  final Dio dio;
  final CookieJar cookieJar;
  final CacheService _cache;

  ApiService({
    required this.dio,
    required this.cookieJar,
    CacheService? cache,
  }) : _cache = cache ?? CacheService();

  // ─── Authentification ──────────────────────────────────────

  /// [identifiant] est un email OU un matricule : le backend résout les deux.
  /// Il n'est donc pas mis en minuscules — les matricules sont majoritairement
  /// en majuscules et la casse peut compter à la résolution.
  Future<Map<String, dynamic>> login({
    required String identifiant,
    required String password,
  }) async {
    return _post(
      ApiEndpoints.login,
      data: {
        'email': identifiant.trim(),
        'motDePasse': password,
      },
    );
  }

  Future<Map<String, dynamic>> verifyMfaAndLogin({
    required String mfaChallengeToken,
    required String code,
  }) async {
    return _post(
      ApiEndpoints.twoFactorLoginVerify,
      data: {
        'mfaChallengeToken': mfaChallengeToken,
        'code': code,
      },
    );
  }

  Future<void> logout() async {
    try {
      await dio.post(ApiEndpoints.logout);
    } catch (_) {
      // Au mieux : même si le backend ne répond pas, la session locale est
      // effacée juste après.
    } finally {
      await cookieJar.deleteAll();
    }
  }

  /// Profil minimal `{email, roles}` — voir `AuthController.monProfil`.
  /// Sert à vérifier que la session est encore vivante, pas à alimenter l'UI.
  Future<Map<String, dynamic>> getMe() => _get(ApiEndpoints.moi);

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _post(
      ApiEndpoints.changerMotDePasse,
      data: {
        'ancienMotDePasse': oldPassword,
        'nouveauMotDePasse': newPassword,
      },
    );
  }

  // ─── 2FA (compte authentifié) ────────────────────────────────

  /// `GET /api/auth/2fa/status` → `{enabled: bool}`.
  Future<bool> getTwoFactorStatus() async {
    final data = await _get(ApiEndpoints.twoFactorStatus);
    return data['enabled'] == true;
  }

  /// `POST /api/auth/2fa/setup` → `{secret, otpAuthUrl, qrCodeImage}`.
  Future<Map<String, dynamic>> demarrerActivation2fa() =>
      _post(ApiEndpoints.twoFactorSetup);

  /// `POST /api/auth/2fa/confirm` avec le code de l'application d'authentification.
  Future<void> confirmerActivation2fa(String code) async {
    await _post(ApiEndpoints.twoFactorConfirm, data: {'code': code});
  }

  /// `POST /api/auth/2fa/disable` avec un code valide.
  Future<void> desactiver2fa(String code) async {
    await _post(ApiEndpoints.twoFactorDisable, data: {'code': code});
  }

  Future<Map<String, dynamic>> forgotPassword({
    required String matricule,
    required String email,
  }) {
    return _post(
      ApiEndpoints.motDePasseOublie,
      data: {'matricule': matricule, 'email': email},
    );
  }

  // ─── Portail étudiant ──────────────────────────────────────

  Future<Map<String, dynamic>> getDashboard(String inscriptionId) =>
      _get(ApiEndpoints.etudiantDashboard(inscriptionId));

  Future<Map<String, dynamic>> getProfile(String inscriptionId) =>
      _get(ApiEndpoints.etudiantProfil(inscriptionId));

  Future<Map<String, dynamic>> updateProfile(
    String inscriptionId,
    Map<String, dynamic> data,
  ) {
    return _put(ApiEndpoints.etudiantProfil(inscriptionId), data: data);
  }

  // M3 : cache pour les cours (fréquemment consultés)
  Future<List<dynamic>> getCourses(String inscriptionId) => _cache.getOrFetch(
    key: 'courses_$inscriptionId',
    ttl: CacheTTL.cours,
    fetch: () => _getList(ApiEndpoints.etudiantCours(inscriptionId)),
  );

  /// `GET /api/etudiant/portal/{id}/notes` renvoie un OBJET
  /// `{anneeAcademique, moyenneGenerale, creditsValides, notes:[...]}`, pas
  /// une liste nue : on lit le Map complet, le modèle [NotesResultat] l'exploite.
  Future<Map<String, dynamic>> getNotes(String inscriptionId, {String? annee}) {
    return _get(
      ApiEndpoints.etudiantNotes(inscriptionId),
      queryParameters: annee != null ? {'annee': annee} : null,
    );
  }

  Future<List<dynamic>> getTravaux(String inscriptionId) =>
      _getList(ApiEndpoints.etudiantTravaux(inscriptionId));

  Future<Map<String, dynamic>> getDocuments(String inscriptionId) =>
      _get(ApiEndpoints.etudiantDocuments(inscriptionId));

  Future<List<dynamic>> getStages(String inscriptionId) =>
      _getList(ApiEndpoints.etudiantStage(inscriptionId));  // ─── Notifications ─────────────────────────────────────────

  Future<List<dynamic>> getNotifications() => _getList(ApiEndpoints.notificationsList);

  Future<List<dynamic>> getUnreadNotifications() => _getList(ApiEndpoints.notificationsNonLues);

  // M3 : cache court pour le compteur de notifications (polling fréquent)
  Future<int> getUnreadNotificationsCount() => _cache.getOrFetch(
    key: 'notifications_count',
    ttl: CacheTTL.notificationsCount,
    fetch: () async {
      final data = await _get(ApiEndpoints.notificationsCount);
      return (data['count'] as num?)?.toInt() ?? 0;
    },
  );

  // Invalider le cache des notifications quand on les marque comme lues
  void invalidateNotificationsCache() {
    _cache.invalidatePrefix('notifications');
  }

  Future<Map<String, dynamic>> getReleveNotes(
    String inscriptionId, {
    String? annee,
  }) {
    return _get(
      ApiEndpoints.etudiantReleve(inscriptionId),
      queryParameters: annee != null ? {'annee': annee} : null,
    );
  }

  /// Télécharge le PDF du reçu d'un paiement validé.
  Future<List<int>> telechargerRecu(int paiementId) async {
    try {
      final response = await dio.get<List<int>>(
        ApiEndpoints.recuPaiement(paiementId),
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    await _patch(ApiEndpoints.notificationMarquerLue(notificationId));
    invalidateNotificationsCache();
  }

  Future<void> markAllNotificationsAsRead() async {
    await _patch(ApiEndpoints.notificationsToutLire);
    invalidateNotificationsCache();
  }

  // ─── Frais et paiements ────────────────────────────────────

  // M3 CORRIGÉ : les données financières et l'emploi du temps
  // sont mises en cache pour éviter les rechargements inutiles.
  /// Situation financière : `GET /api/etudiant/frais/situation` (objet).

  Future<Map<String, dynamic>> getFeesSituation() => _cache.getOrFetch(
    key: 'fees_situation',
    ttl: CacheTTL.situationFinanciere,
    fetch: () => _get(ApiEndpoints.fraisSituation),
  );

  /// Frais à payer : `GET /api/etudiant/frais/a-payer` (liste de dettes).
  Future<List<dynamic>> getFeesAPayer() => _cache.getOrFetch(
    key: 'fees_a_payer',
    ttl: CacheTTL.situationFinanciere,
    fetch: () => _getList(ApiEndpoints.fraisAPayer),
  );

  Future<List<dynamic>> getPaymentHistory() => _cache.getOrFetch(
    key: 'payment_history',
    ttl: CacheTTL.situationFinanciere,
    fetch: () => _getList(ApiEndpoints.historiquePaiements),
  );

  // ─── Documents ─────────────────────────────────────────────

  Future<List<dynamic>> getAttestations() =>
      _getList(ApiEndpoints.attestations);

  // ─── Messagerie ────────────────────────────────────────────

  Future<List<dynamic>> getMessages() => _getList(ApiEndpoints.messagerie);

  Future<int> getUnreadMessagesCount(String destinataireId) async {
    final data = await _get(ApiEndpoints.messagesNonLus(destinataireId));
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  // ─── Smart Presence ────────────────────────────────────────

  Future<Map<String, dynamic>> demarrerSession(
    int coursId, {
    int? salleId,
    int? horaireId,
    double? latitude,
    double? longitude,
    double? precisionMetres,
  }) {
    return _post(
      ApiEndpoints.attendanceSessionsStart,
      data: {
        'coursId': coursId,
        'salleId': ?salleId,
        'horaireId': ?horaireId,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'precisionMetres': ?precisionMetres,
      },
    );
  }

  Future<void> fermerSession(int sessionId) async {
    await _post('${ApiEndpoints.attendanceSessionsClose}/$sessionId/close');
  }

  Future<Map<String, dynamic>> getStatutSession(int sessionId) {
    return _get(ApiEndpoints.attendanceSession(sessionId));
  }

  /// Séances du jour de l'enseignant connecté : ce qu'il peut ouvrir.
  Future<List<dynamic>> getSeancesDuJour() =>
      _getList(ApiEndpoints.attendanceSeancesDuJour);

  /// Séance Smart Présence déjà ouverte par l'enseignant, s'il y en a une.
  ///
  /// Même convention que côté étudiant : 204 signifie « aucune séance
  /// ouverte », ce qui est l'état normal hors cours et non une erreur.
  Future<Map<String, dynamic>?> getSessionCouranteProfesseur() async {
    try {
      final response = await dio.get(ApiEndpoints.attendanceSessionCourante);
      if (response.statusCode == 204) return null;
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 204) return null;
      throw ApiException.fromDio(e);
    }
  }

  /// Séance ouverte concernant l'étudiant connecté — `GET /sessions/mienne`.
  ///
  /// Renvoie `null` quand le serveur répond 204 (aucune séance ouverte pour la
  /// promotion de l'étudiant) — c'est une issue normale, pas une erreur.
  Future<Map<String, dynamic>?> getSessionCouranteEtudiant() async {
    try {
      final response = await dio.get(ApiEndpoints.attendanceSessionMienne);
      if (response.statusCode == 204) return null;
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 204) return null;
      throw ApiException.fromDio(e);
    }
  }

  /// Demande la preuve de proximité.
  ///
  /// Le contexte (position + appareil) est facultatif et jamais cru sur
  /// parole : sans lui le serveur délivre quand même la preuve, mais signale
  /// la présence au professeur. La géolocalisation ne doit donc jamais
  /// bloquer le parcours.
  Future<Map<String, dynamic>> verifierProximite(
    int sessionId, {
    ProximityProofRequest? contexte,
  }) {
    return _post(
      ApiEndpoints.attendanceVerifyProximity(sessionId),
      data: contexte?.toJson() ?? const {},
    );
  }

  Future<Map<String, dynamic>> scannerQr(
    int sessionId,
    String qrPayload,
    String proofToken,
  ) {
    return _post(
      ApiEndpoints.attendanceScan(sessionId),
      data: {
        'qrPayload': qrPayload,
        'proofToken': proofToken,
      },
    );
  }

  Future<List<dynamic>> getRecords(int sessionId) {
    return _getList(ApiEndpoints.attendanceRecords(sessionId));
  }

  // ─── Verbes HTTP ───────────────────────────────────────────

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _envelopper(() => dio.get(path, queryParameters: queryParameters));
  }

  Future<Map<String, dynamic>> _post(String path, {Object? data}) async {
    return _envelopper(() => dio.post(path, data: data));
  }

  Future<Map<String, dynamic>> _put(String path, {Object? data}) async {
    return _envelopper(() => dio.put(path, data: data));
  }

  Future<Map<String, dynamic>> _patch(String path, {Object? data}) async {
    return _envelopper(() => dio.patch(path, data: data));
  }

  Future<Map<String, dynamic>> _envelopper(
    Future<Response<dynamic>> Function() appel,
  ) async {
    try {
      final response = await appel();
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data == null || (data is String && data.isEmpty)) return const {};
      return {'data': data};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<dynamic>> _getList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await dio.get(path, queryParameters: queryParameters);
      final data = response.data;
      if (data is List) return data;
      // Certains endpoints renvoient une page Spring `{content: [...]}`.
      if (data is Map && data['content'] is List) return data['content'] as List;
      return const [];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
