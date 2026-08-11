import '../../productos/data/producto_model.dart';
import 'promocion_model.dart';

/// Lógica pura de promociones (sin Firestore ni Widgets, para poder
/// razonarla y probarla aparte): qué promociones aplican a un producto en
/// este momento, y cuál conviene aplicar cuando cae en más de una.

/// Promociones vigentes (por fecha y activas) y aplicables a [idProducto]
/// según la condición de pago (Contado/Crédito) de la venta en curso.
List<PromocionModel> promocionesAplicables(
  List<PromocionModel> todas,
  String idProducto,
  String condicion, {
  DateTime? ahora,
}) {
  return todas.where((p) => p.aplicaAProducto(idProducto) && p.vigente(ahora) && p.aplicaACondicion(condicion)).toList();
}

/// Valor monetario promedio "por unidad comprada" de una promoción, para
/// poder comparar entre tipos distintos (un % no se compara directo contra
/// un combo) y quedarse con la de mayor beneficio para el cliente cuando un
/// producto cae en más de una promoción vigente a la vez.
double valorPorUnidad(PromocionModel promo, ProductoModel producto, ProductoModel? productoRegalo) {
  switch (promo.tipo) {
    case TipoPromocion.porcentaje:
      return producto.precioVenta * promo.porcentajeDescuento / 100;
    case TipoPromocion.precioFijo:
      final diferencia = producto.precioVenta - promo.precioFijo;
      return diferencia > 0 ? diferencia : 0;
    case TipoPromocion.comboCantidad:
      if (promo.cantidadRequerida <= 0) return 0;
      return producto.precioVenta * promo.cantidadBeneficio / promo.cantidadRequerida;
    case TipoPromocion.regalo:
      if (promo.cantidadRequerida <= 0) return 0;
      final precioRegalo = productoRegalo?.precioVenta ?? 0;
      return precioRegalo * promo.cantidadRegalo / promo.cantidadRequerida;
  }
}

/// De la lista de promociones aplicables a [producto], la de mayor
/// beneficio para el cliente (ver [valorPorUnidad]). [productosPorId] sirve
/// para resolver el precio del producto regalado en promociones tipo
/// [TipoPromocion.regalo].
PromocionModel? elegirMejorPromocion(List<PromocionModel> aplicables, ProductoModel producto, Map<String, ProductoModel> productosPorId) {
  PromocionModel? mejor;
  var mejorValor = -1.0;
  for (final promo in aplicables) {
    final productoRegalo = promo.tipo == TipoPromocion.regalo ? productosPorId[promo.idProductoRegalo] : null;
    final valor = valorPorUnidad(promo, producto, productoRegalo);
    if (valor > mejorValor) {
      mejorValor = valor;
      mejor = promo;
    }
  }
  return mejor;
}

/// Texto corto para mostrar en badges/chips y en la lista de vigentes.
String descripcionCortaPromocion(PromocionModel promo) {
  switch (promo.tipo) {
    case TipoPromocion.porcentaje:
      final pct = promo.porcentajeDescuento;
      return '${pct % 1 == 0 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1)}% de descuento';
    case TipoPromocion.precioFijo:
      return 'Precio especial';
    case TipoPromocion.comboCantidad:
      return 'Llevando ${promo.cantidadRequerida}, se llevan ${promo.cantidadBeneficio} más gratis';
    case TipoPromocion.regalo:
      return 'Al llevar ${promo.cantidadRequerida}, se regala ${promo.cantidadRegalo} de ${promo.nombreProductoRegalo}';
  }
}
