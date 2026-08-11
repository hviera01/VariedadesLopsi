import '../../caja/data/cierre_caja_model.dart';

/// Un producto dentro de un ranking (más vendido, más comprado o más
/// rentable). El campo `monto` cambia de significado según el ranking en el
/// que aparezca (ingreso, costo o ganancia) — lo interpreta quien arma la
/// lista, no el modelo.
class RankingProducto {
  final String idProducto;
  final String nombreProducto;
  final double cantidad;
  final double monto;

  RankingProducto({required this.idProducto, required this.nombreProducto, required this.cantidad, required this.monto});
}

class ProductoSinVenta {
  final String idProducto;
  final String nombreProducto;
  final double stock;
  final double valorInventario;

  ProductoSinVenta({required this.idProducto, required this.nombreProducto, required this.stock, required this.valorInventario});
}

class VentasPorUsuario {
  final String usuario;
  final double totalVentas;
  final int cantidadTransacciones;
  final double totalEfectivo;
  final double totalTarjeta;
  final double totalTransferencia;

  VentasPorUsuario({
    required this.usuario,
    required this.totalVentas,
    required this.cantidadTransacciones,
    this.totalEfectivo = 0,
    this.totalTarjeta = 0,
    this.totalTransferencia = 0,
  });
}

/// Ganancia de una venta individual: para responder "qué tan rentable fue
/// esta venta puntual", no solo el agregado del periodo.
class GananciaPorVenta {
  final String idVenta;
  final String numeroDocumento;
  final DateTime? fecha;
  final String cliente;
  final double ventas;
  final double costo;

  GananciaPorVenta({required this.idVenta, required this.numeroDocumento, required this.fecha, required this.cliente, required this.ventas, required this.costo});

  double get ganancia => ventas - costo;
  double get margenPorcentaje => ventas <= 0 ? 0 : (ganancia / ventas) * 100;
}

class AbonoPorProveedor {
  final String proveedor;
  final double total;

  AbonoPorProveedor({required this.proveedor, required this.total});
}

/// Un mes de la serie de comparación (últimos 6 meses, terminando en el
/// actual). `costoVentas` alimenta la tendencia de margen bruto mensual de
/// Inteligencia de Negocios — se calcula junto con el resto de la serie
/// (ver ReporteFinancieroRepository._calcularSerieMensual) para no repetir
/// la consulta de detalle.
class PuntoMensual {
  final DateTime mes;
  final double totalVentas;
  final double totalCompras;
  final double costoVentas;

  PuntoMensual({required this.mes, required this.totalVentas, required this.totalCompras, this.costoVentas = 0});

  double get utilidadBruta => totalVentas - costoVentas;
  double get margenPorcentaje => totalVentas <= 0 ? 0 : (utilidadBruta / totalVentas) * 100;
}

/// Proyección de ventas del próximo mes por regresión lineal simple sobre
/// los meses ya cerrados de [PuntoMensual] (ver
/// ReporteFinancieroRepository._calcularPronostico): no es Machine Learning,
/// es la recta que mejor ajusta la tendencia reciente, para dar una idea
/// razonable de hacia dónde van las ventas sin prometer precisión que el
/// negocio no necesita.
class PronosticoVentas {
  final double proximoMes;
  final double promedioMensual;
  // Cuánto sube (positivo) o baja (negativo) el promedio mensual de ventas
  // de un mes al siguiente, según la tendencia reciente.
  final double tendenciaMensual;

  PronosticoVentas({required this.proximoMes, required this.promedioMensual, required this.tendenciaMensual});

  bool get tendenciaAlAlza => tendenciaMensual > 0;
}

/// Un producto candidato a reponer: se calcula sobre una ventana fija de 90
/// días (independiente del rango elegido en el reporte, ver
/// ReporteFinancieroRepository._calcularVelocidadYProveedores) para no
/// sugerir compras en base a un solo día de ventas.
class ProductoSugerenciaCompra {
  final String idProducto;
  final String nombreProducto;
  final double stock;
  final double ventaDiariaPromedio;
  final double diasDeStock;
  final String nombreProveedor;
  final bool proveedorConDeudaVencida;
  final double montoVencidoProveedor;

  ProductoSugerenciaCompra({
    required this.idProducto,
    required this.nombreProducto,
    required this.stock,
    required this.ventaDiariaPromedio,
    required this.diasDeStock,
    required this.nombreProveedor,
    required this.proveedorConDeudaVencida,
    required this.montoVencidoProveedor,
  });
}

/// Un cliente identificado (con DNI o al menos nombre) dentro del rango del
/// reporte — "Consumidor Final" sin datos no cuenta como cliente recurrente,
/// ver ReporteFinancieroRepository._calcularTopClientes.
class ClienteTop {
  final String nombre;
  final String documento;
  final double totalComprado;
  final int cantidadCompras;

  ClienteTop({required this.nombre, required this.documento, required this.totalComprado, required this.cantidadCompras});
}

/// Analítica agregada para la sección "Inteligencia de Negocios": todo se
/// deriva de datos que el reporte financiero ya necesita (ventas, compras,
/// inventario, cuentas por pagar), sin colecciones ni consultas nuevas por
/// fuera del patrón ya usado en el resto de este archivo.
class InteligenciaNegocioData {
  final PronosticoVentas pronostico;
  final RankingProducto? productoMasRentable;
  final List<ProductoSugerenciaCompra> sugerenciasCompra;
  // Veces al año que se estima que rota el inventario, al ritmo de venta
  // del rango elegido en el reporte.
  final double rotacionInventarioAnual;
  final double diasInventario;
  final List<ClienteTop> topClientes;

  InteligenciaNegocioData({
    required this.pronostico,
    required this.productoMasRentable,
    required this.sugerenciasCompra,
    required this.rotacionInventarioAnual,
    required this.diasInventario,
    required this.topClientes,
  });
}

class FlujoEfectivo {
  final double ingresosEfectivo;
  final double ingresosTarjeta;
  final double ingresosTransferencia;
  final double egresosEfectivo;
  final double egresosTransferencia;

  FlujoEfectivo({
    required this.ingresosEfectivo,
    required this.ingresosTarjeta,
    required this.ingresosTransferencia,
    required this.egresosEfectivo,
    required this.egresosTransferencia,
  });

  double get totalIngresos => ingresosEfectivo + ingresosTarjeta + ingresosTransferencia;
  double get totalEgresos => egresosEfectivo + egresosTransferencia;
  double get neto => totalIngresos - totalEgresos;
}

/// Balance general simplificado: no reemplaza un balance contable formal (no
/// hay partida doble, activos fijos ni capital aportado en el sistema). El
/// patrimonio es el residuo Activos − Pasivos, no una cuenta llevada aparte.
class BalanceGeneral {
  final double inventarioACosto;
  final double cuentasPorCobrar;
  final double efectivoEstimado;
  final double cuentasPorPagar;

  BalanceGeneral({
    required this.inventarioACosto,
    required this.cuentasPorCobrar,
    required this.efectivoEstimado,
    required this.cuentasPorPagar,
  });

  double get totalActivos => inventarioACosto + cuentasPorCobrar + efectivoEstimado;
  double get totalPasivos => cuentasPorPagar;
  double get patrimonio => totalActivos - totalPasivos;
}

/// Resultado agregado completo del Reporte Financiero para un rango de
/// fechas. Se calcula una sola vez y lo consumen tanto la pantalla como el
/// PDF, para no recalcular ni arriesgar que muestren números distintos.
class ReporteFinancieroData {
  final DateTime inicio;
  final DateTime fin;

  final double ventasPeriodo;
  final double comprasPeriodo;
  final double costoVentas;
  final double utilidadBruta;
  // Base de la Utilidad Neta: distinta de ventasPeriodo/costoVentas (esos
  // son de la Utilidad Bruta, que cuenta todo crédito activo aunque no se
  // haya cobrado) — acá solo entra lo de contado más el crédito que se
  // terminó de cobrar en el rango. Mismas columnas que el reporte de
  // Utilidad Neta del sistema viejo (Total Ventas/Total Costos/Total
  // Egresos/Utilidad Neta).
  final double ventasNeta;
  final double costoNeta;
  final double gastosPeriodo;
  final double utilidadNeta;

  final FlujoEfectivo flujoEfectivo;
  final List<PuntoMensual> serieMensual;

  final List<RankingProducto> topVendidosPorCantidad;
  final List<RankingProducto> topCompradosPorCantidad;
  final List<RankingProducto> topGananciaPorProducto;
  final List<ProductoSinVenta> productosSinVenta;

  final List<GananciaPorVenta> gananciaPorVenta;
  final List<VentasPorUsuario> ventasPorUsuario;

  final double totalAbonosComprasCredito;
  final List<AbonoPorProveedor> abonosPorProveedor;

  final List<CierreCajaModel> cierresCaja;
  final BalanceGeneral balanceGeneral;
  final InteligenciaNegocioData inteligencia;

  ReporteFinancieroData({
    required this.inicio,
    required this.fin,
    required this.ventasPeriodo,
    required this.comprasPeriodo,
    required this.costoVentas,
    required this.utilidadBruta,
    required this.ventasNeta,
    required this.costoNeta,
    required this.gastosPeriodo,
    required this.utilidadNeta,
    required this.flujoEfectivo,
    required this.serieMensual,
    required this.gananciaPorVenta,
    required this.topVendidosPorCantidad,
    required this.topCompradosPorCantidad,
    required this.topGananciaPorProducto,
    required this.productosSinVenta,
    required this.ventasPorUsuario,
    required this.totalAbonosComprasCredito,
    required this.abonosPorProveedor,
    required this.cierresCaja,
    required this.balanceGeneral,
    required this.inteligencia,
  });

  double get margenBrutoPorcentaje => ventasPeriodo <= 0 ? 0 : (utilidadBruta / ventasPeriodo) * 100;
}
