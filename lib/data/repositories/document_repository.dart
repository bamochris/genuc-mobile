import '../services/api_service.dart';

class DocumentRepository {
  final ApiService api;

  DocumentRepository(this.api);

  Future<List<dynamic>> getAttestations() => api.getAttestations();

  /// Documents officiels d'un dossier (relevés, attestations générées…).
  /// Il n'existe pas d'endpoint `/api/diplomes` côté backend : les diplômes
  /// remontent dans cette réponse.
  Future<Map<String, dynamic>> getDocuments(String inscriptionId) =>
      api.getDocuments(inscriptionId);
}
