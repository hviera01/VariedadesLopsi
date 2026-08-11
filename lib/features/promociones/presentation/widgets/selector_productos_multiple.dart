import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../productos/data/producto_model.dart';
import '../../../productos/providers/productos_provider.dart';
import '../../../../core/utils/texto_utils.dart';
import '../../../../core/utils/formato_moneda.dart';

/// Buscador embebido con checklist para elegir uno o varios productos desde
/// el formulario de una promoción — a diferencia de BuscarProductoDialog
/// (que es una pantalla completa y devuelve un solo producto para agregarlo
/// al carrito), este widget vive adentro del formulario y puede devolver
/// más de uno. [maximoUno] lo pone en modo selección única (radio en vez de
/// checkbox), para elegir el producto condición/regalo de un combo.
class SelectorProductosMultiple extends ConsumerStatefulWidget {
  final List<String> seleccionados;
  final ValueChanged<List<String>> onCambiar;
  final bool maximoUno;
  final String etiqueta;

  const SelectorProductosMultiple({
    super.key,
    required this.seleccionados,
    required this.onCambiar,
    this.maximoUno = false,
    this.etiqueta = 'Productos',
  });

  @override
  ConsumerState<SelectorProductosMultiple> createState() => _SelectorProductosMultipleState();
}

class _SelectorProductosMultipleState extends ConsumerState<SelectorProductosMultiple> {
  final _busquedaController = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _alternar(ProductoModel p) {
    final actuales = [...widget.seleccionados];
    if (widget.maximoUno) {
      widget.onCambiar(actuales.contains(p.id) ? [] : [p.id]);
      return;
    }
    if (actuales.contains(p.id)) {
      actuales.remove(p.id);
    } else {
      actuales.add(p.id);
    }
    widget.onCambiar(actuales);
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosStreamProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.etiqueta, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFFF2F3F7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFB6BCC7))),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _busquedaController,
                  style: GoogleFonts.poppins(fontSize: 13),
                  decoration: InputDecoration(hintText: 'Buscar producto...', hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade400), border: InputBorder.none, isDense: true),
                  onChanged: (v) => setState(() => _busqueda = v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 220,
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFB6BCC7)), borderRadius: BorderRadius.circular(10)),
          child: productosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, st) => Center(child: Text('Error: $e', style: GoogleFonts.poppins(fontSize: 12, color: Colors.red))),
            data: (productos) {
              final activos = productos.where((p) => p.estado).toList();
              final filtrados = _busqueda.isEmpty ? activos : activos.where((p) => coincideFuzzy(p.textoBusqueda, _busqueda)).toList();
              if (filtrados.isEmpty) {
                return Center(child: Text('Sin resultados', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade500)));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: filtrados.length,
                separatorBuilder: (context, i) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, i) {
                  final p = filtrados[i];
                  final marcado = widget.seleccionados.contains(p.id);
                  return InkWell(
                    onTap: () => _alternar(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            marcado ? (widget.maximoUno ? Icons.radio_button_checked : Icons.check_box) : (widget.maximoUno ? Icons.radio_button_unchecked : Icons.check_box_outline_blank),
                            size: 19,
                            color: marcado ? const Color(0xFF0F1B3D) : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(p.nombre, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: marcado ? FontWeight.w600 : FontWeight.w400), overflow: TextOverflow.ellipsis),
                          ),
                          Text(formatearMoneda(p.precioVenta), style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.seleccionados.isEmpty ? 'Ningún producto seleccionado' : '${widget.seleccionados.length} producto(s) seleccionado(s)',
          style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
