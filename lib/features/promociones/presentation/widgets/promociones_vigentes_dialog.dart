import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/promocion_model.dart';
import '../../data/promocion_evaluador.dart';
import '../../providers/promociones_provider.dart';

/// Consulta rápida, de solo lectura, de las promociones vigentes ahora
/// mismo — para que el vendedor pueda revisarlas todas de un vistazo sin
/// tener que buscar producto por producto (y sin necesitar permiso de
/// Mantenedor, a diferencia de PromocionesScreen). Se abre desde Registrar
/// Venta.
class PromocionesVigentesDialog extends ConsumerWidget {
  const PromocionesVigentesDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promocionesAsync = ref.watch(promocionesStreamProvider);
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 520;
    final anchoDialog = esMovil ? tamano.width - 24 : 480.0;
    final formatoFecha = DateFormat('dd/MM/yyyy');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: anchoDialog,
        constraints: BoxConstraints(maxHeight: tamano.height < 640 ? tamano.height - 40 : 600),
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
                  Expanded(child: Text('Promociones Vigentes', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)))),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: promocionesAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: Color(0xFF0F1B3D)))),
                error: (e, st) => Padding(padding: const EdgeInsets.all(24), child: Text('Error: $e', style: GoogleFonts.poppins(color: Colors.red))),
                data: (promociones) {
                  final vigentes = promociones.where((p) => p.vigente()).toList();
                  if (vigentes.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(30),
                      child: Center(child: Text('No hay promociones vigentes en este momento.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500))),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    shrinkWrap: true,
                    itemCount: vigentes.length,
                    separatorBuilder: (context, i) => Divider(height: 20, color: Colors.grey.shade200),
                    itemBuilder: (context, i) => _tarjetaPromocion(vigentes[i], formatoFecha),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaPromocion(PromocionModel promo, DateFormat formatoFecha) {
    final alcanceCondicion = promo.condicionRestringida.isEmpty ? 'Todos' : (promo.condicionRestringida == 'Contado' ? 'Solo Contado' : 'Solo Crédito');
    final alcanceMetodoPago = promo.metodoPagoRestringido.isEmpty ? 'Todos los métodos de pago' : 'Solo ${promo.metodoPagoRestringido}';
    final vigenciaTexto = promo.esIndefinida ? 'Desde el ${formatoFecha.format(promo.fechaInicio)} (indefinido)' : 'Del ${formatoFecha.format(promo.fechaInicio)} al ${formatoFecha.format(promo.fechaFin!)}';
    final nombresChips = promo.tipo == TipoPromocion.comboMultiproducto ? promo.nombresProductosCombo : promo.nombresProductos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(promo.nombre, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(descripcionCortaPromocion(promo), style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF0F1B3D), fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final n in nombresChips.where((n) => n.isNotEmpty))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF2F3F7), borderRadius: BorderRadius.circular(8)),
                child: Text(n, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('$vigenciaTexto · $alcanceCondicion · $alcanceMetodoPago', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}
