import 'package:cloud_firestore/cloud_firestore.dart';
import 'cliente_model.dart';
import 'movimiento_puntos_model.dart';

class ClienteRepository {
  final _col = FirebaseFirestore.instance.collection('clientes');

  Stream<List<ClienteModel>> obtenerClientes() {
    return _col.orderBy('nombreCompleto').snapshots().map((snap) {
      return snap.docs.map((d) => ClienteModel.fromMap(d.id, d.data())).toList();
    });
  }

  Future<void> crear({
    required String dni,
    required String nombreCompleto,
    required String correo,
    required String telefono,
    required bool estado,
  }) async {
    if (dni.isNotEmpty) {
      final existe = await _col.where('dni', isEqualTo: dni).limit(1).get();
      if (existe.docs.isNotEmpty) {
        throw Exception('Ya existe un cliente con ese DNI');
      }
    }
    await _col.add({
      'dni': dni,
      'nombreCompleto': nombreCompleto,
      'correo': correo,
      'telefono': telefono,
      'estado': estado,
      'fechaRegistro': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizar({
    required String id,
    required String dni,
    required String nombreCompleto,
    required String correo,
    required String telefono,
    required bool estado,
  }) async {
    if (dni.isNotEmpty) {
      final existe = await _col.where('dni', isEqualTo: dni).limit(2).get();
      final duplicado = existe.docs.any((d) => d.id != id);
      if (duplicado) {
        throw Exception('Ya existe un cliente con ese DNI');
      }
    }
    await _col.doc(id).update({
      'dni': dni,
      'nombreCompleto': nombreCompleto,
      'correo': correo,
      'telefono': telefono,
      'estado': estado,
    });
  }

  Future<void> eliminar(String id) async {
    await _col.doc(id).delete();
  }

  Stream<List<MovimientoPuntosModel>> obtenerMovimientosPuntos(String idCliente) {
    return _col.doc(idCliente).collection('puntos_movimientos').orderBy('fecha', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => MovimientoPuntosModel.fromMap(d.id, d.data())).toList();
    });
  }

  /// Registra un movimiento de puntos (positivo = acumulación, negativo =
  /// canje o ajuste a la baja) y actualiza `saldoPuntos` del cliente, todo
  /// atómico. Si se pasa [transaction] (por ejemplo desde
  /// `VentaRepository.registrarVenta`, para que la acumulación quede en la
  /// misma transacción que la venta que la generó) se usa esa transacción en
  /// vez de abrir una nueva — Firestore no permite anidar transacciones.
  /// IMPORTANTE si se pasa [transaction]: la lectura del cliente (`get`) que
  /// hace este método debe poder ejecutarse ANTES de cualquier escritura ya
  /// hecha en esa transacción (regla de Firestore: todas las lecturas antes
  /// que las escrituras) — por eso [snapshotCliente] permite pasar un
  /// snapshot ya leído de antemano en el mismo batch de lecturas iniciales,
  /// evitando una lectura tardía a mitad de transacción.
  Future<double> registrarMovimientoPuntos({
    Transaction? transaction,
    DocumentSnapshot<Map<String, dynamic>>? snapshotCliente,
    required String idCliente,
    required double puntos,
    required String tipo,
    required String descripcion,
    required String usuario,
    String usuarioAutoriza = '',
    String idVentaRelacionada = '',
  }) async {
    final clienteRef = _col.doc(idCliente);

    Future<double> operar(Transaction tx) async {
      final snap = snapshotCliente ?? await tx.get(clienteRef);
      final saldoActual = ((snap.data()?['saldoPuntos'] ?? 0) as num).toDouble();
      final saldoNuevo = saldoActual + puntos;
      tx.update(clienteRef, {'saldoPuntos': saldoNuevo});
      final movRef = clienteRef.collection('puntos_movimientos').doc();
      tx.set(movRef, {
        'puntos': puntos,
        'saldoResultante': saldoNuevo,
        'tipo': tipo,
        'descripcion': descripcion,
        'usuario': usuario,
        'usuarioAutoriza': usuarioAutoriza,
        'idVentaRelacionada': idVentaRelacionada,
        'fecha': FieldValue.serverTimestamp(),
      });
      return saldoNuevo;
    }

    if (transaction != null) {
      return operar(transaction);
    }
    return FirebaseFirestore.instance.runTransaction((tx) => operar(tx));
  }
}
