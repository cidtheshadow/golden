import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/service_personnel_model.dart';
import '../../repositories/service_personnel_repository.dart';

final caregiversProvider =
    FutureProvider.autoDispose<List<ServicePersonnelModel>>((ref) async {
  final repository = ref.watch(servicePersonnelRepositoryProvider);
  final all = await repository.getServicePersonnel();
  all.sort((a, b) => b.rating.compareTo(a.rating));
  return all;
});
