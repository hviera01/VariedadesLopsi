import 'package:cloud_firestore/cloud_firestore.dart';
import 'promocion_model.dart';

class PromocionRepository {
  final _col = FirebaseFirestore.instance.collection('promociones');

  // En vivo (sin autoDispose, un solo listener global para toda la app,
  // mismo criterio que productosStreamProvider/categoriasStreamProvider):
  // el vendedor tiene que ver al instante una promoción nueva que un
  // administrador acabe de activar, o una que se acabe de desactivar, sin
  // tener que reabrir la pantalla de Registrar Venta.
  Stream<List<PromocionModel>> obtenerPromociones() {
    return _col.orderBy('fechaRegistro', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => PromocionModel.fromMap(d.id, d.data())).toList();
    });
  }

  Future<void> crear(PromocionModel promo) async {
    await _col.add({...promo.toMap(), 'fechaRegistro': FieldValue.serverTimestamp()});
  }

  Future<void> actualizar(PromocionModel promo) async {
    await _col.doc(promo.id).update(promo.toMap());
  }

  Future<void> eliminar(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> establecerActiva(String id, bool activa) async {
    await _col.doc(id).update({'activa': activa});
  }
}
