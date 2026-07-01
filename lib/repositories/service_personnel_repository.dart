import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_personnel_model.dart';
import '../firebase/firestore_service.dart';

final servicePersonnelRepositoryProvider = Provider<ServicePersonnelRepository>((ref) {
  return ServicePersonnelRepository(FirestoreService());
});

class ServicePersonnelRepository {
  final FirestoreService _firestoreService;

  ServicePersonnelRepository(this._firestoreService);

  Future<List<ServicePersonnelModel>> getServicePersonnel({DateTime? startTime, DateTime? endTime}) => 
      _firestoreService.getServicePersonnel(startTime: startTime, endTime: endTime);
      
  Stream<ServicePersonnelModel?> getPersonnelStream(String uid) => 
      _firestoreService.getPersonnelStream(uid);
      
  Future<void> updatePersonnelStatus(String uid, bool isOnline) => 
      _firestoreService.updatePersonnelStatus(uid, isOnline);
      
  Future<void> createServicePersonnel(ServicePersonnelModel personnel) => 
      _firestoreService.createServicePersonnel(personnel);
      
  Future<void> updateServicePersonnel(String uid, Map<String, dynamic> data) => 
      _firestoreService.updateServicePersonnel(uid, data);
      
  Future<void> submitReview(String personnelId, Map<String, dynamic> review) => 
      _firestoreService.submitReview(personnelId, review);
}
