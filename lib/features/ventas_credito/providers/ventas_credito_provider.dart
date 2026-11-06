import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/venta_credito_repository.dart';
import '../data/venta_credito_model.dart';
import '../data/abono_model.dart';

final ventaCreditoRepositoryProvider = Provider((ref) => VentaCreditoRepository());

final ventasCreditoStreamProvider = StreamProvider<List<VentaCreditoModel>>((ref) {
  return ref.watch(ventaCreditoRepositoryProvider).obtenerCreditos();
});

// autoDispose: se abre en un diálogo para consultar el historial de abonos
// de un crédito y se cierra; sin autoDispose quedaría un provider vivo por
// cada crédito distinto revisado en la sesión.
final abonosStreamProvider = FutureProvider.autoDispose.family<List<AbonoModel>, String>((ref, idCredito) {
  return ref.watch(ventaCreditoRepositoryProvider).obtenerAbonos(idCredito);
});

class VentasCreditoBusquedaNotifier extends Notifier<String> {
  @override
  String build() => '';
  void actualizar(String valor) => state = valor;
}

final ventasCreditoBusquedaProvider = NotifierProvider<VentasCreditoBusquedaNotifier, String>(VentasCreditoBusquedaNotifier.new);

class VentasCreditoVistaNotifier extends Notifier<String> {
  @override
  String build() => 'debe';
  void actualizar(String valor) => state = valor;
}

final ventasCreditoVistaProvider = NotifierProvider<VentasCreditoVistaNotifier, String>(VentasCreditoVistaNotifier.new);
