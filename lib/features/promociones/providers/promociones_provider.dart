import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/promocion_repository.dart';
import '../data/promocion_model.dart';

final promocionRepositoryProvider = Provider((ref) => PromocionRepository());

final promocionesStreamProvider = StreamProvider<List<PromocionModel>>((ref) {
  return ref.watch(promocionRepositoryProvider).obtenerPromociones();
});
