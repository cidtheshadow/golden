import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_model.dart';
import '../firebase/firestore_service.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return ServiceRepository(FirestoreService());
});

class ServiceRepository {
  final FirestoreService _firestoreService;

  ServiceRepository(this._firestoreService);

  Future<List<ServiceModel>> getServices() => _firestoreService.getServices();

  Stream<List<ServiceModel>> getServicesStream() =>
      _firestoreService.getServicesStream();

  Future<List<ServiceModel>> getServicesByCategory(String category) =>
      _firestoreService.getServicesByCategory(category);

  Stream<List<ServiceModel>> getPopularServices() =>
      _firestoreService.getPopularServices();
}
