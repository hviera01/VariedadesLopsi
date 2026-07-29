import 'package:cloud_firestore/cloud_firestore.dart';

/// Un movimiento del ledger de puntos de fidelización de un cliente
/// (subcolección `clientes/{id}/puntos_movimientos`). Cada acumulación,
/// canje o ajuste manual queda como una fila propia — el saldo actual
/// (`ClienteModel.saldoPuntos`) es solo un total desnormalizado para
/// consulta rápida, este ledger es la fuente de verdad histórica.
class MovimientoPuntosModel {
  final String id;
  // Positivo = acumulación (venta), negativo = canje o ajuste manual a la baja.
  final double puntos;
  final double saldoResultante;
  final String tipo; // 'Acumulacion' | 'Canje' | 'AjusteManual'
  final String descripcion;
  final String usuario;
  // Usuario que autorizó (clave especial, ver verificarAccesoEspecial) un
  // ajuste manual. Vacío en acumulaciones y canjes normales.
  final String usuarioAutoriza;
  final String idVentaRelacionada;
  final DateTime? fecha;

  MovimientoPuntosModel({
    required this.id,
    required this.puntos,
    required this.saldoResultante,
    required this.tipo,
    required this.descripcion,
    required this.usuario,
    this.usuarioAutoriza = '',
    this.idVentaRelacionada = '',
    required this.fecha,
  });

  factory MovimientoPuntosModel.fromMap(String id, Map<String, dynamic> data) {
    return MovimientoPuntosModel(
      id: id,
      puntos: (data['puntos'] ?? 0).toDouble(),
      saldoResultante: (data['saldoResultante'] ?? 0).toDouble(),
      tipo: data['tipo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      usuario: data['usuario'] ?? '',
      usuarioAutoriza: data['usuarioAutoriza'] ?? '',
      idVentaRelacionada: data['idVentaRelacionada'] ?? '',
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
    );
  }
}
