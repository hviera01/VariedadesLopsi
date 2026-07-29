import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/cliente_repository.dart';
import '../data/cliente_model.dart';
import '../data/movimiento_puntos_model.dart';

final clienteRepositoryProvider = Provider((ref) => ClienteRepository());

final clientesStreamProvider = StreamProvider<List<ClienteModel>>((ref) {
  return ref.watch(clienteRepositoryProvider).obtenerClientes();
});

final movimientosPuntosProvider = StreamProvider.family<List<MovimientoPuntosModel>, String>((ref, idCliente) {
  return ref.watch(clienteRepositoryProvider).obtenerMovimientosPuntos(idCliente);
});

class ClientesBusquedaNotifier extends Notifier<String> {
  @override
  String build() => '';
  void actualizar(String valor) => state = valor;
}

final clientesBusquedaProvider = NotifierProvider<ClientesBusquedaNotifier, String>(ClientesBusquedaNotifier.new);

class ClientesVistaNotifier extends Notifier<String> {
  @override
  String build() => 'filtrados';
  void actualizar(String valor) => state = valor;
}

final clientesVistaProvider = NotifierProvider<ClientesVistaNotifier, String>(ClientesVistaNotifier.new);
