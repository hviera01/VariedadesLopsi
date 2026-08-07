class ProductoModel {
  final String id;
  final String codigo;
  final String codigoBarras;
  final String nombre;
  final String descripcion;
  final String idCategoria;
  final double stock;
  final double precioCompra;
  final double precioVenta;
  final double precioVenta2;
  final double precioVenta3;
  // Precio del producto expresado en puntos de fidelización, para el modo
  // "Canje" de Registrar Venta (ver sistema de puntos). 0 = no configurado
  // para canje.
  final double precioPuntos;
  final bool estado;
  final String imagenUrl;

  ProductoModel({
    required this.id,
    required this.codigo,
    required this.codigoBarras,
    required this.nombre,
    required this.descripcion,
    required this.idCategoria,
    required this.stock,
    required this.precioCompra,
    required this.precioVenta,
    required this.precioVenta2,
    required this.precioVenta3,
    this.precioPuntos = 0,
    required this.estado,
    this.imagenUrl = '',
  });

  factory ProductoModel.fromMap(String id, Map<String, dynamic> data) {
    return ProductoModel(
      id: id,
      codigo: data['codigo'] ?? '',
      codigoBarras: data['codigoBarras'] ?? '',
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      idCategoria: data['idCategoria'] ?? '',
      stock: (data['stock'] ?? 0).toDouble(),
      precioCompra: (data['precioCompra'] ?? 0).toDouble(),
      precioVenta: (data['precioVenta'] ?? 0).toDouble(),
      precioVenta2: (data['precioVenta2'] ?? 0).toDouble(),
      precioVenta3: (data['precioVenta3'] ?? 0).toDouble(),
      precioPuntos: (data['precioPuntos'] ?? 0).toDouble(),
      estado: data['estado'] ?? true,
      imagenUrl: data['imagenUrl'] ?? '',
    );
  }

  String get textoBusqueda => '$codigo $codigoBarras $nombre $descripcion';

  /// Precio de venta según el nivel de precio activo (1, 2 o 3). Si el nivel
  /// pedido no tiene precio configurado (0), cae al primer nivel disponible
  /// probando 1, 2 y 3 en orden — mismo fallback que ya usaba el selector de
  /// nivel de precio del diálogo de búsqueda.
  double precioSegunNivel(int nivel) {
    final directo = switch (nivel) {
      2 => precioVenta2,
      3 => precioVenta3,
      _ => precioVenta,
    };
    if (directo > 0) return directo;
    for (final candidato in [precioVenta, precioVenta2, precioVenta3]) {
      if (candidato > 0) return candidato;
    }
    return 0;
  }
}