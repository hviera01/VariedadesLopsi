import 'package:cloud_firestore/cloud_firestore.dart';

/// Los cuatro tipos de promoción que puede armar el Mantenedor:
/// - [porcentaje]: % de descuento sobre uno o varios productos.
/// - [precioFijo]: precio especial (no porcentaje) sobre uno o varios
///   productos.
/// - [comboCantidad]: "llevando N unidades de X, se lleva Y" — Y son
///   unidades adicionales del MISMO producto X, gratis (ej. 3x2).
/// - [regalo]: "si lleva X, se regala Y" — Y es OTRO producto distinto,
///   regalado al comprar X.
enum TipoPromocion { porcentaje, precioFijo, comboCantidad, regalo }

extension TipoPromocionStorage on TipoPromocion {
  String get valor => name;

  static TipoPromocion desde(String v) {
    return TipoPromocion.values.firstWhere((t) => t.name == v, orElse: () => TipoPromocion.porcentaje);
  }
}

/// Una promoción configurada en Mantenedor > Descuentos y Promociones.
///
/// [idsProductos] tiene un solo significado por tipo: en [TipoPromocion.porcentaje]
/// y [TipoPromocion.precioFijo] son TODOS los productos alcanzados por el
/// descuento; en [TipoPromocion.comboCantidad] y [TipoPromocion.regalo] es
/// un solo producto (el "X" de la condición — "llevando N de X").
///
/// [condicionRestringida] vacío significa "todos los métodos de pago"; si
/// no, vale 'Contado' o 'Credito' (mismos valores que
/// CarritoVentaState.condicion / ReporteVentaModel.condicion — no confundir
/// con metodoPago, que distingue Efectivo/Tarjeta/Transferencia dentro de
/// Contado).
class PromocionModel {
  final String id;
  final String nombre;
  final TipoPromocion tipo;
  final List<String> idsProductos;
  final List<String> nombresProductos;
  final double porcentajeDescuento;
  final double precioFijo;
  final int cantidadRequerida;
  final int cantidadBeneficio;
  final String idProductoRegalo;
  final String nombreProductoRegalo;
  final int cantidadRegalo;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final String condicionRestringida;
  final bool activa;
  final DateTime? fechaRegistro;
  final String usuarioRegistro;

  PromocionModel({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.idsProductos,
    this.nombresProductos = const [],
    this.porcentajeDescuento = 0,
    this.precioFijo = 0,
    this.cantidadRequerida = 1,
    this.cantidadBeneficio = 1,
    this.idProductoRegalo = '',
    this.nombreProductoRegalo = '',
    this.cantidadRegalo = 1,
    required this.fechaInicio,
    this.fechaFin,
    this.condicionRestringida = '',
    this.activa = true,
    this.fechaRegistro,
    this.usuarioRegistro = '',
  });

  bool get esIndefinida => fechaFin == null;

  /// Vigente por fecha (y activa a mano): [ahora] por defecto es el
  /// instante actual, parametrizable para pruebas y para no repetir
  /// `DateTime.now()` en cada evaluación de un carrito con varios productos.
  bool vigente([DateTime? ahora]) {
    if (!activa) return false;
    final now = ahora ?? DateTime.now();
    final inicioDelDia = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    if (now.isBefore(inicioDelDia)) return false;
    final fin = fechaFin;
    if (fin != null) {
      final finDelDia = DateTime(fin.year, fin.month, fin.day, 23, 59, 59);
      if (now.isAfter(finDelDia)) return false;
    }
    return true;
  }

  bool aplicaACondicion(String condicion) => condicionRestringida.isEmpty || condicionRestringida == condicion;

  bool aplicaAProducto(String idProducto) => idsProductos.contains(idProducto);

  factory PromocionModel.fromMap(String id, Map<String, dynamic> data) {
    return PromocionModel(
      id: id,
      nombre: data['nombre'] ?? '',
      tipo: TipoPromocionStorage.desde(data['tipo'] ?? ''),
      idsProductos: List<String>.from(data['idsProductos'] ?? const []),
      nombresProductos: List<String>.from(data['nombresProductos'] ?? const []),
      porcentajeDescuento: (data['porcentajeDescuento'] ?? 0).toDouble(),
      precioFijo: (data['precioFijo'] ?? 0).toDouble(),
      cantidadRequerida: (data['cantidadRequerida'] ?? 1).toInt(),
      cantidadBeneficio: (data['cantidadBeneficio'] ?? 1).toInt(),
      idProductoRegalo: data['idProductoRegalo'] ?? '',
      nombreProductoRegalo: data['nombreProductoRegalo'] ?? '',
      cantidadRegalo: (data['cantidadRegalo'] ?? 1).toInt(),
      fechaInicio: (data['fechaInicio'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaFin: (data['fechaFin'] as Timestamp?)?.toDate(),
      condicionRestringida: data['condicionRestringida'] ?? '',
      activa: data['activa'] ?? true,
      fechaRegistro: (data['fechaRegistro'] as Timestamp?)?.toDate(),
      usuarioRegistro: data['usuarioRegistro'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'tipo': tipo.valor,
      'idsProductos': idsProductos,
      'nombresProductos': nombresProductos,
      'porcentajeDescuento': porcentajeDescuento,
      'precioFijo': precioFijo,
      'cantidadRequerida': cantidadRequerida,
      'cantidadBeneficio': cantidadBeneficio,
      'idProductoRegalo': idProductoRegalo,
      'nombreProductoRegalo': nombreProductoRegalo,
      'cantidadRegalo': cantidadRegalo,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaFin': fechaFin == null ? null : Timestamp.fromDate(fechaFin!),
      'condicionRestringida': condicionRestringida,
      'activa': activa,
      'usuarioRegistro': usuarioRegistro,
    };
  }

  PromocionModel copyWith({
    String? nombre,
    TipoPromocion? tipo,
    List<String>? idsProductos,
    List<String>? nombresProductos,
    double? porcentajeDescuento,
    double? precioFijo,
    int? cantidadRequerida,
    int? cantidadBeneficio,
    String? idProductoRegalo,
    String? nombreProductoRegalo,
    int? cantidadRegalo,
    DateTime? fechaInicio,
    Object? fechaFin = _sinCambio,
    String? condicionRestringida,
    bool? activa,
  }) {
    return PromocionModel(
      id: id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      idsProductos: idsProductos ?? this.idsProductos,
      nombresProductos: nombresProductos ?? this.nombresProductos,
      porcentajeDescuento: porcentajeDescuento ?? this.porcentajeDescuento,
      precioFijo: precioFijo ?? this.precioFijo,
      cantidadRequerida: cantidadRequerida ?? this.cantidadRequerida,
      cantidadBeneficio: cantidadBeneficio ?? this.cantidadBeneficio,
      idProductoRegalo: idProductoRegalo ?? this.idProductoRegalo,
      nombreProductoRegalo: nombreProductoRegalo ?? this.nombreProductoRegalo,
      cantidadRegalo: cantidadRegalo ?? this.cantidadRegalo,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin == _sinCambio ? this.fechaFin : fechaFin as DateTime?,
      condicionRestringida: condicionRestringida ?? this.condicionRestringida,
      activa: activa ?? this.activa,
      fechaRegistro: fechaRegistro,
      usuarioRegistro: usuarioRegistro,
    );
  }
}

const _sinCambio = Object();
