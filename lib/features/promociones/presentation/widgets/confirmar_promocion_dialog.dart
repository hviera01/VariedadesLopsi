import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/promocion_model.dart';
import '../../data/promocion_evaluador.dart';

/// "Este producto tiene la promoción X, ¿aplicar?" — se muestra al agregar
/// al carrito un producto con una promoción vigente y aplicable. El
/// vendedor puede ACEPTAR (el producto entra con el beneficio) o RECHAZAR
/// (entra a precio normal, sin la promoción).
class ConfirmarPromocionDialog extends StatelessWidget {
  final PromocionModel promocion;
  final String nombreProducto;

  const ConfirmarPromocionDialog({super.key, required this.promocion, required this.nombreProducto});

  static Future<bool> mostrar(BuildContext context, {required PromocionModel promocion, required String nombreProducto}) async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmarPromocionDialog(promocion: promocion, nombreProducto: nombreProducto),
    );
    return resultado ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.of(context).size;
    final anchoDialog = tamano.width < 420 ? tamano.width - 40 : 380.0;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: anchoDialog,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: const Color(0xFF0EA5A4).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.local_offer_outlined, color: Color(0xFF0EA5A4)),
            ),
            const SizedBox(height: 14),
            Text('¡Promoción disponible!', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A)),
                children: [
                  TextSpan(text: nombreProducto, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' tiene la promoción '),
                  TextSpan(text: '"${promocion.nombre}"', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: '. ¿Aplicarla?'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFE8F8EE), borderRadius: BorderRadius.circular(12)),
              child: Text(descripcionCortaPromocion(promocion), style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1A1A),
                      side: const BorderSide(color: Color(0xFFB6BCC7)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Rechazar', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Aplicar', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
