import 'package:cloud_firestore/cloud_firestore.dart';

/// Los tipos de promoción que puede armar el Mantenedor:
/// - [porcentaje]: % de descuento sobre uno o varios productos.
/// - [precioFijo]: precio especial (no porcentaje) sobre uno o varios
///   productos.
/// - [comboCantidad]: "llevando N unidades de X, se lleva Y" — Y son
///   unidades adicionales del MISMO producto X, gratis (ej. 3x2).
/// - [comboMultiproducto]: "llevando 1 de CADA UNO de 2+ productos
///   DISTINTOS, el paquete completo cuesta [precioCombo]" — a diferencia de
///   [comboCantidad] (mismo producto repetido), acá cada producto del combo
///   es distinto y se necesita 1 unidad de cada uno.
/// - [regalo]: "si lleva X, se regalan Y (uno o varios productos distintos)"
///   — [idsProductosRegalo] se regalan al comprar X.
enum TipoPromocion { porcentaje, precioFijo, comboCantidad, comboMultiproducto, regalo }

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
/// un solo producto (el "X" de la condición — "llevando N de X"). En
/// [TipoPromocion.comboMultiproducto] no se usa: los productos del combo
/// viven en [idsProductosCombo].
///
/// [condicionRestringida] vacío significa "todos" (Contado/Crédito); si no,
/// vale 'Contado' o 'Credito' (mismos valores que
/// CarritoVentaState.condicion / ReporteVentaModel.condicion). Es un filtro
/// independiente de [metodoPagoRestringido] (vacío = todos, o si no
/// 'Efectivo'/'Tarjeta'/'Transferencia', mismos valores que
/// CarritoVentaState.metodoPago salvo 'Mixto', que nunca matchea un alcance
/// específico) — para que una promoción aplique, tienen que cumplirse AMBOS.
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
  // Combo de productos distintos (comboMultiproducto): 2+ productos, 1
  // unidad de cada uno por combo, a [precioCombo] (precio total del
  // paquete).
  final List<String> idsProductosCombo;
  final List<String> nombresProductosCombo;
  final double precioCombo;
  final List<String> idsProductosRegalo;
  final List<String> nombresProductosRegalo;
  final int cantidadRegalo;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final String condicionRestringida;
  final String metodoPagoRestringido;
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
    this.idsProductosCombo = const [],
    this.nombresProductosCombo = const [],
    this.precioCombo = 0,
    this.idsProductosRegalo = const [],
    this.nombresProductosRegalo = const [],
    this.cantidadRegalo = 1,
    required this.fechaInicio,
    this.fechaFin,
    this.condicionRestringida = '',
    this.metodoPagoRestringido = '',
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

  // 'Mixto' nunca matchea un alcance específico (Efectivo/Tarjeta/
  // Transferencia): solo vacío/Todos.
  bool aplicaMetodoPago(String metodoPago) {
    if (metodoPagoRestringido.isEmpty) return true;
    return metodoPagoRestringido == metodoPago;
  }

  bool aplicaAProducto(String idProducto) => idsProductos.contains(idProducto) || idsProductosCombo.contains(idProducto);

  factory PromocionModel.fromMap(String id, Map<String, dynamic> data) {
    // Compatibilidad con promociones de regalo creadas antes de que
    // idsProductosRegalo existiera (era idProductoRegalo, un solo string):
    // si el documento viejo no tiene la lista nueva pero sí el campo
    // antiguo con algo adentro, se migra a una lista de un elemento al
    // leerlo, sin tocar Firestore.
    final idProductoRegaloViejo = data['idProductoRegalo'] as String? ?? '';
    final idsProductosRegalo = data['idsProductosRegalo'] != null
        ? List<String>.from(data['idsProductosRegalo'])
        : (idProductoRegaloViejo.isEmpty ? const <String>[] : [idProductoRegaloViejo]);
    final nombreProductoRegaloViejo = data['nombreProductoRegalo'] as String? ?? '';
    final nombresProductosRegalo = data['nombresProductosRegalo'] != null
        ? List<String>.from(data['nombresProductosRegalo'])
        : (nombreProductoRegaloViejo.isEmpty ? const <String>[] : [nombreProductoRegaloViejo]);
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
      idsProductosCombo: List<String>.from(data['idsProductosCombo'] ?? const []),
      nombresProductosCombo: List<String>.from(data['nombresProductosCombo'] ?? const []),
      precioCombo: (data['precioCombo'] ?? 0).toDouble(),
      idsProductosRegalo: idsProductosRegalo,
      nombresProductosRegalo: nombresProductosRegalo,
      cantidadRegalo: (data['cantidadRegalo'] ?? 1).toInt(),
      fechaInicio: (data['fechaInicio'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaFin: (data['fechaFin'] as Timestamp?)?.toDate(),
      condicionRestringida: data['condicionRestringida'] ?? '',
      metodoPagoRestringido: data['metodoPagoRestringido'] ?? '',
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
      'idsProductosCombo': idsProductosCombo,
      'nombresProductosCombo': nombresProductosCombo,
      'precioCombo': precioCombo,
      'idsProductosRegalo': idsProductosRegalo,
      'nombresProductosRegalo': nombresProductosRegalo,
      'cantidadRegalo': cantidadRegalo,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaFin': fechaFin == null ? null : Timestamp.fromDate(fechaFin!),
      'condicionRestringida': condicionRestringida,
      'metodoPagoRestringido': metodoPagoRestringido,
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
    List<String>? idsProductosCombo,
    List<String>? nombresProductosCombo,
    double? precioCombo,
    List<String>? idsProductosRegalo,
    List<String>? nombresProductosRegalo,
    int? cantidadRegalo,
    DateTime? fechaInicio,
    Object? fechaFin = _sinCambio,
    String? condicionRestringida,
    String? metodoPagoRestringido,
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
      idsProductosCombo: idsProductosCombo ?? this.idsProductosCombo,
      nombresProductosCombo: nombresProductosCombo ?? this.nombresProductosCombo,
      precioCombo: precioCombo ?? this.precioCombo,
      idsProductosRegalo: idsProductosRegalo ?? this.idsProductosRegalo,
      nombresProductosRegalo: nombresProductosRegalo ?? this.nombresProductosRegalo,
      cantidadRegalo: cantidadRegalo ?? this.cantidadRegalo,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin == _sinCambio ? this.fechaFin : fechaFin as DateTime?,
      condicionRestringida: condicionRestringida ?? this.condicionRestringida,
      metodoPagoRestringido: metodoPagoRestringido ?? this.metodoPagoRestringido,
      activa: activa ?? this.activa,
      fechaRegistro: fechaRegistro,
      usuarioRegistro: usuarioRegistro,
    );
  }
}

const _sinCambio = Object();
