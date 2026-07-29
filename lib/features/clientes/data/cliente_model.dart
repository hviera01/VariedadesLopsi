class ClienteModel {
  final String id;
  final String dni;
  final String nombreCompleto;
  final String correo;
  final String telefono;
  final bool estado;
  // Saldo de puntos de fidelización, desnormalizado para no tener que sumar
  // todo el ledger (ver MovimientoPuntosModel) en cada consulta. Se actualiza
  // atómicamente junto con cada movimiento, mismo patrón que productos.stock.
  final double saldoPuntos;

  ClienteModel({
    required this.id,
    required this.dni,
    required this.nombreCompleto,
    required this.correo,
    required this.telefono,
    required this.estado,
    this.saldoPuntos = 0,
  });

  factory ClienteModel.fromMap(String id, Map<String, dynamic> data) {
    return ClienteModel(
      id: id,
      dni: data['dni'] ?? '',
      nombreCompleto: data['nombreCompleto'] ?? '',
      correo: data['correo'] ?? '',
      telefono: data['telefono'] ?? '',
      estado: data['estado'] ?? true,
      saldoPuntos: (data['saldoPuntos'] ?? 0).toDouble(),
    );
  }

  String get textoBusqueda => '$dni $nombreCompleto $correo $telefono';
}
