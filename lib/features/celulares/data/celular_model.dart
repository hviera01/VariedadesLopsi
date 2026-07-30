import 'package:cloud_firestore/cloud_firestore.dart';

/// Estados posibles de un celular en trazabilidad por IMEI. Se guardan como
/// String en Firestore (no un enum de Dart) para poder leerlos/filtrarlos
/// directo con queries si algún día hace falta, mismo criterio que el resto
/// del proyecto (ver PermisosEspeciales en negocio_model.dart).
class EstadoCelular {
  static const disponible = 'DISPONIBLE';
  static const malEstado = 'MAL_ESTADO';
  static const vendido = 'VENDIDO';
  static const inactivo = 'INACTIVO';
  static const devuelto = 'DEVUELTO';

  static const List<String> todos = [disponible, malEstado, vendido, inactivo, devuelto];

  static const Map<String, String> etiquetas = {
    disponible: 'Disponible',
    malEstado: 'Mal Estado',
    vendido: 'Vendido',
    inactivo: 'Inactivo',
    devuelto: 'Devuelto',
  };
}

/// Celular en trazabilidad por IMEI: módulo independiente del catálogo de
/// Productos/Compras/Venta — no tiene precio, no descuenta stock y no genera
/// ingreso en ningún reporte de ventas. `nombreClienteFinal` es texto libre
/// (no una FK a la colección de clientes reales), igual que `proveedor`.
class CelularModel {
  final String id;
  final String codigo;
  final String proveedor;
  final String marca;
  final String modelo;
  final String color;
  final String imei;
  final String notas;
  final DateTime? fechaCompra;
  final String nombreClienteFinal;
  final DateTime? fechaVenta;
  final String estado;
  final String usuarioReg;
  final DateTime? fechaRegistro;
  final DateTime? fechaActualizacion;

  CelularModel({
    required this.id,
    required this.codigo,
    required this.proveedor,
    required this.marca,
    required this.modelo,
    required this.color,
    required this.imei,
    this.notas = '',
    this.fechaCompra,
    this.nombreClienteFinal = '',
    this.fechaVenta,
    this.estado = EstadoCelular.disponible,
    this.usuarioReg = '',
    this.fechaRegistro,
    this.fechaActualizacion,
  });

  factory CelularModel.fromMap(String id, Map<String, dynamic> data) {
    return CelularModel(
      id: id,
      codigo: data['codigo'] ?? '',
      proveedor: data['proveedor'] ?? '',
      marca: data['marca'] ?? '',
      modelo: data['modelo'] ?? '',
      color: data['color'] ?? '',
      imei: data['imei'] ?? '',
      notas: data['notas'] ?? '',
      fechaCompra: (data['fechaCompra'] as Timestamp?)?.toDate(),
      nombreClienteFinal: data['nombreClienteFinal'] ?? '',
      fechaVenta: (data['fechaVenta'] as Timestamp?)?.toDate(),
      estado: data['estado'] ?? EstadoCelular.disponible,
      usuarioReg: data['usuarioReg'] ?? '',
      fechaRegistro: (data['fechaRegistro'] as Timestamp?)?.toDate(),
      fechaActualizacion: (data['fechaActualizacion'] as Timestamp?)?.toDate(),
    );
  }

  String get textoBusqueda => '$codigo $marca $modelo $imei $proveedor';
}
