import 'package:cloud_firestore/cloud_firestore.dart';
import 'reporte_repository.dart';
import 'reporte_financiero_model.dart';
import 'reporte_venta_model.dart';
import 'reporte_compra_model.dart';
import '../../ventas/data/item_venta_model.dart';
import '../../compras/data/item_compra_model.dart';
import '../../productos/data/producto_model.dart';
import '../../egresos/data/egreso_repository.dart';
import '../../egresos/data/egreso_model.dart';
import '../../compras_credito/data/compra_credito_repository.dart';
import '../../compras_credito/data/abono_compra_model.dart';
import '../../ventas_credito/data/venta_credito_repository.dart';
import '../../ventas_credito/data/abono_model.dart';
import '../../caja/data/cierre_caja_repository.dart';

/// Cuánto del efectivo estimado se sugiere reservar como colchón de
/// seguridad antes de recomendar pagos a proveedores.
const _colchonSeguridadPorcentaje = 0.20;

/// Porcentaje del efectivo cobrado en el periodo que, como referencia
/// alternativa, se sugiere destinar a pagos a proveedores.
const _porcentajeVentasParaProveedores = 0.35;

const _topN = 10;

/// Detalle de ventas/compras agrupado por id de documento padre, resuelto
/// desde una sola query de collectionGroup (ver [ReporteFinancieroRepository._detallePorRango]).
typedef _DetalleRapido = ({Map<String, List<ItemVentaModel>> ventas, Map<String, List<ItemCompraModel>> compras});

class ReporteFinancieroRepository {
  final _db = FirebaseFirestore.instance;
  final _reporteRepository = ReporteRepository();
  final _egresoRepository = EgresoRepository();
  final _compraCreditoRepository = CompraCreditoRepository();
  final _ventaCreditoRepository = VentaCreditoRepository();
  final _cierreCajaRepository = CierreCajaRepository();

  Future<List<ItemVentaModel>> _detalleVenta(String idVenta) async {
    final snap = await _db.collection('ventas').doc(idVenta).collection('detalle').get();
    return snap.docs.map((d) => ItemVentaModel.fromMap(d.data())).toList();
  }

  Future<List<ItemCompraModel>> _detalleCompra(String idCompra) async {
    final snap = await _db.collection('compras').doc(idCompra).collection('detalle').get();
    return snap.docs.map((d) => ItemCompraModel.fromMap(d.data())).toList();
  }

  /// Trae en una sola consulta (collectionGroup sobre 'detalle', filtrado por
  /// el campo 'fecha' que se guarda en cada línea) el detalle de todas las
  /// ventas y compras del rango, evitando leer la subcolección de cada
  /// documento uno por uno.
  Future<_DetalleRapido> _detallePorRango(DateTime inicio, DateTime finInclusive) async {
    final snap = await _db
        .collectionGroup('detalle')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive))
        .get();
    final porVenta = <String, List<ItemVentaModel>>{};
    final porCompra = <String, List<ItemCompraModel>>{};
    for (final doc in snap.docs) {
      final docPadre = doc.reference.parent.parent;
      if (docPadre == null) continue;
      final coleccionRaiz = docPadre.parent.id;
      if (coleccionRaiz == 'ventas') {
        porVenta.putIfAbsent(docPadre.id, () => []).add(ItemVentaModel.fromMap(doc.data()));
      } else if (coleccionRaiz == 'compras') {
        porCompra.putIfAbsent(docPadre.id, () => []).add(ItemCompraModel.fromMap(doc.data()));
      }
    }
    return (ventas: porVenta, compras: porCompra);
  }

  /// Junta el detalle rápido con un respaldo documento-por-documento solo
  /// para los que quedaron fuera (registrados antes de que 'detalle'
  /// empezara a guardar su propia fecha). A medida que pase el tiempo esta
  /// lista de respaldo se vuelve vacía.
  Future<List<List<ItemVentaModel>>> _resolverDetalleVentas(List<ReporteVentaModel> ventas, Map<String, List<ItemVentaModel>> rapido) async {
    final faltantes = ventas.where((v) => !rapido.containsKey(v.id)).toList();
    final detalleFaltante = await Future.wait(faltantes.map((v) => _detalleVenta(v.id)));
    final porId = {for (var i = 0; i < faltantes.length; i++) faltantes[i].id: detalleFaltante[i]};
    return [for (final v in ventas) rapido[v.id] ?? porId[v.id] ?? const []];
  }

  Future<List<List<ItemCompraModel>>> _resolverDetalleCompras(List<ReporteCompraModel> compras, Map<String, List<ItemCompraModel>> rapido) async {
    final faltantes = compras.where((c) => !rapido.containsKey(c.id)).toList();
    final detalleFaltante = await Future.wait(faltantes.map((c) => _detalleCompra(c.id)));
    final porId = {for (var i = 0; i < faltantes.length; i++) faltantes[i].id: detalleFaltante[i]};
    return [for (final c in compras) rapido[c.id] ?? porId[c.id] ?? const []];
  }

  /// Ventas y costo de las ventas a crédito que se terminaron de pagar
  /// dentro del rango (el abono que llevó su saldo pendiente a 0), para la
  /// Utilidad Neta: a diferencia de la Utilidad Bruta (que cuenta toda venta
  /// activa en la fecha en que se hizo), la Neta solo reconoce un crédito
  /// cuando el dinero realmente entró, no cuando se prometió.
  Future<({double ventas, double costo})> _creditoCanceladoEnRango(DateTime inicio, DateTime finInclusive) async {
    final snap = await _db
        .collectionGroup('abonos')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive))
        .where('saldoPendiente', isEqualTo: 0)
        .get();
    final idsVenta = snap.docs.map((d) => d.reference.parent.parent!.id).toSet();
    if (idsVenta.isEmpty) return (ventas: 0.0, costo: 0.0);

    final ventaSnaps = await Future.wait(idsVenta.map((id) => _db.collection('ventas').doc(id).get()));
    // Detalle de todas las ventas canceladas en paralelo (antes se pedía una
    // por una, en secuencia, esperando cada respuesta antes de pedir la
    // siguiente).
    final detalleSnaps = await Future.wait(ventaSnaps.map((v) => v.exists ? v.reference.collection('detalle').get() : Future.value(null)));
    double ventas = 0, costo = 0;
    for (var i = 0; i < ventaSnaps.length; i++) {
      final ventaSnap = ventaSnaps[i];
      if (!ventaSnap.exists) continue;
      final data = ventaSnap.data()!;
      // Por si se anuló después de haberse cancelado (raro, pero el crédito
      // ya no existiría y no debería sumar).
      if (data['estado'] == 'Anulada') continue;
      ventas += ((data['totalAPagar'] ?? 0) as num).toDouble();
      final detalleSnap = detalleSnaps[i]!;
      for (final item in detalleSnap.docs) {
        final d = item.data();
        costo += ((d['precioCompraUsado'] ?? 0) as num).toDouble() * ((d['cantidad'] ?? 0) as num).toDouble();
      }
    }
    return (ventas: ventas, costo: costo);
  }

  Future<double> _efectivoEstimado() async {
    final estado = await _cierreCajaRepository.obtenerEstadoCaja();
    final hoy = DateTime.now();
    final finInclusive = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);
    final totales = await _cierreCajaRepository.calcularTotales(estado.fechaDesde, finInclusive);
    return estado.montoInicial + totales.ingresosEfectivo - totales.egresosEfectivo;
  }

  /// Reconstruye el flujo de efectivo con datos que ya se pidieron para el
  /// resto del reporte, en vez de recalcular todo el libro financiero de
  /// nuevo (mismo criterio que `CierreCajaRepository.calcularTotales`).
  FlujoEfectivo _calcularFlujo({
    required List<ReporteVentaModel> ventasContado,
    required List<ReporteCompraModel> comprasContado,
    required List<AbonoModel> abonosVenta,
    required List<AbonoCompraModel> abonosCompra,
    required List<EgresoModel> egresos,
  }) {
    double ingresosEfectivo = 0, ingresosTarjeta = 0, ingresosTransferencia = 0;
    double egresosEfectivo = 0, egresosTransferencia = 0;

    void sumarIngreso(String metodoPago, double monto) {
      switch (metodoPago) {
        case 'Efectivo':
          ingresosEfectivo += monto;
          break;
        case 'Tarjeta':
          ingresosTarjeta += monto;
          break;
        case 'Transferencia':
          ingresosTransferencia += monto;
          break;
      }
    }

    void sumarEgreso(String metodoPago, double monto) {
      switch (metodoPago) {
        case 'Efectivo':
          egresosEfectivo += monto;
          break;
        case 'Transferencia':
          egresosTransferencia += monto;
          break;
      }
    }

    for (final v in ventasContado) {
      sumarIngreso(v.metodoPago, v.totalAPagar);
    }
    for (final c in comprasContado) {
      sumarEgreso(c.metodoPago, c.montoTotal);
    }
    for (final a in abonosVenta) {
      sumarIngreso(a.metodoPago, a.montoAbonado);
    }
    for (final a in abonosCompra) {
      sumarEgreso(a.metodoPago, a.montoAbonado);
    }
    for (final e in egresos) {
      sumarEgreso(e.metodoPago, e.monto);
    }

    return FlujoEfectivo(
      ingresosEfectivo: ingresosEfectivo,
      ingresosTarjeta: ingresosTarjeta,
      ingresosTransferencia: ingresosTransferencia,
      egresosEfectivo: egresosEfectivo,
      egresosTransferencia: egresosTransferencia,
    );
  }

  Future<ReporteFinancieroData> obtenerReporte(DateTime inicio, DateTime finInclusive) async {
    // Todo lo que no depende de nada más se dispara en paralelo de una vez;
    // recién se espera por cada resultado donde hace falta.
    final ventasHeadersFuture = _reporteRepository.obtenerReporteVentas(inicio, finInclusive);
    final comprasHeadersFuture = _reporteRepository.obtenerReporteCompras(inicio, finInclusive);
    final detalleRapidoFuture = _detallePorRango(inicio, finInclusive);
    final egresosPeriodoFuture = _egresoRepository.obtenerEgresosPorRango(inicio, finInclusive);
    final abonosVentaFuture = _ventaCreditoRepository.obtenerAbonosPorRango(inicio, finInclusive);
    final abonosCompraFuture = _compraCreditoRepository.obtenerAbonosPorRango(inicio, finInclusive);
    final productosFuture = _db.collection('productos').get();
    final ventasCreditoFuture = _db.collection('ventasCredito').get();
    final comprasCreditoFuture = _db.collection('comprasCredito').get();
    final serieMensualFuture = _obtenerSerieMensual();
    final efectivoEstimadoFuture = _efectivoEstimado();
    final hace3Meses = DateTime(DateTime.now().year, DateTime.now().month - 2, 1);
    final egresosUltimos3MesesFuture = _egresoRepository.obtenerEgresosPorRango(hace3Meses, DateTime.now());
    final creditoCanceladoFuture = _creditoCanceladoEnRango(inicio, finInclusive);

    final ventasHeaders = await ventasHeadersFuture;
    final comprasHeaders = await comprasHeadersFuture;
    final detalleRapido = await detalleRapidoFuture;
    final egresosPeriodo = await egresosPeriodoFuture;
    final abonosVenta = await abonosVentaFuture;
    final abonosCompra = await abonosCompraFuture;
    final productosSnap = await productosFuture;
    final ventasCreditoSnap = await ventasCreditoFuture;
    final comprasCreditoSnap = await comprasCreditoFuture;
    final serieMensual = await serieMensualFuture;
    final efectivoEstimado = await efectivoEstimadoFuture;
    final egresosUltimos3Meses = await egresosUltimos3MesesFuture;
    final creditoCancelado = await creditoCanceladoFuture;

    final ventasValidas = ventasHeaders.where((v) => v.esActiva && !v.esCotizacion).toList();
    final comprasValidas = comprasHeaders.where((c) => c.esActiva).toList();

    final detalleVentasPorVenta = await _resolverDetalleVentas(ventasValidas, detalleRapido.ventas);
    final detalleComprasPorCompra = await _resolverDetalleCompras(comprasValidas, detalleRapido.compras);
    final itemsVenta = detalleVentasPorVenta.expand((items) => items).toList();
    final itemsCompra = detalleComprasPorCompra.expand((items) => items).toList();

    final gananciaPorVenta = <GananciaPorVenta>[
      for (var i = 0; i < ventasValidas.length; i++)
        GananciaPorVenta(
          idVenta: ventasValidas[i].id,
          numeroDocumento: ventasValidas[i].numeroDocumento,
          fecha: ventasValidas[i].fechaRegistro,
          cliente: ventasValidas[i].nombreCliente.isEmpty ? 'CONSUMIDOR FINAL' : ventasValidas[i].nombreCliente,
          ventas: ventasValidas[i].totalAPagar,
          costo: detalleVentasPorVenta[i].fold<double>(0, (s, item) => s + item.precioCompraUsado * item.cantidad),
        ),
    ]..sort((a, b) => (b.fecha ?? DateTime(2000)).compareTo(a.fecha ?? DateTime(2000)));

    final ventasPeriodo = ventasValidas.fold<double>(0, (s, v) => s + v.totalAPagar);
    final comprasPeriodo = comprasValidas.fold<double>(0, (s, c) => s + c.montoTotal);
    final costoVentas = itemsVenta.fold<double>(0, (s, i) => s + i.precioCompraUsado * i.cantidad);
    final utilidadBruta = ventasPeriodo - costoVentas;

    // Gastos operativos reales: las devoluciones por factura anulada quedan
    // afuera porque no son un gasto del negocio, son plata que nunca debió
    // contarse como ganada (la venta anulada ya no suma en ventasValidas).
    final gastosPeriodo = egresosPeriodo.where((e) => e.categoria != 'Devolución').fold<double>(0, (s, e) => s + e.monto);

    // Utilidad Neta usa una base de ingresos distinta a la Bruta: al contado
    // se reconoce en la fecha de la venta (igual que la Bruta), pero a
    // crédito recién cuando se termina de cobrar (ver
    // _creditoCanceladoEnRango) — no cuando se prometió la venta.
    double ventasNeta = 0, costoNeta = 0;
    for (var i = 0; i < ventasValidas.length; i++) {
      if (ventasValidas[i].condicion == 'Contado') {
        ventasNeta += ventasValidas[i].totalAPagar;
        costoNeta += detalleVentasPorVenta[i].fold<double>(0, (s, item) => s + item.precioCompraUsado * item.cantidad);
      }
    }
    ventasNeta += creditoCancelado.ventas;
    costoNeta += creditoCancelado.costo;
    final utilidadNeta = (ventasNeta - costoNeta) - gastosPeriodo;

    final flujoEfectivo = _calcularFlujo(
      ventasContado: ventasValidas.where((v) => v.condicion == 'Contado').toList(),
      comprasContado: comprasValidas.where((c) => c.condicion != 'Credito').toList(),
      abonosVenta: abonosVenta,
      abonosCompra: abonosCompra,
      egresos: egresosPeriodo,
    );

    final topVendidosPorCantidad = _rankearPorCantidad(itemsVenta.map((i) => (i.idProducto, i.nombreProducto, i.cantidad)));
    final topCompradosPorCantidad = _rankearPorCantidad(itemsCompra.map((i) => (i.idProducto, i.nombreProducto, i.cantidad)));
    final topGananciaPorProducto = _rankearGanancia(itemsVenta);

    final productos = productosSnap.docs.map((d) => ProductoModel.fromMap(d.id, d.data())).toList();
    final idsConVenta = itemsVenta.map((i) => i.idProducto).toSet();
    final productosSinVenta = productos
        .where((p) => p.estado && !idsConVenta.contains(p.id))
        .map((p) => ProductoSinVenta(idProducto: p.id, nombreProducto: p.nombre, stock: p.stock, valorInventario: p.stock * p.precioCompra))
        .toList()
      ..sort((a, b) => b.valorInventario.compareTo(a.valorInventario));
    final inventarioACosto = productos.where((p) => p.estado).fold<double>(0, (s, p) => s + p.stock * p.precioCompra);

    final ventasPorUsuario = _agruparPorUsuario(ventasValidas);

    final totalAbonosComprasCredito = abonosCompra.fold<double>(0, (s, a) => s + a.montoAbonado);
    final abonosPorProveedor = _agruparAbonosPorProveedor(abonosCompra);

    final reservaGastosFijos = egresosUltimos3Meses.fold<double>(0, (s, e) => s + e.monto) / 3;
    final colchon = efectivoEstimado * _colchonSeguridadPorcentaje;
    final sugeridoPorCaja = (efectivoEstimado - reservaGastosFijos - colchon).clamp(0, double.infinity).toDouble();
    final sugeridoPorVentas = flujoEfectivo.ingresosEfectivo * _porcentajeVentasParaProveedores;

    final recomendacionPago = RecomendacionPago(
      efectivoEstimado: efectivoEstimado,
      reservaGastosFijos: reservaGastosFijos,
      sugeridoPorCaja: sugeridoPorCaja,
      ingresoEfectivoCobrado: flujoEfectivo.ingresosEfectivo,
      sugeridoPorVentas: sugeridoPorVentas,
    );

    final cuentasPorCobrar = ventasCreditoSnap.docs.fold<double>(0, (s, d) => s + ((d.data()['saldoPendiente'] ?? 0) as num).toDouble().clamp(0, double.infinity));
    final cuentasPorPagar = comprasCreditoSnap.docs.fold<double>(0, (s, d) => s + ((d.data()['saldoPendiente'] ?? 0) as num).toDouble().clamp(0, double.infinity));

    final balanceGeneral = BalanceGeneral(
      inventarioACosto: inventarioACosto,
      cuentasPorCobrar: cuentasPorCobrar,
      efectivoEstimado: efectivoEstimado,
      cuentasPorPagar: cuentasPorPagar,
    );

    return ReporteFinancieroData(
      inicio: inicio,
      fin: finInclusive,
      ventasPeriodo: ventasPeriodo,
      comprasPeriodo: comprasPeriodo,
      costoVentas: costoVentas,
      utilidadBruta: utilidadBruta,
      gastosPeriodo: gastosPeriodo,
      utilidadNeta: utilidadNeta,
      flujoEfectivo: flujoEfectivo,
      serieMensual: serieMensual,
      gananciaPorVenta: gananciaPorVenta,
      topVendidosPorCantidad: topVendidosPorCantidad,
      topCompradosPorCantidad: topCompradosPorCantidad,
      topGananciaPorProducto: topGananciaPorProducto,
      productosSinVenta: productosSinVenta,
      ventasPorUsuario: ventasPorUsuario,
      totalAbonosComprasCredito: totalAbonosComprasCredito,
      abonosPorProveedor: abonosPorProveedor,
      recomendacionPago: recomendacionPago,
      balanceGeneral: balanceGeneral,
    );
  }

  List<RankingProducto> _rankearPorCantidad(Iterable<(String, String, double)> lineas) {
    final porProducto = <String, RankingProducto>{};
    for (final (idProducto, nombre, cantidad) in lineas) {
      final actual = porProducto[idProducto];
      porProducto[idProducto] = RankingProducto(
        idProducto: idProducto,
        nombreProducto: nombre,
        cantidad: (actual?.cantidad ?? 0) + cantidad,
        monto: 0,
      );
    }
    final lista = porProducto.values.toList()..sort((a, b) => b.cantidad.compareTo(a.cantidad));
    return lista.take(_topN).toList();
  }

  List<RankingProducto> _rankearGanancia(List<ItemVentaModel> items) {
    final ingresoPorProducto = <String, double>{};
    final costoPorProducto = <String, double>{};
    final cantidadPorProducto = <String, double>{};
    final nombrePorProducto = <String, String>{};
    for (final item in items) {
      ingresoPorProducto[item.idProducto] = (ingresoPorProducto[item.idProducto] ?? 0) + item.subtotal;
      costoPorProducto[item.idProducto] = (costoPorProducto[item.idProducto] ?? 0) + item.precioCompraUsado * item.cantidad;
      cantidadPorProducto[item.idProducto] = (cantidadPorProducto[item.idProducto] ?? 0) + item.cantidad;
      nombrePorProducto[item.idProducto] = item.nombreProducto;
    }
    final lista = ingresoPorProducto.keys
        .map((id) => RankingProducto(
              idProducto: id,
              nombreProducto: nombrePorProducto[id] ?? '',
              cantidad: cantidadPorProducto[id] ?? 0,
              monto: (ingresoPorProducto[id] ?? 0) - (costoPorProducto[id] ?? 0),
            ))
        .toList()
      ..sort((a, b) => b.monto.compareTo(a.monto));
    return lista.take(_topN).toList();
  }

  List<VentasPorUsuario> _agruparPorUsuario(List<ReporteVentaModel> ventas) {
    final totalPorUsuario = <String, double>{};
    final conteoPorUsuario = <String, int>{};
    for (final v in ventas) {
      final usuario = v.usuarioRegistro.isEmpty ? 'Sin usuario' : v.usuarioRegistro;
      totalPorUsuario[usuario] = (totalPorUsuario[usuario] ?? 0) + v.totalAPagar;
      conteoPorUsuario[usuario] = (conteoPorUsuario[usuario] ?? 0) + 1;
    }
    final lista = totalPorUsuario.keys
        .map((u) => VentasPorUsuario(usuario: u, totalVentas: totalPorUsuario[u] ?? 0, cantidadTransacciones: conteoPorUsuario[u] ?? 0))
        .toList()
      ..sort((a, b) => b.totalVentas.compareTo(a.totalVentas));
    return lista;
  }

  List<AbonoPorProveedor> _agruparAbonosPorProveedor(List<AbonoCompraModel> abonos) {
    final totalPorProveedor = <String, double>{};
    for (final a in abonos) {
      final proveedor = a.nombreProveedor.isEmpty ? 'N/A' : a.nombreProveedor;
      totalPorProveedor[proveedor] = (totalPorProveedor[proveedor] ?? 0) + a.montoAbonado;
    }
    final lista = totalPorProveedor.entries.map((e) => AbonoPorProveedor(proveedor: e.key, total: e.value)).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return lista;
  }

  Future<List<PuntoMensual>> _obtenerSerieMensual() async {
    final hoy = DateTime.now();
    final primerMesDeLaSerie = DateTime(hoy.year, hoy.month - 5, 1);
    final finRango = DateTime(hoy.year, hoy.month + 1, 1).subtract(const Duration(seconds: 1));

    // Independientes entre sí: en paralelo en vez de esperar una para recién
    // pedir la otra.
    final ventasFuture = _reporteRepository.obtenerReporteVentas(primerMesDeLaSerie, finRango);
    final comprasFuture = _reporteRepository.obtenerReporteCompras(primerMesDeLaSerie, finRango);
    final ventas = await ventasFuture;
    final compras = await comprasFuture;
    final ventasValidas = ventas.where((v) => v.esActiva && !v.esCotizacion);
    final comprasValidas = compras.where((c) => c.esActiva);

    final ventasPorMes = <String, double>{};
    for (final v in ventasValidas) {
      final fecha = v.fechaRegistro;
      if (fecha == null) continue;
      final clave = '${fecha.year}-${fecha.month}';
      ventasPorMes[clave] = (ventasPorMes[clave] ?? 0) + v.totalAPagar;
    }
    final comprasPorMes = <String, double>{};
    for (final c in comprasValidas) {
      final fecha = c.fechaRegistro;
      if (fecha == null) continue;
      final clave = '${fecha.year}-${fecha.month}';
      comprasPorMes[clave] = (comprasPorMes[clave] ?? 0) + c.montoTotal;
    }

    final serie = <PuntoMensual>[];
    for (var i = 0; i < 6; i++) {
      final mes = DateTime(primerMesDeLaSerie.year, primerMesDeLaSerie.month + i, 1);
      final clave = '${mes.year}-${mes.month}';
      serie.add(PuntoMensual(mes: mes, totalVentas: ventasPorMes[clave] ?? 0, totalCompras: comprasPorMes[clave] ?? 0));
    }
    return serie;
  }
}
