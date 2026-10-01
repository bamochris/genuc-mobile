import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/theme/app_theme.dart';
import 'package:genuc_mobile/presentation/config/destinations.dart';
import 'package:genuc_mobile/presentation/screens/professeur/compte/compte_screens.dart';

import 'support/montage_portail.dart';

/// Modules que le serveur déclare non implémentés (audit du 01/10/2026).
///
/// « Mon évaluation » recevait des moyennes à zéro d'un module qui n'existe
/// pas ; le serveur répond désormais 501 avec un message. Ce n'est pas une
/// panne : l'écran doit le dire comme un état vide, sans « Réessayer ».
void main() {
  setUp(MontagePortail.simulerStockageSecurise);

  testWidgets('Mon évaluation : un 501 s\'affiche comme un état, pas une erreur',
      (tester) async {
    await MontagePortail.monter(
      tester,
      Destination(
        chemin: '/professeur/mon-evaluation',
        libelle: 'Mon évaluation',
        icone: Icons.star_rounded,
        couleur: const Color(0xFF185FA5),
        construire: (_) => const MonEvaluationScreen(),
      ),
      'PROFESSEUR',
      theme: AppTheme.lightTheme,
      adaptateur: _ServeurModuleAbsent(),
    );

    expect(find.textContaining('enregistre pas encore'), findsOneWidget);
    expect(find.text('Erreur de chargement'), findsNothing);
    expect(find.text('Réessayer'), findsNothing);
  });
}

class _ServeurModuleAbsent implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    if (options.path.contains('/api/evaluations/professeur/')) {
      return ResponseBody.fromString(
        '{"success":false,"status":501,"code":"MODULE_NON_IMPLEMENTE",'
        '"message":"Le module « Évaluation des enseignants » n\'enregistre pas encore les données qui lui sont confiées."}',
        501,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString('[]', 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }
}
