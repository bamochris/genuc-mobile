import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../storage/secure_cookie_storage.dart';

/// Client HTTP unique de l'application.
///
/// Une seule instance existe pour tout le processus : les cookies de session
/// posés à la connexion doivent être visibles par TOUS les appels (portail
/// étudiant, notifications, paiements). Avec un client par provider, seul
/// celui qui avait servi la connexion restait authentifié et tous les autres
/// repartaient en 401.
class DioClient {
  static DioClient? _instance;

  /// Marqueur posé sur une requête déjà rejouée après rafraîchissement, pour
  /// qu'un 401 persistant ne déclenche pas une boucle de refresh infinie.
  static const _retriedKey = '__genuc_retried';

  late final Dio dio;
  late final PersistCookieJar cookieJar;

  /// Rafraîchissement en cours, partagé par tous les appels : sans ce verrou,
  /// N requêtes qui reçoivent 401 en même temps déclenchent N refresh
  /// concurrents et les jetons se supplantent les uns les autres.
  Future<bool>? _refreshInFlight;

  factory DioClient() => _instance ??= DioClient._internal();

  /// Réinitialise le singleton. Réservé aux tests.
  @visibleForTesting
  static void reset() => _instance = null;

  DioClient._internal() {
    cookieJar = PersistCookieJar(storage: SecureCookieStorage());

    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
        sendTimeout: const Duration(milliseconds: AppConstants.uploadTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    if (!kIsWeb) {
      dio.interceptors.add(CookieManager(cookieJar));
    }

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // `await` obligatoire : la lecture du pot à cookies est asynchrone.
        // Sans lui, handler.next() partait avant que l'en-tête soit posé et
        // le backend rejetait en 403 tout écrit hors endpoints d'amorçage.
        if (!kIsWeb) {
          await _attachCsrfToken(options);
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final requestOptions = error.requestOptions;
        final dejaRejouee = requestOptions.extra[_retriedKey] == true;
        final statut = error.response?.statusCode;

        // 403 sans jeton CSRF en poche : l'amorçage n'avait pas encore
        // abouti. On l'obtient et on rejoue une fois.
        if (statut == 403 && !dejaRejouee && !await _possedeJetonCsrf()) {
          await amorcerCsrf();
          if (await _possedeJetonCsrf()) {
            return _rejouer(requestOptions, handler, error);
          }
        }

        if (statut == 401 &&
            !dejaRejouee &&
            !_estEndpointAmorcage(requestOptions.path)) {
          if (await _refreshTokens()) {
            return _rejouer(requestOptions, handler, error);
          }
        }

        return handler.next(error);
      },
    ));

    if (kDebugMode) {
      // Volontairement sans `requestBody`/`responseBody` : ils recopiaient les
      // mots de passe et les profils complets dans logcat.
      dio.interceptors.add(LogInterceptor(
        request: false,
        requestHeader: false,
        responseHeader: false,
      ));
    }
  }

  /// Rejoue une requête après rattrapage (rafraîchissement ou amorçage CSRF).
  ///
  /// Passe par `request` et non `fetch` : seul `request` repasse par la chaîne
  /// d'intercepteurs, celle qui pose les cookies à jour et le nouvel en-tête
  /// CSRF. Les en-têtes périmés sont retirés pour laisser la chaîne les
  /// recalculer.
  Future<void> _rejouer(
    RequestOptions requestOptions,
    ErrorInterceptorHandler handler,
    DioException erreurInitiale,
  ) async {
    try {
      final response = await dio.request<dynamic>(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        cancelToken: requestOptions.cancelToken,
        options: Options(
          method: requestOptions.method,
          headers: Map<String, dynamic>.from(requestOptions.headers)
            ..remove('cookie')
            ..remove(AppConstants.csrfHeaderName),
          responseType: requestOptions.responseType,
          contentType: requestOptions.contentType,
          extra: {...requestOptions.extra, _retriedKey: true},
        ),
      );
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<bool> _possedeJetonCsrf() async {
    try {
      final cookies = await cookieJar.loadForRequest(
        Uri.parse(AppConstants.baseUrl),
      );
      return cookies.any((c) =>
          c.name == AppConstants.csrfCookieName && c.value.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  bool _estEndpointAmorcage(String path) {
    return path == AppConstants.refreshEndpoint ||
        path == AppConstants.loginEndpoint ||
        path == AppConstants.logoutEndpoint ||
        path == AppConstants.twoFactorVerifyEndpoint;
  }

  Future<void> _attachCsrfToken(RequestOptions options) async {
    try {
      final cookies = await cookieJar.loadForRequest(
        Uri.parse(AppConstants.baseUrl).resolve(options.path),
      );

      for (final cookie in cookies) {
        if (cookie.name == AppConstants.csrfCookieName && cookie.value.isNotEmpty) {
          options.headers[AppConstants.csrfHeaderName] = cookie.value;
          return;
        }
      }
    } catch (_) {
      // Pas de jeton disponible : la requête partira sans, le backend
      // répondra 403 et l'appelant traitera l'erreur normalement.
    }
  }

  /// Amorce le cookie `XSRF-TOKEN` avant la première écriture.
  ///
  /// Spring Security 6 ne l'émet que sur une réponse ; tant qu'aucun appel n'a
  /// eu lieu, le pot est vide et la connexion partirait sans en-tête CSRF.
  /// C'est le pendant du `GET /api/universites/public` que fait le portail web
  /// à son montage.
  Future<void> amorcerCsrf() async {
    try {
      await dio.get(AppConstants.csrfBootstrapEndpoint);
    } catch (_) {
      // L'important est la réponse (et son Set-Cookie), pas son contenu.
    }
  }

  Future<bool> _refreshTokens() {
    return _refreshInFlight ??= _executerRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _executerRefresh() async {
    try {
      final response = await dio.post(
        AppConstants.refreshEndpoint,
        options: Options(extra: {_retriedKey: true}),
      );
      if (response.statusCode == 200) return true;
    } on DioException catch (_) {
      // Session définitivement expirée.
    }
    await cookieJar.deleteAll();
    return false;
  }
}
