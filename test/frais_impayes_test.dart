import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/errors/api_exception.dart';
import 'package:genuc_mobile/data/models/etudiant/cours.dart';
import 'package:genuc_mobile/data/models/etudiant/dashboard_data_backend.dart';
import 'package:genuc_mobile/data/models/etudiant/etudiant_profile_backend.dart';
import 'package:genuc_mobile/data/models/etudiant/note.dart';
import 'package:genuc_mobile/data/models/etudiant/paiement.dart';
import 'package:genuc_mobile/data/repositories/student_repository.dart';
import 'package:genuc_mobile/presentation/providers/student_provider.dart';

/// Résultats retenus pour frais impayés (règle serveur du 30/09/2026).
///
/// Le serveur répond 402 `{code: FRAIS_IMPAYES, erreur, message, montantsDus}`
/// sur les notes, relevés, bulletins et certains documents, et pose
/// `resultatsRetenus` (moyenne et crédits à `null`) sur le tableau de bord.
void main() {
  const corps402 = {
    'success': false,
    'status': 402,
    'code': 'FRAIS_IMPAYES',
    'message': 'Vos résultats vous seront accessibles une fois vos frais '
        'réglés. Reste à payer : 300 USD.',
    'erreur': 'Vos résultats vous seront accessibles une fois vos frais '
        'réglés. Reste à payer : 300 USD.',
    'montantsDus': {'USD': 300},
  };

  DioException refus(dynamic donnees) {
    final options = RequestOptions(path: '/api/etudiant/portal/7/notes');
    return DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: 402,
        data: donnees,
      ),
    );
  }

  group('ApiException et le 402', () {
    test('lit le message du serveur et reconnaît les frais impayés', () {
      final e = ApiException.fromDio(refus(corps402));
      expect(e.estFraisImpayes, isTrue);
      expect(e.message, contains('Reste à payer : 300 USD'));
    });

    test('décode le refus d\'un téléchargement arrivé en OCTETS', () {
      // Un PDF demandé en `ResponseType.bytes` : le corps d'erreur JSON
      // arrive en octets, et l'écran ne disait que « Erreur serveur (402) ».
      final e = ApiException.fromDio(refus(utf8.encode(jsonEncode(corps402))));
      expect(e.estFraisImpayes, isTrue);
      expect(e.message, contains('300 USD'));
    });

    test('sans corps lisible, un repli qui dit la cause', () {
      final e = ApiException.fromDio(refus(null));
      expect(e.estFraisImpayes, isTrue);
      expect(e.message, contains('frais'));
    });
  });

  group('Tableau de bord aux résultats retenus', () {
    test('moyenne nulle ET retenue : ni 0/20 ni échec', () {
      final d = DashboardData.fromJson({
        'moyenneGenerale': null,
        'creditsValides': null,
        'resultatsRetenus': true,
      });
      expect(d.resultatsRetenus, isTrue);
      expect(d.isReussi, isFalse);
    });

    test('un 402 sur les notes ne fait plus tomber tout l\'écran', () async {
      final provider = StudentProvider(_DepotNotesRetenues());
      await provider.loadEssentiels('7');

      expect(provider.error, isNull,
          reason: 'le tableau de bord, le profil et la situation financière '
              'doivent rester lisibles pour pouvoir régulariser');
      expect(provider.dashboard, isNotNull);
      expect(provider.situationFinanciere, isNotNull);
      expect(provider.notesResultat?.estRetenu, isTrue);
      expect(provider.notesResultat?.retenue, contains('300 USD'));
      expect(provider.notes, isEmpty);
    });

    test('une autre erreur sur les notes reste une erreur', () async {
      final provider = StudentProvider(
          _DepotNotesRetenues(erreur: const ApiException('Panne', statusCode: 500)));
      await provider.loadEssentiels('7');
      expect(provider.error, 'Panne');
    });
  });

  test('NotesResultat retenu n\'est pas « réussi »', () {
    final r = NotesResultat.retenus('Frais à régler');
    expect(r.estRetenu, isTrue);
    expect(r.estReussi, isFalse);
    expect(r.notes, isEmpty);
  });

  test('profil : l\'adresse de remplacement est signalée', () {
    final p = EtudiantProfile.fromJson({'email': '', 'emailDeRemplacement': true});
    expect(p.emailDeRemplacement, isTrue);
    expect(EtudiantProfile.fromJson({'email': 'a@b.cd'}).emailDeRemplacement,
        isFalse);
  });
}

/// Dépôt dont seules les notes échouent — en 402 par défaut.
class _DepotNotesRetenues implements StudentRepository {
  final ApiException erreur;

  _DepotNotesRetenues({
    this.erreur = const ApiException(
      'Vos résultats vous seront accessibles une fois vos frais réglés. '
      'Reste à payer : 300 USD.',
      code: 'FRAIS_IMPAYES',
      statusCode: 402,
    ),
  });

  @override
  Future<DashboardData> getDashboard(String inscriptionId) async =>
      DashboardData.fromJson({'resultatsRetenus': true});

  @override
  Future<List<Cours>> getCourses(String inscriptionId) async => const [];

  @override
  Future<NotesResultat> getNotes(String inscriptionId, {String? annee}) =>
      Future.error(erreur);

  @override
  Future<EtudiantProfile> getProfile(String inscriptionId) async =>
      EtudiantProfile.fromJson(const {});

  @override
  Future<SituationFinanciere> getSituationFinanciere() async =>
      SituationFinanciere.fromJson(const {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
