import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/celular_repository.dart';
import '../data/celular_model.dart';
import '../data/historial_celular_model.dart';

final celularRepositoryProvider = Provider((ref) => CelularRepository());

final celularesStreamProvider = StreamProvider<List<CelularModel>>((ref) {
  return ref.watch(celularRepositoryProvider).obtenerCelulares();
});

final historialCelularProvider = StreamProvider.family<List<HistorialCelularModel>, String>((ref, idCelular) {
  return ref.watch(celularRepositoryProvider).obtenerHistorial(idCelular);
});

class CelularesBusquedaNotifier extends Notifier<String> {
  @override
  String build() => '';
  void actualizar(String valor) => state = valor;
}

final celularesBusquedaProvider = NotifierProvider<CelularesBusquedaNotifier, String>(CelularesBusquedaNotifier.new);

/// null = todos los estados.
class CelularesFiltroEstadoNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void actualizar(String? valor) => state = valor;
}

final celularesFiltroEstadoProvider = NotifierProvider<CelularesFiltroEstadoNotifier, String?>(CelularesFiltroEstadoNotifier.new);
