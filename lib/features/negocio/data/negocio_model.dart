import 'package:cloud_firestore/cloud_firestore.dart';

class PermisosEspeciales {
  static const inventarioEditarProducto = 'inventario_editar_producto';
  static const inventarioAjustarStock = 'inventario_ajustar_stock';
  static const ventasCreditoEliminar = 'ventas_credito_eliminar';
  static const ventasCambiarPrecio = 'ventas_cambiar_precio';
  static const ventasEditarDescripcion = 'ventas_editar_descripcion';
  static const ventasVenderSinStock = 'ventas_vender_sin_stock';
  static const actualizarPuntos = 'actualizar_puntos';

  // Claves nuevas para el rol Encargado (Fase 4): a diferencia de las de
  // arriba, estas no gatillan el diálogo de clave especial compartida, sino
  // que se usan como `accionKey` de `puedeRealizarAccion` (ver
  // core/utils/permisos_usuario.dart) para ocultar botones de crear/editar/
  // eliminar según lo que el Administrador marcó para ese usuario puntual.
  static const comprasCrear = 'compras_crear';
  static const comprasEditar = 'compras_editar';
  static const comprasEliminar = 'compras_eliminar';
  static const inventarioCrearProducto = 'inventario_crear_producto';
  static const inventarioEliminarProducto = 'inventario_eliminar_producto';
  static const clientesCrear = 'clientes_crear';
  static const clientesEditar = 'clientes_editar';
  static const clientesEliminar = 'clientes_eliminar';
  static const ventasEliminar = 'ventas_eliminar';

  static const Map<String, String> etiquetas = {
    inventarioEditarProducto: 'Editar productos en Inventario',
    inventarioAjustarStock: 'Cambiar existencias en Inventario',
    ventasCreditoEliminar: 'Eliminar créditos en Ventas a Crédito',
    ventasCambiarPrecio: 'Cambiar precio de un producto en Ventas',
    ventasEditarDescripcion: 'Editar descripción de un producto en Ventas',
    ventasVenderSinStock: 'Agregar a una venta un producto sin existencia',
    actualizarPuntos: 'Ajustar puntos de un cliente a mano',
    comprasCrear: 'Registrar compras',
    comprasEditar: 'Editar compras',
    comprasEliminar: 'Anular compras',
    inventarioCrearProducto: 'Crear productos en Inventario',
    inventarioEliminarProducto: 'Eliminar productos en Inventario',
    clientesCrear: 'Crear clientes',
    clientesEditar: 'Editar clientes',
    clientesEliminar: 'Eliminar clientes',
    ventasEliminar: 'Anular ventas',
  };

  static const Map<String, String> descripciones = {
    inventarioEditarProducto: 'Pide la clave especial antes de guardar cambios en un producto existente.',
    inventarioAjustarStock: 'Pide la clave especial antes de confirmar un ajuste de existencia.',
    ventasCreditoEliminar: 'Pide la clave especial antes de eliminar un crédito.',
    ventasCambiarPrecio: 'Pide la clave especial antes de modificar el precio unitario de un producto dentro de una venta.',
    ventasEditarDescripcion: 'Pide la clave especial antes de cambiar la descripción de un producto dentro de una venta.',
    ventasVenderSinStock: 'Pide la clave especial antes de agregar a una venta (o aumentar la cantidad de) un producto sin existencia disponible, en categorías que sí controlan stock. Si se cancela, se ofrece igual la opción de reembasado.',
    actualizarPuntos: 'Pide la clave especial antes de sumar o restar puntos de un cliente a mano, fuera de una venta.',
    comprasCrear: 'Permite registrar una nueva compra.',
    comprasEditar: 'Permite editar una compra ya registrada.',
    comprasEliminar: 'Permite anular una compra ya registrada.',
    inventarioCrearProducto: 'Permite dar de alta un producto nuevo en Inventario.',
    inventarioEliminarProducto: 'Permite eliminar un producto de Inventario.',
    clientesCrear: 'Permite dar de alta un cliente nuevo.',
    clientesEditar: 'Permite editar los datos de un cliente existente.',
    clientesEliminar: 'Permite eliminar un cliente.',
    ventasEliminar: 'Permite anular una venta ya registrada.',
  };
}

/// Cómo se maneja la impresión de la factura al confirmar una venta
/// facturable (ver ModoImpresion.preguntar/directo).
class ModoImpresion {
  static const preguntar = 'preguntar';
  static const directo = 'directo';
}

class NegocioModel {
  final String nombre;
  final String correo;
  final String rtn;
  final String cai;
  final String direccion;
  final String telefono;
  final String eslogan;
  final String rangoPrefijo;
  final String rangoDesde;
  final String rangoHasta;
  final DateTime? fechaLimiteEmision;
  final String logoColorBase64;
  final String logoBnBase64;
  final String claveEspecialHash;
  final Map<String, bool> permisos;
  final String impresoraTermicaUrl;
  final String impresoraTermicaNombre;
  final String impresoraEtiquetasUrl;
  final String impresoraEtiquetasNombre;
  // Si es false, el ticket de venta solo imprime la hoja "ORIGINAL" (se
  // salta la "COPIA"), para no gastar papel de más cuando no hace falta.
  final bool facturaImprimirCopia;
  // Si es true, el precio unitario y el importe de cada línea del ticket se
  // muestran con ISV incluido (igual que el recuadro "Con ISV" del carrito
  // en Registrar Venta). Si es false (default, comportamiento de siempre)
  // se muestran sin ISV, con el ISV desglosado aparte en el total.
  final bool facturaPreciosConIsv;
  // ModoImpresion.preguntar (default, comportamiento de siempre) muestra el
  // diálogo de vista previa/descargar/imprimir; ModoImpresion.directo salta
  // ese diálogo e imprime directo en la impresora configurada.
  final String modoImpresion;
  // Impresora térmica de red (ESC/POS por socket TCP): la vía que sí
  // funciona desde el celular, donde no hay forma de listar impresoras del
  // sistema operativo.
  final String impresoraRedIp;
  final int impresoraRedPuerto;

  const NegocioModel({
    this.nombre = '',
    this.correo = '',
    this.rtn = '',
    this.cai = '',
    this.direccion = '',
    this.telefono = '',
    this.eslogan = '',
    this.rangoPrefijo = '',
    this.rangoDesde = '',
    this.rangoHasta = '',
    this.fechaLimiteEmision,
    this.logoColorBase64 = '',
    this.logoBnBase64 = '',
    this.claveEspecialHash = '',
    this.permisos = const {},
    this.impresoraTermicaUrl = '',
    this.impresoraTermicaNombre = '',
    this.impresoraEtiquetasUrl = '',
    this.impresoraEtiquetasNombre = '',
    this.facturaImprimirCopia = true,
    this.facturaPreciosConIsv = false,
    this.modoImpresion = ModoImpresion.preguntar,
    this.impresoraRedIp = '',
    this.impresoraRedPuerto = 9100,
  });

  bool get tieneClaveEspecial => claveEspecialHash.isNotEmpty;

  bool tienePermiso(String key) => permisos[key] == true;

  factory NegocioModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const NegocioModel();
    return NegocioModel(
      nombre: data['nombre'] ?? '',
      correo: data['correo'] ?? '',
      rtn: data['rtn'] ?? '',
      cai: data['cai'] ?? '',
      direccion: data['direccion'] ?? '',
      telefono: data['telefono'] ?? '',
      eslogan: data['eslogan'] ?? '',
      rangoPrefijo: data['rangoPrefijo'] ?? '',
      rangoDesde: data['rangoDesde'] ?? '',
      rangoHasta: data['rangoHasta'] ?? '',
      fechaLimiteEmision: (data['fechaLimiteEmision'] as Timestamp?)?.toDate(),
      logoColorBase64: data['logoColorBase64'] ?? '',
      logoBnBase64: data['logoBnBase64'] ?? '',
      claveEspecialHash: data['claveEspecialHash'] ?? '',
      // El campo `permisos` debe ser un mapa; si por algún motivo quedó
      // guardado con otro tipo de dato (se dio un caso real en producción:
      // apareció como el string literal "[object Object]"), se ignora en vez
      // de tirar una excepción que deja la pantalla de Negocio en blanco.
      permisos: data['permisos'] is Map ? Map<String, bool>.from(data['permisos'] as Map) : {},
      impresoraTermicaUrl: data['impresoraTermicaUrl'] ?? '',
      impresoraTermicaNombre: data['impresoraTermicaNombre'] ?? '',
      impresoraEtiquetasUrl: data['impresoraEtiquetasUrl'] ?? '',
      impresoraEtiquetasNombre: data['impresoraEtiquetasNombre'] ?? '',
      facturaImprimirCopia: data['facturaImprimirCopia'] ?? true,
      facturaPreciosConIsv: data['facturaPreciosConIsv'] ?? false,
      modoImpresion: data['modoImpresion'] ?? ModoImpresion.preguntar,
      impresoraRedIp: data['impresoraRedIp'] ?? '',
      impresoraRedPuerto: ((data['impresoraRedPuerto'] ?? 9100) as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'correo': correo,
      'rtn': rtn,
      'cai': cai,
      'direccion': direccion,
      'telefono': telefono,
      'eslogan': eslogan,
      'rangoPrefijo': rangoPrefijo,
      'rangoDesde': rangoDesde,
      'rangoHasta': rangoHasta,
      'fechaLimiteEmision': fechaLimiteEmision != null ? Timestamp.fromDate(fechaLimiteEmision!) : null,
      'logoColorBase64': logoColorBase64,
      'logoBnBase64': logoBnBase64,
      'claveEspecialHash': claveEspecialHash,
      'permisos': permisos,
      'impresoraTermicaUrl': impresoraTermicaUrl,
      'impresoraTermicaNombre': impresoraTermicaNombre,
      'impresoraEtiquetasUrl': impresoraEtiquetasUrl,
      'impresoraEtiquetasNombre': impresoraEtiquetasNombre,
      'facturaImprimirCopia': facturaImprimirCopia,
      'facturaPreciosConIsv': facturaPreciosConIsv,
      'modoImpresion': modoImpresion,
      'impresoraRedIp': impresoraRedIp,
      'impresoraRedPuerto': impresoraRedPuerto,
    };
  }

  NegocioModel copyWith({
    String? nombre,
    String? correo,
    String? rtn,
    String? cai,
    String? direccion,
    String? telefono,
    String? eslogan,
    String? rangoPrefijo,
    String? rangoDesde,
    String? rangoHasta,
    DateTime? fechaLimiteEmision,
    String? logoColorBase64,
    String? logoBnBase64,
    String? claveEspecialHash,
    Map<String, bool>? permisos,
    String? impresoraTermicaUrl,
    String? impresoraTermicaNombre,
    String? impresoraEtiquetasUrl,
    String? impresoraEtiquetasNombre,
    bool? facturaImprimirCopia,
    bool? facturaPreciosConIsv,
    String? modoImpresion,
    String? impresoraRedIp,
    int? impresoraRedPuerto,
  }) {
    return NegocioModel(
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      rtn: rtn ?? this.rtn,
      cai: cai ?? this.cai,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      eslogan: eslogan ?? this.eslogan,
      rangoPrefijo: rangoPrefijo ?? this.rangoPrefijo,
      rangoDesde: rangoDesde ?? this.rangoDesde,
      rangoHasta: rangoHasta ?? this.rangoHasta,
      fechaLimiteEmision: fechaLimiteEmision ?? this.fechaLimiteEmision,
      logoColorBase64: logoColorBase64 ?? this.logoColorBase64,
      logoBnBase64: logoBnBase64 ?? this.logoBnBase64,
      claveEspecialHash: claveEspecialHash ?? this.claveEspecialHash,
      permisos: permisos ?? this.permisos,
      impresoraTermicaUrl: impresoraTermicaUrl ?? this.impresoraTermicaUrl,
      impresoraTermicaNombre: impresoraTermicaNombre ?? this.impresoraTermicaNombre,
      impresoraEtiquetasUrl: impresoraEtiquetasUrl ?? this.impresoraEtiquetasUrl,
      impresoraEtiquetasNombre: impresoraEtiquetasNombre ?? this.impresoraEtiquetasNombre,
      facturaImprimirCopia: facturaImprimirCopia ?? this.facturaImprimirCopia,
      facturaPreciosConIsv: facturaPreciosConIsv ?? this.facturaPreciosConIsv,
      modoImpresion: modoImpresion ?? this.modoImpresion,
      impresoraRedIp: impresoraRedIp ?? this.impresoraRedIp,
      impresoraRedPuerto: impresoraRedPuerto ?? this.impresoraRedPuerto,
    );
  }
}
