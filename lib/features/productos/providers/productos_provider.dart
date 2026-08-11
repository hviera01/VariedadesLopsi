import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/producto_repository.dart';
import '../data/producto_model.dart';
import '../data/historial_stock_model.dart';
import '../data/historial_precio_compra_model.dart';
import '../data/historial_venta_producto_model.dart';
import '../data/lote_costo_model.dart';
import '../data/lote_costo_repository.dart';

final productoRepositoryProvider = Provider((ref) => ProductoRepository());

final loteCostoRepositoryProvider = Provider((ref) => LoteCostoRepository());

// Los cuatro providers de abajo (lotes/historial) son autoDispose + Future
// (antes StreamProvider.family con .snapshots()): se abren en diálogos de
// "ver historial" de un producto puntual para consultar el pasado, no para
// seguir cambios en vivo. Sin autoDispose, cada producto distinto revisado
// en la sesión dejaba un listener de Firestore abierto para siempre — con
// autoDispose + .get() es una sola lectura mientras el diálogo está abierto.
final lotesProductoProvider = FutureProvider.autoDispose.family<List<LoteCostoModel>, String>((ref, idProducto) {
  return ref.watch(loteCostoRepositoryProvider).obtenerLotes(idProducto);
});

// Este sí se queda como listener en tiempo real (sin autoDispose, provider
// único global): el stock tiene que verse al instante durante una venta
// (evitar vender algo que ya no hay) y en el inventario cuando otro usuario
// registra una compra/ajuste. Al no ser .family ni .autoDispose es un solo
// listener para toda la app, compartido por todas las pantallas que lo
// observan.
final productosStreamProvider = StreamProvider<List<ProductoModel>>((ref) {
  return ref.watch(productoRepositoryProvider).obtenerProductos();
});

final historialStockProvider = FutureProvider.autoDispose.family<List<HistorialStockModel>, String>((ref, idProducto) {
  return ref.watch(productoRepositoryProvider).obtenerHistorialStock(idProducto);
});

final historialPreciosCompraProvider = FutureProvider.autoDispose.family<List<HistorialPrecioCompraModel>, String>((ref, idProducto) {
  return ref.watch(productoRepositoryProvider).obtenerHistorialPreciosCompra(idProducto);
});

final historialVentasProductoProvider = FutureProvider.autoDispose.family<List<HistorialVentaProductoModel>, String>((ref, idProducto) {
  return ref.watch(productoRepositoryProvider).obtenerHistorialVentas(idProducto);
});

class InventarioBusquedaNotifier extends Notifier<String> {
  @override
  String build() => '';
  void actualizar(String valor) => state = valor;
}

final inventarioBusquedaProvider = NotifierProvider<InventarioBusquedaNotifier, String>(InventarioBusquedaNotifier.new);

class InventarioVistaNotifier extends Notifier<String> {
  @override
  String build() => 'filtrados';
  void actualizar(String valor) => state = valor;
}

final inventarioVistaProvider = NotifierProvider<InventarioVistaNotifier, String>(InventarioVistaNotifier.new);