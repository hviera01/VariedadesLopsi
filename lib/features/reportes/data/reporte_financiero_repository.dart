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
import '../../compras_credito/data/compra_credito_model.dart';
import '../../ventas_credito/data/venta_credito_repository.dart';
import '../../ventas_credito/data/abono_model.dart';
import '../../caja/data/cierre_caja_repository.dart';
import '../../caja/data/cierre_caja_model.dart';

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

  // La serie mensual y el efectivo estimado no dependen del rango que el
  // usuario elija en el reporte (son "últimos 6 meses" y "desde el último
  // cierre de caja" respectivamente), así que antes se recalculaban desde
  // cero en cada búsqueda aunque el usuario solo hubiera cambiado el rango
  // principal. Se cachean un rato corto para no repetir esas consultas.
  static const _vigenciaCache = Duration(minutes: 5);
  List<PuntoMensual>? _serieMensualCache;
  DateTime? _serieMensualCacheEn;
  double? _efectivoEstimadoCache;
  DateTime? _efectivoEstimadoCacheEn;
  // El catálogo completo de productos (para inventario a costo y productos
  // sin venta) tampoco depende del rango de fechas elegido, pero antes se
  // volvía a traer entero de Firestore en cada "Generar" del reporte
  // financiero, sin cache: en un catálogo grande esa sola consulta podía ser
  // el costo dominante de todo el reporte. Mismo criterio de cache corto que
  // la serie mensual/efectivo estimado de arriba.
  List<ProductoModel>? _productosCache;
  DateTime? _productosCacheEn;
  // Cuentas por cobrar/pagar (Balance General): son un saldo actual, no
  // dependen del rango de fechas elegido -antes se releían por completo en
  // cada "Generar", aunque el usuario solo hubiera cambiado el rango
  // principal-. Mismo criterio de cache corto que arriba.
  QuerySnapshot<Map<String, dynamic>>? _ventasCreditoCache;
  DateTime? _ventasCreditoCacheEn;
  QuerySnapshot<Map<String, dynamic>>? _comprasCreditoCache;
  DateTime? _comprasCreditoCacheEn;

  Future<List<ProductoModel>> _obtenerProductosCacheados() async {
    final ahora = DateTime.now();
    final cache = _productosCache;
    final cacheEn = _productosCacheEn;
    if (cache != null && cacheEn != null && ahora.difference(cacheEn) < _vigenciaCache) {
      return cache;
    }
    final snap = await _db.collection('productos').get();
    final productos = snap.docs.map((d) => ProductoModel.fromMap(d.id, d.data())).toList();
    _productosCache = productos;
    _productosCacheEn = ahora;
    return productos;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _ventasCreditoAbiertasCacheadas() async {
    final ahora = DateTime.now();
    final cache = _ventasCreditoCache;
    final cacheEn = _ventasCreditoCacheEn;
    if (cache != null && cacheEn != null && ahora.difference(cacheEn) < _vigenciaCache) {
      return cache;
    }
    final snap = await _db.collection('ventasCredito').where('saldoPendiente', isGreaterThan: 0).get();
    _ventasCreditoCache = snap;
    _ventasCreditoCacheEn = ahora;
    return snap;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _comprasCreditoAbiertasCacheadas() async {
    final ahora = DateTime.now();
    final cache = _comprasCreditoCache;
    final cacheEn = _comprasCreditoCacheEn;
    if (cache != null && cacheEn != null && ahora.difference(cacheEn) < _vigenciaCache) {
      return cache;
    }
    final snap = await _db.collection('comprasCredito').where('saldoPendiente', isGreaterThan: 0).get();
    _comprasCreditoCache = snap;
    _comprasCreditoCacheEn = ahora;
    return snap;
  }

  /// Cierres de caja del rango elegido (por fechaFin), más recientes primero,
  /// para la pestaña "Cierres de Caja" del Reporte Financiero.
  Future<List<CierreCajaModel>> _cierresCajaPorRango(DateTime inicio, DateTime finInclusive) async {
    final snap = await _db
        .collection('cierresCaja')
        .where('fechaFin', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fechaFin', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive))
        .orderBy('fechaFin', descending: true)
        .get();
    return snap.docs.map((d) => CierreCajaModel.fromMap(d.id, d.data())).toList();
  }

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
    final cacheEn = _efectivoEstimadoCacheEn;
    if (_efectivoEstimadoCache != null && cacheEn != null && DateTime.now().difference(cacheEn) < _vigenciaCache) {
      return _efectivoEstimadoCache!;
    }
    final estado = await _cierreCajaRepository.obtenerEstadoCaja();
    final hoy = DateTime.now();
    final finInclusive = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);
    final totales = await _cierreCajaRepository.calcularTotales(estado.fechaDesde, finInclusive);
    final resultado = estado.montoInicial + totales.ingresosEfectivo - totales.egresosEfectivo;
    _efectivoEstimadoCache = resultado;
    _efectivoEstimadoCacheEn = DateTime.now();
    return resultado;
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
      if (v.metodoPago == 'Mixto' && v.pagosMixtos.isNotEmpty) {
        for (final pago in v.pagosMixtos) {
          sumarIngreso(pago.metodoPago, pago.monto);
        }
      } else {
        sumarIngreso(v.metodoPago, v.totalAPagar);
      }
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
    final productosFuture = _obtenerProductosCacheados();
    // Solo interesan para sumar saldoPendiente (cuentas por cobrar/pagar), así
    // que se filtran del lado del servidor los créditos ya saldados en vez de
    // traer la colección completa (con historial largo, la mayoría termina
    // pagada) y descartarlos recién en el cliente.
    final ventasCreditoFuture = _ventasCreditoAbiertasCacheadas();
    final comprasCreditoFuture = _comprasCreditoAbiertasCacheadas();
    final serieMensualFuture = _obtenerSerieMensual();
    final efectivoEstimadoFuture = _efectivoEstimado();
    final creditoCanceladoFuture = _creditoCanceladoEnRango(inicio, finInclusive);
    final cierresCajaFuture = _cierresCajaPorRango(inicio, finInclusive);

    final ventasHeaders = await ventasHeadersFuture;
    final comprasHeaders = await comprasHeadersFuture;
    final detalleRapido = await detalleRapidoFuture;
    final egresosPeriodo = await egresosPeriodoFuture;
    final abonosVenta = await abonosVentaFuture;
    final abonosCompra = await abonosCompraFuture;
    final productos = await productosFuture;
    final ventasCreditoSnap = await ventasCreditoFuture;
    final comprasCreditoSnap = await comprasCreditoFuture;
    final serieMensual = await serieMensualFuture;
    final efectivoEstimado = await efectivoEstimadoFuture;
    final creditoCancelado = await creditoCanceladoFuture;
    final cierresCaja = await cierresCajaFuture;

    // Igual que sp_ReporteUtilidadBruta del sistema viejo: activas, sin
    // contar Cotización (todavía no es una venta concretada) ni Canje (no
    // genera ingreso real, se paga con puntos).
    final ventasValidas = ventasHeaders.where((v) => v.esActiva && !v.esCotizacion && !v.esCanje).toList();
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

    final cuentasPorCobrar = ventasCreditoSnap.docs.fold<double>(0, (s, d) => s + ((d.data()['saldoPendiente'] ?? 0) as num).toDouble().clamp(0, double.infinity));
    final cuentasPorPagar = comprasCreditoSnap.docs.fold<double>(0, (s, d) => s + ((d.data()['saldoPendiente'] ?? 0) as num).toDouble().clamp(0, double.infinity));

    final balanceGeneral = BalanceGeneral(
      inventarioACosto: inventarioACosto,
      cuentasPorCobrar: cuentasPorCobrar,
      efectivoEstimado: efectivoEstimado,
      cuentasPorPagar: cuentasPorPagar,
    );

    // Inteligencia de Negocios: todo se arma con datos que ya se pidieron
    // arriba para el resto del reporte, salvo la velocidad de venta/
    // proveedor por producto (cacheada 5 min, ver
    // _obtenerVelocidadYProveedoresCacheado) que necesita su propia ventana
    // fija de 90 días.
    final sugerenciasCompra = await _calcularSugerenciasCompra(productos, comprasCreditoSnap);
    final pronostico = _calcularPronostico(serieMensual);
    final topClientes = _calcularTopClientes(ventasValidas);
    // Rotación anualizada: se proyecta el costo de ventas del rango elegido
    // a un año completo y se compara contra el inventario a costo actual —
    // mismo criterio que un índice de rotación de inventario clásico
    // (costo de ventas anual / inventario), adaptado a que el usuario puede
    // elegir cualquier rango de fechas.
    final diasEnRango = finInclusive.difference(inicio).inDays + 1;
    final costoVentasAnualizado = diasEnRango > 0 ? costoVentas / diasEnRango * 365 : 0.0;
    final rotacionInventarioAnual = inventarioACosto > 0 ? costoVentasAnualizado / inventarioACosto : 0.0;
    final diasInventario = rotacionInventarioAnual > 0 ? 365 / rotacionInventarioAnual : 0.0;

    final inteligencia = InteligenciaNegocioData(
      pronostico: pronostico,
      productoMasRentable: topGananciaPorProducto.isEmpty ? null : topGananciaPorProducto.first,
      sugerenciasCompra: sugerenciasCompra,
      rotacionInventarioAnual: rotacionInventarioAnual,
      diasInventario: diasInventario,
      topClientes: topClientes,
    );

    return ReporteFinancieroData(
      inicio: inicio,
      fin: finInclusive,
      ventasPeriodo: ventasPeriodo,
      comprasPeriodo: comprasPeriodo,
      costoVentas: costoVentas,
      utilidadBruta: utilidadBruta,
      ventasNeta: ventasNeta,
      costoNeta: costoNeta,
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
      cierresCaja: cierresCaja,
      balanceGeneral: balanceGeneral,
      inteligencia: inteligencia,
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

  // Igual que sp_ReporteVentasPorVendedor del sistema viejo: desglosa el
  // total de cada usuario por método de pago, no solo el total general. Una
  // venta con pago Mixto reparte su monto entre los métodos reales de
  // pagosMixtos en vez de contarla entera bajo "Mixto" (que no es un método
  // real al que atribuirle una columna).
  List<VentasPorUsuario> _agruparPorUsuario(List<ReporteVentaModel> ventas) {
    final totalPorUsuario = <String, double>{};
    final conteoPorUsuario = <String, int>{};
    final efectivoPorUsuario = <String, double>{};
    final tarjetaPorUsuario = <String, double>{};
    final transferenciaPorUsuario = <String, double>{};
    for (final v in ventas) {
      final usuario = v.usuarioRegistro.isEmpty ? 'Sin usuario' : v.usuarioRegistro;
      totalPorUsuario[usuario] = (totalPorUsuario[usuario] ?? 0) + v.totalAPagar;
      conteoPorUsuario[usuario] = (conteoPorUsuario[usuario] ?? 0) + 1;

      void sumar(String metodo, double monto) {
        switch (metodo) {
          case 'Efectivo':
            efectivoPorUsuario[usuario] = (efectivoPorUsuario[usuario] ?? 0) + monto;
            break;
          case 'Tarjeta':
            tarjetaPorUsuario[usuario] = (tarjetaPorUsuario[usuario] ?? 0) + monto;
            break;
          case 'Transferencia':
            transferenciaPorUsuario[usuario] = (transferenciaPorUsuario[usuario] ?? 0) + monto;
            break;
        }
      }

      if (v.metodoPago == 'Mixto' && v.pagosMixtos.isNotEmpty) {
        for (final pago in v.pagosMixtos) {
          sumar(pago.metodoPago, pago.monto);
        }
      } else {
        sumar(v.metodoPago, v.totalAPagar);
      }
    }
    final lista = totalPorUsuario.keys
        .map((u) => VentasPorUsuario(
              usuario: u,
              totalVentas: totalPorUsuario[u] ?? 0,
              cantidadTransacciones: conteoPorUsuario[u] ?? 0,
              totalEfectivo: efectivoPorUsuario[u] ?? 0,
              totalTarjeta: tarjetaPorUsuario[u] ?? 0,
              totalTransferencia: transferenciaPorUsuario[u] ?? 0,
            ))
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
    final cacheEn = _serieMensualCacheEn;
    if (_serieMensualCache != null && cacheEn != null && DateTime.now().difference(cacheEn) < _vigenciaCache) {
      return _serieMensualCache!;
    }
    final resultado = await _calcularSerieMensual();
    _serieMensualCache = resultado;
    _serieMensualCacheEn = DateTime.now();
    return resultado;
  }

  Future<List<PuntoMensual>> _calcularSerieMensual() async {
    final hoy = DateTime.now();
    final primerMesDeLaSerie = DateTime(hoy.year, hoy.month - 5, 1);
    final finRango = DateTime(hoy.year, hoy.month + 1, 1).subtract(const Duration(seconds: 1));

    // Independientes entre sí: en paralelo en vez de esperar una para recién
    // pedir la otra. detalleFuture (una sola consulta collectionGroup, mismo
    // criterio que _detallePorRango) trae el costo de cada venta del rango
    // para poder calcular el margen bruto mes a mes (Inteligencia de
    // Negocios), sin repetir la consulta de detalle que ya hace el resto del
    // reporte para el rango elegido por el usuario.
    final ventasFuture = _reporteRepository.obtenerReporteVentas(primerMesDeLaSerie, finRango);
    final comprasFuture = _reporteRepository.obtenerReporteCompras(primerMesDeLaSerie, finRango);
    final detalleFuture = _detallePorRango(primerMesDeLaSerie, finRango);
    final ventas = await ventasFuture;
    final compras = await comprasFuture;
    final detalle = await detalleFuture;
    final ventasValidas = ventas.where((v) => v.esActiva && !v.esCotizacion && !v.esCanje).toList();
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
    final detalleVentasPorVenta = await _resolverDetalleVentas(ventasValidas, detalle.ventas);
    final costoPorMes = <String, double>{};
    for (var i = 0; i < ventasValidas.length; i++) {
      final fecha = ventasValidas[i].fechaRegistro;
      if (fecha == null) continue;
      final clave = '${fecha.year}-${fecha.month}';
      final costo = detalleVentasPorVenta[i].fold<double>(0, (s, item) => s + item.precioCompraUsado * item.cantidad);
      costoPorMes[clave] = (costoPorMes[clave] ?? 0) + costo;
    }

    final serie = <PuntoMensual>[];
    for (var i = 0; i < 6; i++) {
      final mes = DateTime(primerMesDeLaSerie.year, primerMesDeLaSerie.month + i, 1);
      final clave = '${mes.year}-${mes.month}';
      serie.add(PuntoMensual(mes: mes, totalVentas: ventasPorMes[clave] ?? 0, totalCompras: comprasPorMes[clave] ?? 0, costoVentas: costoPorMes[clave] ?? 0));
    }
    return serie;
  }

  // ---------- Inteligencia de Negocios ----------

  // Ventana fija de 90 días (independiente del rango que el usuario haya
  // elegido en el reporte, mismo criterio que la serie mensual/efectivo
  // estimado de arriba): cuánto se vendió de cada producto recientemente
  // (para estimar cuántos días de stock quedan) y de qué proveedor vino su
  // compra más reciente (para poder avisar si ese proveedor tiene cuentas
  // vencidas antes de sugerir comprarle más). Cacheada con el mismo criterio
  // corto que el resto de este archivo.
  ({Map<String, double> ventasPorProducto, Map<String, (String idProveedor, String nombreProveedor)> proveedorPorProducto})? _velocidadCache;
  DateTime? _velocidadCacheEn;

  Future<({Map<String, double> ventasPorProducto, Map<String, (String idProveedor, String nombreProveedor)> proveedorPorProducto})> _obtenerVelocidadYProveedoresCacheado() async {
    final ahora = DateTime.now();
    final cacheEn = _velocidadCacheEn;
    if (_velocidadCache != null && cacheEn != null && ahora.difference(cacheEn) < _vigenciaCache) {
      return _velocidadCache!;
    }
    final resultado = await _calcularVelocidadYProveedores();
    _velocidadCache = resultado;
    _velocidadCacheEn = ahora;
    return resultado;
  }

  static const _diasVentanaOperativa = 90;

  Future<({Map<String, double> ventasPorProducto, Map<String, (String idProveedor, String nombreProveedor)> proveedorPorProducto})> _calcularVelocidadYProveedores() async {
    final ahora = DateTime.now();
    final inicio = ahora.subtract(const Duration(days: _diasVentanaOperativa));

    final ventasHeadersFuture = _reporteRepository.obtenerReporteVentas(inicio, ahora);
    final comprasHeadersFuture = _reporteRepository.obtenerReporteCompras(inicio, ahora);
    final detalleFuture = _detallePorRango(inicio, ahora);
    final ventasHeaders = await ventasHeadersFuture;
    final comprasHeaders = await comprasHeadersFuture;
    final detalle = await detalleFuture;

    final ventasPorProducto = <String, double>{};
    for (final v in ventasHeaders.where((v) => v.esActiva && !v.esCotizacion && !v.esCanje)) {
      for (final item in detalle.ventas[v.id] ?? const []) {
        ventasPorProducto[item.idProducto] = (ventasPorProducto[item.idProducto] ?? 0) + item.cantidad;
      }
    }

    // Ordenadas de más vieja a más nueva para que, al recorrerlas, la
    // proveedora que quede guardada por producto sea siempre la de la
    // compra más reciente.
    final comprasValidas = comprasHeaders.where((c) => c.esActiva).toList()
      ..sort((a, b) => (a.fechaRegistro ?? DateTime(2000)).compareTo(b.fechaRegistro ?? DateTime(2000)));
    final proveedorPorProducto = <String, (String, String)>{};
    for (final c in comprasValidas) {
      for (final item in detalle.compras[c.id] ?? const []) {
        proveedorPorProducto[item.idProducto] = (c.idProveedor, c.razonSocial);
      }
    }

    return (ventasPorProducto: ventasPorProducto, proveedorPorProducto: proveedorPorProducto);
  }

  /// Productos a reponer: solo entran los que tuvieron venta real en los
  /// últimos [_diasVentanaOperativa] días (sin venta reciente no hay
  /// velocidad que estimar) y a quienes el stock actual les alcanza para
  /// menos de dos semanas a ese ritmo. Se ordenan por urgencia (menos días
  /// de stock primero) y, a igual urgencia, se prioriza el producto cuyo
  /// proveedor está al día sobre el que tiene saldo vencido — no se oculta
  /// la sugerencia (el negocio igual necesita reponer), solo se avisa y se
  /// pospone frente a las que no tienen ese riesgo.
  Future<List<ProductoSugerenciaCompra>> _calcularSugerenciasCompra(
    List<ProductoModel> productos,
    QuerySnapshot<Map<String, dynamic>> comprasCreditoAbiertasSnap,
  ) async {
    final velocidad = await _obtenerVelocidadYProveedoresCacheado();

    final vencidoPorProveedor = <String, double>{};
    for (final d in comprasCreditoAbiertasSnap.docs) {
      final cc = CompraCreditoModel.fromMap(d.id, d.data());
      if (cc.vencida) vencidoPorProveedor[cc.idProveedor] = (vencidoPorProveedor[cc.idProveedor] ?? 0) + cc.saldoPendiente;
    }

    final sugerencias = <ProductoSugerenciaCompra>[];
    for (final p in productos) {
      if (!p.estado) continue;
      final vendidos = velocidad.ventasPorProducto[p.id] ?? 0;
      if (vendidos <= 0) continue;
      final velocidadDiaria = vendidos / _diasVentanaOperativa;
      final diasDeStock = p.stock / velocidadDiaria;
      if (diasDeStock > 14) continue;
      final infoProveedor = velocidad.proveedorPorProducto[p.id];
      final montoVencido = infoProveedor == null ? 0.0 : (vencidoPorProveedor[infoProveedor.$1] ?? 0);
      sugerencias.add(ProductoSugerenciaCompra(
        idProducto: p.id,
        nombreProducto: p.nombre,
        stock: p.stock,
        ventaDiariaPromedio: velocidadDiaria,
        diasDeStock: diasDeStock,
        nombreProveedor: infoProveedor?.$2 ?? '',
        proveedorConDeudaVencida: montoVencido > 0,
        montoVencidoProveedor: montoVencido,
      ));
    }
    sugerencias.sort((a, b) {
      final porUrgencia = a.diasDeStock.compareTo(b.diasDeStock);
      if (porUrgencia != 0) return porUrgencia;
      return (a.proveedorConDeudaVencida ? 1 : 0).compareTo(b.proveedorConDeudaVencida ? 1 : 0);
    });
    return sugerencias.take(15).toList();
  }

  /// Regresión lineal simple sobre los meses ya cerrados de la serie mensual
  /// (se descarta el último punto: es el mes en curso, todavía incompleto,
  /// y usarlo como dato de entrenamiento sesgaría la proyección a la baja).
  /// Con menos de dos meses cerrados no hay tendencia que calcular: se
  /// proyecta plano, igual al promedio disponible.
  PronosticoVentas _calcularPronostico(List<PuntoMensual> serieMensual) {
    if (serieMensual.isEmpty) {
      return PronosticoVentas(proximoMes: 0, promedioMensual: 0, tendenciaMensual: 0);
    }
    final cerrados = serieMensual.length > 1 ? serieMensual.sublist(0, serieMensual.length - 1) : serieMensual;
    final valores = [for (final p in cerrados) p.totalVentas];
    final n = valores.length;
    final promedio = valores.fold<double>(0, (s, v) => s + v) / n;
    if (n < 2) {
      return PronosticoVentas(proximoMes: promedio, promedioMensual: promedio, tendenciaMensual: 0);
    }

    final xMedia = (n - 1) / 2.0;
    var numerador = 0.0, denominador = 0.0;
    for (var i = 0; i < n; i++) {
      numerador += (i - xMedia) * (valores[i] - promedio);
      denominador += (i - xMedia) * (i - xMedia);
    }
    final pendiente = denominador == 0 ? 0.0 : numerador / denominador;
    final interseccion = promedio - pendiente * xMedia;
    // Los meses cerrados ocupan las posiciones 0..n-1; la posición n es el
    // mes en curso (excluido del entrenamiento); el próximo mes a proyectar
    // es la posición n+1.
    final proyeccion = interseccion + pendiente * (n + 1);
    return PronosticoVentas(proximoMes: proyeccion < 0 ? 0 : proyeccion, promedioMensual: promedio, tendenciaMensual: pendiente);
  }

  /// Clientes identificados (con DNI o al menos nombre) que más compraron en
  /// el rango del reporte. "Consumidor Final" sin ningún dato no cuenta como
  /// cliente recurrente para este ranking.
  List<ClienteTop> _calcularTopClientes(List<ReporteVentaModel> ventas) {
    final totalPorClave = <String, double>{};
    final conteoPorClave = <String, int>{};
    final nombrePorClave = <String, String>{};
    for (final v in ventas) {
      final clave = v.documentoCliente.isNotEmpty ? v.documentoCliente : v.nombreCliente;
      if (clave.isEmpty) continue;
      totalPorClave[clave] = (totalPorClave[clave] ?? 0) + v.totalAPagar;
      conteoPorClave[clave] = (conteoPorClave[clave] ?? 0) + 1;
      nombrePorClave[clave] = v.nombreCliente.isEmpty ? 'CONSUMIDOR FINAL' : v.nombreCliente;
    }
    final lista = totalPorClave.keys
        .map((k) => ClienteTop(nombre: nombrePorClave[k]!, documento: k, totalComprado: totalPorClave[k]!, cantidadCompras: conteoPorClave[k] ?? 0))
        .toList()
      ..sort((a, b) => b.totalComprado.compareTo(a.totalComprado));
    return lista.take(10).toList();
  }
}
