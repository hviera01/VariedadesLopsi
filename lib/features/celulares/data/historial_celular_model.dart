import 'package:cloud_firestore/cloud_firestore.dart';

/// Fila del historial de cambios de estado de un celular (subcolección
/// `celulares/{id}/historial`), mismo patrón que HistorialStockModel de
/// Productos.
class HistorialCelularModel {
  final String id;
  final String estadoAnterior;
  final String estadoNuevo;
  final String observacion;
  final String nombreClienteFinal;
  final DateTime? fechaVenta;
  final String usuario;
  final DateTime? fecha;

  HistorialCelularModel({
    required this.id,
    required this.estadoAnterior,
    required this.estadoNuevo,
    this.observacion = '',
    this.nombreClienteFinal = '',
    this.fechaVenta,
    required this.usuario,
    this.fecha,
  });

  factory HistorialCelularModel.fromMap(String id, Map<String, dynamic> data) {
    return HistorialCelularModel(
      id: id,
      estadoAnterior: data['estadoAnterior'] ?? '',
      estadoNuevo: data['estadoNuevo'] ?? '',
      observacion: data['observacion'] ?? '',
      nombreClienteFinal: data['nombreClienteFinal'] ?? '',
      fechaVenta: (data['fechaVenta'] as Timestamp?)?.toDate(),
      usuario: data['usuario'] ?? '',
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
    );
  }
}
