import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/promocion_model.dart';
import '../../providers/promociones_provider.dart';
import '../../../productos/providers/productos_provider.dart';
import 'selector_productos_multiple.dart';

class PromocionFormDialog extends ConsumerStatefulWidget {
  final PromocionModel? promocion;

  const PromocionFormDialog({super.key, this.promocion});

  @override
  ConsumerState<PromocionFormDialog> createState() => _PromocionFormDialogState();
}

class _PromocionFormDialogState extends ConsumerState<PromocionFormDialog> {
  final _nombreController = TextEditingController();
  final _porcentajeController = TextEditingController();
  final _precioFijoController = TextEditingController();
  final _cantidadRequeridaController = TextEditingController(text: '1');
  final _cantidadBeneficioController = TextEditingController(text: '1');
  final _cantidadRegaloController = TextEditingController(text: '1');
  final _precioComboController = TextEditingController();

  TipoPromocion _tipo = TipoPromocion.porcentaje;
  List<String> _idsProductos = [];
  List<String> _idsProductosRegalo = [];
  List<String> _idsProductosCombo = [];
  DateTime _fechaInicio = DateTime.now();
  DateTime? _fechaFin;
  bool _sinFechaFin = true;
  String _condicionRestringida = '';
  String _metodoPagoRestringido = '';
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.promocion;
    if (p != null) {
      _nombreController.text = p.nombre;
      _tipo = p.tipo;
      _idsProductos = [...p.idsProductos];
      _idsProductosRegalo = [...p.idsProductosRegalo];
      _idsProductosCombo = [...p.idsProductosCombo];
      _porcentajeController.text = p.porcentajeDescuento == 0 ? '' : _sinDecimalesInnecesarios(p.porcentajeDescuento);
      _precioFijoController.text = p.precioFijo == 0 ? '' : _sinDecimalesInnecesarios(p.precioFijo);
      _cantidadRequeridaController.text = p.cantidadRequerida.toString();
      _cantidadBeneficioController.text = p.cantidadBeneficio.toString();
      _cantidadRegaloController.text = p.cantidadRegalo.toString();
      _precioComboController.text = p.precioCombo == 0 ? '' : _sinDecimalesInnecesarios(p.precioCombo);
      _fechaInicio = p.fechaInicio;
      _fechaFin = p.fechaFin;
      _sinFechaFin = p.esIndefinida;
      _condicionRestringida = p.condicionRestringida;
      _metodoPagoRestringido = p.metodoPagoRestringido;
    }
  }

  String _sinDecimalesInnecesarios(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _nombreController.dispose();
    _porcentajeController.dispose();
    _precioFijoController.dispose();
    _cantidadRequeridaController.dispose();
    _cantidadBeneficioController.dispose();
    _cantidadRegaloController.dispose();
    _precioComboController.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha({required bool esInicio}) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: esInicio ? _fechaInicio : (_fechaFin ?? _fechaInicio),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha == null) return;
    setState(() {
      if (esInicio) {
        _fechaInicio = fecha;
      } else {
        _fechaFin = fecha;
      }
    });
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre de la promoción es obligatorio');
      return;
    }
    if (!_sinFechaFin && _fechaFin != null && _fechaFin!.isBefore(_fechaInicio)) {
      setState(() => _error = 'La fecha de fin no puede ser anterior a la fecha de inicio');
      return;
    }
    double porcentaje = 0, precioFijo = 0, precioCombo = 0;
    int cantidadRequerida = 1, cantidadBeneficio = 1, cantidadRegalo = 1;
    List<String> idsProductosRegalo = [], nombresProductosRegalo = [];
    List<String> idsProductosCombo = [], nombresProductosCombo = [];
    final productos = ref.read(productosStreamProvider).value ?? const [];
    switch (_tipo) {
      case TipoPromocion.porcentaje:
        if (_idsProductos.isEmpty) {
          setState(() => _error = 'Elegí al menos un producto');
          return;
        }
        porcentaje = double.tryParse(_porcentajeController.text.trim()) ?? 0;
        if (porcentaje <= 0 || porcentaje > 100) {
          setState(() => _error = 'El porcentaje debe ser mayor a 0 y hasta 100');
          return;
        }
        break;
      case TipoPromocion.precioFijo:
        if (_idsProductos.isEmpty) {
          setState(() => _error = 'Elegí al menos un producto');
          return;
        }
        precioFijo = double.tryParse(_precioFijoController.text.trim()) ?? 0;
        if (precioFijo <= 0) {
          setState(() => _error = 'El precio especial debe ser mayor a 0');
          return;
        }
        break;
      case TipoPromocion.comboCantidad:
        if (_idsProductos.isEmpty) {
          setState(() => _error = 'Elegí el producto condición');
          return;
        }
        cantidadRequerida = int.tryParse(_cantidadRequeridaController.text.trim()) ?? 0;
        cantidadBeneficio = int.tryParse(_cantidadBeneficioController.text.trim()) ?? 0;
        if (cantidadRequerida <= 0 || cantidadBeneficio <= 0) {
          setState(() => _error = 'Las cantidades del combo deben ser mayores a 0');
          return;
        }
        break;
      case TipoPromocion.comboMultiproducto:
        if (_idsProductosCombo.length < 2) {
          setState(() => _error = 'Elegí al menos 2 productos para el combo');
          return;
        }
        precioCombo = double.tryParse(_precioComboController.text.trim()) ?? 0;
        if (precioCombo <= 0) {
          setState(() => _error = 'El precio del combo debe ser mayor a 0');
          return;
        }
        idsProductosCombo = _idsProductosCombo;
        nombresProductosCombo = [
          for (final id in _idsProductosCombo) productos.where((p) => p.id == id).map((p) => p.nombre).firstOrNull ?? '',
        ];
        break;
      case TipoPromocion.regalo:
        if (_idsProductos.isEmpty) {
          setState(() => _error = 'Elegí el producto condición');
          return;
        }
        cantidadRequerida = int.tryParse(_cantidadRequeridaController.text.trim()) ?? 0;
        cantidadRegalo = int.tryParse(_cantidadRegaloController.text.trim()) ?? 0;
        if (cantidadRequerida <= 0 || cantidadRegalo <= 0) {
          setState(() => _error = 'Las cantidades del regalo deben ser mayores a 0');
          return;
        }
        if (_idsProductosRegalo.isEmpty) {
          setState(() => _error = 'Elegí al menos un producto que se regala');
          return;
        }
        if (_idsProductosRegalo.contains(_idsProductos.first)) {
          setState(() => _error = 'El producto regalado no puede ser el mismo que el producto condición');
          return;
        }
        idsProductosRegalo = _idsProductosRegalo;
        nombresProductosRegalo = [
          for (final id in _idsProductosRegalo) productos.where((p) => p.id == id).map((p) => p.nombre).firstOrNull ?? '',
        ];
        break;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final nombresProductos = [
        for (final id in _idsProductos)
          productos.where((p) => p.id == id).map((p) => p.nombre).firstOrNull ?? '',
      ];
      final promo = PromocionModel(
        id: widget.promocion?.id ?? '',
        nombre: nombre,
        tipo: _tipo,
        idsProductos: _tipo == TipoPromocion.comboMultiproducto ? const [] : _idsProductos,
        nombresProductos: _tipo == TipoPromocion.comboMultiproducto ? const [] : nombresProductos,
        porcentajeDescuento: porcentaje,
        precioFijo: precioFijo,
        cantidadRequerida: cantidadRequerida,
        cantidadBeneficio: cantidadBeneficio,
        idsProductosCombo: idsProductosCombo,
        nombresProductosCombo: nombresProductosCombo,
        precioCombo: precioCombo,
        idsProductosRegalo: idsProductosRegalo,
        nombresProductosRegalo: nombresProductosRegalo,
        cantidadRegalo: cantidadRegalo,
        fechaInicio: _fechaInicio,
        fechaFin: _sinFechaFin ? null : _fechaFin,
        condicionRestringida: _condicionRestringida,
        metodoPagoRestringido: _metodoPagoRestringido,
        activa: widget.promocion?.activa ?? true,
      );
      final repo = ref.read(promocionRepositoryProvider);
      if (widget.promocion == null) {
        await repo.crear(promo);
      } else {
        await repo.actualizar(promo);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _guardando = false;
      });
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar promoción', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('¿Seguro que querés eliminar esta promoción? Ya no se ofrecerá en Registrar Venta.', style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: GoogleFonts.poppins())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F1B3D)),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _guardando = true);
    try {
      await ref.read(promocionRepositoryProvider).eliminar(widget.promocion!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _guardando = false;
      });
    }
  }

  InputDecoration _decoracion(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFE8EAF0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _chipTipo(TipoPromocion tipo, String texto, IconData icono) {
    final activo = _tipo == tipo;
    return ChoiceChip(
      label: Text(texto, style: GoogleFonts.poppins(fontSize: 12.5)),
      avatar: Icon(icono, size: 16, color: activo ? Colors.white : const Color(0xFF0F1B3D)),
      selected: activo,
      onSelected: (_) => setState(() => _tipo = tipo),
      selectedColor: const Color(0xFF0F1B3D),
      labelStyle: GoogleFonts.poppins(fontSize: 12.5, color: activo ? Colors.white : const Color(0xFF1A1A1A)),
      backgroundColor: const Color(0xFFE8EAF0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
    );
  }

  Widget _camposSegunTipo() {
    switch (_tipo) {
      case TipoPromocion.porcentaje:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectorProductosMultiple(seleccionados: _idsProductos, onCambiar: (v) => setState(() => _idsProductos = v), etiqueta: 'Productos con descuento'),
            const SizedBox(height: 14),
            TextField(
              controller: _porcentajeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: _decoracion('Porcentaje de descuento (%)'),
            ),
          ],
        );
      case TipoPromocion.precioFijo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectorProductosMultiple(seleccionados: _idsProductos, onCambiar: (v) => setState(() => _idsProductos = v), etiqueta: 'Productos con precio especial'),
            const SizedBox(height: 14),
            TextField(
              controller: _precioFijoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: _decoracion('Precio especial (L.)'),
            ),
          ],
        );
      case TipoPromocion.comboCantidad:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectorProductosMultiple(seleccionados: _idsProductos, onCambiar: (v) => setState(() => _idsProductos = v), maximoUno: true, etiqueta: 'Producto del combo'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cantidadRequeridaController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: _decoracion('Llevando (unidades)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cantidadBeneficioController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: _decoracion('Se lleva gratis (unidades)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ej.: "Llevando 3" y "Se lleva gratis 1" arma un 3x2: al llegar a 3 unidades del producto en el carrito, la venta ofrece agregar 1 más gratis.',
              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500),
            ),
          ],
        );
      case TipoPromocion.comboMultiproducto:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectorProductosMultiple(seleccionados: _idsProductosCombo, onCambiar: (v) => setState(() => _idsProductosCombo = v), etiqueta: 'Productos del combo (2 o más)'),
            const SizedBox(height: 14),
            TextField(
              controller: _precioComboController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: _decoracion('Precio del combo (L.)'),
            ),
            const SizedBox(height: 8),
            Text(
              'Se necesita 1 unidad de CADA producto elegido en el carrito para armar el combo, al precio total indicado.',
              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500),
            ),
          ],
        );
      case TipoPromocion.regalo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectorProductosMultiple(seleccionados: _idsProductos, onCambiar: (v) => setState(() => _idsProductos = v), maximoUno: true, etiqueta: 'Producto condición (el que se compra)'),
            const SizedBox(height: 14),
            SelectorProductosMultiple(seleccionados: _idsProductosRegalo, onCambiar: (v) => setState(() => _idsProductosRegalo = v), etiqueta: 'Producto(s) que se regalan'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cantidadRequeridaController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: _decoracion('Llevando (unidades)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cantidadRegaloController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: _decoracion('Se regalan (unidades de cada uno)'),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.promocion != null;
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 560;
    final anchoDialog = esMovil ? tamano.width - 24 : 560.0;
    final formatoFecha = DateFormat('dd/MM/yyyy');
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: anchoDialog,
        constraints: BoxConstraints(maxHeight: tamano.height < 760 ? tamano.height - 40 : 720),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: const Color(0xFF0EA5A4).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.sell_outlined, color: Color(0xFF0EA5A4)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      editando ? 'Editar Promoción' : 'Nueva Promoción',
                      style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: _nombreController, autofocus: true, style: GoogleFonts.poppins(fontSize: 14), decoration: _decoracion('Nombre de la promoción')),
                    const SizedBox(height: 16),
                    Text('Tipo de promoción', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chipTipo(TipoPromocion.porcentaje, 'Porcentaje', Icons.percent),
                        _chipTipo(TipoPromocion.precioFijo, 'Precio fijo', Icons.sell_outlined),
                        _chipTipo(TipoPromocion.comboCantidad, 'Combo por cantidad', Icons.filter_3_outlined),
                        _chipTipo(TipoPromocion.comboMultiproducto, 'Combo de productos', Icons.shopping_bag_outlined),
                        _chipTipo(TipoPromocion.regalo, 'Regalo', Icons.card_giftcard_outlined),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _camposSegunTipo(),
                    const SizedBox(height: 18),
                    Text('Vigencia', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _botonFecha('Inicio', formatoFecha.format(_fechaInicio), () => _elegirFecha(esInicio: true)),
                        if (!_sinFechaFin) _botonFecha('Fin', _fechaFin == null ? 'Elegir fecha' : formatoFecha.format(_fechaFin!), () => _elegirFecha(esInicio: false)),
                        FilterChip(
                          label: Text('Indefinido (sin fecha de fin)', style: GoogleFonts.poppins(fontSize: 12)),
                          selected: _sinFechaFin,
                          onSelected: (v) => setState(() => _sinFechaFin = v),
                          selectedColor: const Color(0xFF0F1B3D),
                          labelStyle: GoogleFonts.poppins(fontSize: 12, color: _sinFechaFin ? Colors.white : const Color(0xFF1A1A1A)),
                          backgroundColor: const Color(0xFFE8EAF0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('Condición', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chipCondicion('', 'Todas'),
                        _chipCondicion('Contado', 'Solo Contado'),
                        _chipCondicion('Credito', 'Solo Crédito'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('Método de pago', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chipMetodoPago('', 'Todos'),
                        _chipMetodoPago('Efectivo', 'Efectivo'),
                        _chipMetodoPago('Tarjeta', 'Tarjeta'),
                        _chipMetodoPago('Transferencia', 'Transferencia'),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                        child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              child: Row(
                children: [
                  if (editando)
                    IconButton(
                      onPressed: _guardando ? null : _eliminar,
                      icon: const Icon(Icons.delete_outline, color: Color(0xFF0F1B3D)),
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF0F1B3D).withOpacity(0.08), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  const Spacer(),
                  TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey.shade700))),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F1B3D), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _guardando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                        : Text('Guardar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonFecha(String etiqueta, String texto, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFB6BCC7))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 15, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Text('$etiqueta: $texto', style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF1A1A1A))),
          ],
        ),
      ),
    );
  }

  Widget _chipCondicion(String valor, String texto) {
    final activo = _condicionRestringida == valor;
    return ChoiceChip(
      label: Text(texto, style: GoogleFonts.poppins(fontSize: 12.5)),
      selected: activo,
      onSelected: (_) => setState(() => _condicionRestringida = valor),
      selectedColor: const Color(0xFF0F1B3D),
      labelStyle: GoogleFonts.poppins(fontSize: 12.5, color: activo ? Colors.white : const Color(0xFF1A1A1A)),
      backgroundColor: const Color(0xFFE8EAF0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
    );
  }

  Widget _chipMetodoPago(String valor, String texto) {
    final activo = _metodoPagoRestringido == valor;
    return ChoiceChip(
      label: Text(texto, style: GoogleFonts.poppins(fontSize: 12.5)),
      selected: activo,
      onSelected: (_) => setState(() => _metodoPagoRestringido = valor),
      selectedColor: const Color(0xFF0F1B3D),
      labelStyle: GoogleFonts.poppins(fontSize: 12.5, color: activo ? Colors.white : const Color(0xFF1A1A1A)),
      backgroundColor: const Color(0xFFE8EAF0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
