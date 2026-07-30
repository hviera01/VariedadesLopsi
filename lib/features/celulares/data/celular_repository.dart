import 'package:cloud_firestore/cloud_firestore.dart';
import 'celular_model.dart';
import 'historial_celular_model.dart';

class CelularRepository {
  final _db = FirebaseFirestore.instance;
  final _col = FirebaseFirestore.instance.collection('celulares');
  final _colContadores = FirebaseFirestore.instance.collection('contadores');

  String _formatearCorrelativo(int numero) => 'CEL-${numero.toString().padLeft(6, '0')}';

  Stream<List<CelularModel>> obtenerCelulares() {
    return _col.orderBy('fechaRegistro', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => CelularModel.fromMap(d.id, d.data())).toList();
    });
  }

  /// Da de alta un celular nuevo: código correlativo propio (contador
  /// `contadores/celular`, mismo patrón que `contadores/venta` en
  /// VentaRepository) y estado inicial DISPONIBLE.
  Future<CelularModel> crear({
    required String proveedor,
    required String marca,
    required String modelo,
    required String color,
    required String imei,
    String notas = '',
    required DateTime fechaCompra,
    required String usuario,
  }) async {
    final contadorRef = _colContadores.doc('celular');
    final ref = _col.doc();
    late String codigo;

    await _db.runTransaction((transaction) async {
      final contadorSnap = await transaction.get(contadorRef);
      final actual = ((contadorSnap.data()?['ultimo'] ?? 0) as num).toInt();
      final nuevo = actual + 1;
      codigo = _formatearCorrelativo(nuevo);

      transaction.set(contadorRef, {'ultimo': nuevo}, SetOptions(merge: true));
      transaction.set(ref, {
        'codigo': codigo,
        'proveedor': proveedor.trim(),
        'marca': marca.trim(),
        'modelo': modelo.trim(),
        'color': color.trim(),
        'imei': imei.trim(),
        'notas': notas.trim(),
        'fechaCompra': Timestamp.fromDate(fechaCompra),
        'nombreClienteFinal': '',
        'fechaVenta': null,
        'estado': EstadoCelular.disponible,
        'usuarioReg': usuario,
        'fechaRegistro': FieldValue.serverTimestamp(),
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
    });

    return CelularModel(
      id: ref.id,
      codigo: codigo,
      proveedor: proveedor.trim(),
      marca: marca.trim(),
      modelo: modelo.trim(),
      color: color.trim(),
      imei: imei.trim(),
      notas: notas.trim(),
      fechaCompra: fechaCompra,
      estado: EstadoCelular.disponible,
      usuarioReg: usuario,
    );
  }

  Future<void> actualizar({
    required String id,
    required String proveedor,
    required String marca,
    required String modelo,
    required String color,
    required String imei,
    String notas = '',
    required DateTime fechaCompra,
  }) async {
    await _col.doc(id).update({
      'proveedor': proveedor.trim(),
      'marca': marca.trim(),
      'modelo': modelo.trim(),
      'color': color.trim(),
      'imei': imei.trim(),
      'notas': notas.trim(),
      'fechaCompra': Timestamp.fromDate(fechaCompra),
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<HistorialCelularModel>> obtenerHistorial(String idCelular) {
    return _col.doc(idCelular).collection('historial').orderBy('fecha', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => HistorialCelularModel.fromMap(d.id, d.data())).toList();
    });
  }

  /// Cambia el estado de un celular de forma atómica: actualiza el doc y
  /// agrega la fila de historial en la misma transacción (mismo patrón que
  /// `ajustarStock` en ProductoRepository). Para VENDIDO se manda
  /// [nombreClienteFinal] y [fechaVenta]; para los demás cambios de estado
  /// (Devuelto/MalEstado/Inactivo/Disponible) solo aplica [observacion].
  Future<void> cambiarEstado({
    required String id,
    required String estadoAnterior,
    required String estadoNuevo,
    required String usuario,
    String observacion = '',
    String? nombreClienteFinal,
    DateTime? fechaVenta,
  }) async {
    final ref = _col.doc(id);
    await _db.runTransaction((transaction) async {
      final datosActualizar = <String, dynamic>{
        'estado': estadoNuevo,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      };
      if (nombreClienteFinal != null) datosActualizar['nombreClienteFinal'] = nombreClienteFinal.trim();
      if (fechaVenta != null) datosActualizar['fechaVenta'] = Timestamp.fromDate(fechaVenta);

      transaction.update(ref, datosActualizar);
      final historialRef = ref.collection('historial').doc();
      transaction.set(historialRef, {
        'estadoAnterior': estadoAnterior,
        'estadoNuevo': estadoNuevo,
        'observacion': observacion.trim(),
        'nombreClienteFinal': nombreClienteFinal?.trim() ?? '',
        'fechaVenta': fechaVenta != null ? Timestamp.fromDate(fechaVenta) : null,
        'usuario': usuario,
        'fecha': FieldValue.serverTimestamp(),
      });
    });
  }
}
