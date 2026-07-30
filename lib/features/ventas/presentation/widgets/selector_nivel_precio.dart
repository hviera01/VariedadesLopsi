import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Selector visual de nivel de precio (1/2/3), compartido entre el diálogo
/// de Buscar Producto (nivel puntual para esa búsqueda) y la cabecera de
/// Registrar Venta (nivel global de toda la venta, ver
/// CarritoVentaNotifier.establecerNivelPrecio).
class SelectorNivelPrecio extends StatelessWidget {
  final int nivelActivo;
  final ValueChanged<int> onCambiar;

  const SelectorNivelPrecio({super.key, required this.nivelActivo, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    Widget opcion(String texto, int nivel) {
      final activo = nivelActivo == nivel;
      return InkWell(
        onTap: () => onCambiar(nivel),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: activo ? const Color(0xFF0F1B3D) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            texto,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: activo ? Colors.white : const Color(0xFF666A72)),
          ),
        ),
      );
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFB6BCC7))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          opcion('Precio 1', 1),
          opcion('Precio 2', 2),
          opcion('Precio 3', 3),
        ],
      ),
    );
  }
}
