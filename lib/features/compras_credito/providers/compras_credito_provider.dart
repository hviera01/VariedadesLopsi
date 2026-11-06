import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/compra_credito_repository.dart';
import '../data/compra_credito_model.dart';
import '../data/abono_compra_model.dart';

final compraCreditoRepositoryProvider = Provider((ref) => CompraCreditoRepository());

final comprasCreditoStreamProvider = StreamProvider<List<CompraCreditoModel>>((ref) {
  return ref.watch(compraCreditoRepositoryProvider).obtenerCompras();
});

// autoDispose: se abre en un diálogo para consultar el historial de abonos
// de una compra y se cierra; sin autoDispose quedaría un provider vivo por
// cada compra distinta revisada en la sesión.
final abonosCompraStreamProvider = FutureProvider.autoDispose.family<List<AbonoCompraModel>, String>((ref, idCompra) {
  return ref.watch(compraCreditoRepositoryProvider).obtenerAbonos(idCompra);
});

class ComprasCreditoBusquedaNotifier extends Notifier<String> {
  @override
  String build() => '';
  void actualizar(String valor) => state = valor;
}

final comprasCreditoBusquedaProvider = NotifierProvider<ComprasCreditoBusquedaNotifier, String>(ComprasCreditoBusquedaNotifier.new);

class ComprasCreditoVistaNotifier extends Notifier<String> {
  @override
  String build() => 'debe';
  void actualizar(String valor) => state = valor;
}

final comprasCreditoVistaProvider = NotifierProvider<ComprasCreditoVistaNotifier, String>(ComprasCreditoVistaNotifier.new);
