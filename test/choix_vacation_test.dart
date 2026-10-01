import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/errors/api_exception.dart';
import 'package:genuc_mobile/data/models/etudiant/dashboard_data_backend.dart';
import 'package:genuc_mobile/data/repositories/student_repository.dart';
import 'package:genuc_mobile/presentation/providers/student_provider.dart';

/// Choix de vacation par l'étudiant (règle serveur du 01/10/2026, 7e77fe5).
///
/// Le serveur n'accepte plus qu'un choix, parmi les vacations ouvertes de
/// l'établissement qui couvrent la promotion. Le refus doit atteindre l'écran :
/// avalé par `_charger`, il laissait annoncer « Vacation enregistrée ».
void main() {
  test('un refus du serveur remonte à l\'écran', () async {
    final depot = _DepotVacation(
      refus: const ApiException(
        'Votre vacation est déjà choisie : pour en changer, adressez-vous '
        'au secrétariat académique.',
        statusCode: 400,
      ),
    );
    final provider = StudentProvider(depot);

    await expectLater(
      provider.choisirVacation('7', 3),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', contains('secrétariat'))),
    );
    // Relu même après le refus : la carte de choix doit disparaître.
    expect(depot.lecturesTableauDeBord, 1);
    expect(provider.dashboard?.vacationChoisie, isTrue);
  });

  test('un choix accepté relit le tableau de bord', () async {
    final depot = _DepotVacation();
    final provider = StudentProvider(depot);

    await provider.choisirVacation('7', 3);

    expect(depot.choix, [3]);
    expect(depot.lecturesTableauDeBord, 1);
    expect(provider.error, isNull);
  });
}

class _DepotVacation implements StudentRepository {
  final ApiException? refus;
  final List<int> choix = [];
  int lecturesTableauDeBord = 0;

  _DepotVacation({this.refus});

  @override
  Future<void> choisirVacation(String inscriptionId, int vacationId) async {
    if (refus != null) throw refus!;
    choix.add(vacationId);
  }

  @override
  Future<DashboardData> getDashboard(String inscriptionId) async {
    lecturesTableauDeBord++;
    return DashboardData.fromJson({'vacationChoisie': true, 'vacationId': 3});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
