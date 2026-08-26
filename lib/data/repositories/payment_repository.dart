import '../services/api_service.dart';

class PaymentRepository {
  final ApiService api;

  PaymentRepository(this.api);

  Future<List<dynamic>> getPayments() => api.getPayments();

  /// Situation financière de l'étudiant connecté (`/api/etudiant/frais/situation`).
  Future<Map<String, dynamic>> getFeesSituation() => api.getFeesSituation();

  Future<List<dynamic>> getPaymentHistory() => api.getPaymentHistory();
}
