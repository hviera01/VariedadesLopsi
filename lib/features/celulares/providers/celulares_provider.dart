import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/celular_repository.dart';
import '../data/celular_model.dart';
import '../data/historial_celular_model.dart';

final celularRepositoryProvider = Provider((ref) => CelularRepository());

final celularesStreamProvider = StreamProvider<List<CelularModel>>((ref) {
  return ref.watch(celularRepositoryProvider).obtenerCelulares();
});

// autoDispose: es un historial que se consulta una vez en un diálogo y se
// cierra; sin autoDispose el cache de Riverpod quedaría con un provider vivo
// por cada celular distinto que se haya revisado en la sesión.
final historialCelularProvider = FutureProvider.autoDispose.family<List<HistorialCelularModel>, String>((ref, idCelular) {
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
